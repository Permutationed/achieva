//
//  ChatView.swift
//  Achieva
//
//  Individual chat/conversation view
//

import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var authStore = AuthStore.shared
    @StateObject private var messagingService = MessagingService.shared
    @State private var messages: [Message] = []
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    
    private var currentUserId: UUID {
        authStore.userId ?? UUID()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
            }
            
            // Loading indicator
            if isLoading && messages.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Pinned goals header
            ChatPinnedHeader(
                conversationId: conversation.id,
                conversationName: conversation.displayName(currentUserId: currentUserId)
            )
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.userId == currentUserId,
                                senderName: message.senderProfile?.fullName,
                                currentUserId: currentUserId
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // Input area
            MessageInputView(
                text: $messageText,
                onSend: { text in
                    Task {
                        await sendMessage(text: text)
                    }
                },
                onSendMedia: { data, type in
                    Task {
                        await sendMedia(data: data, type: type)
                    }
                },
                isLoading: isSending
            )
        }
        .navigationTitle(conversation.displayName(currentUserId: currentUserId))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task {
            await loadMessages()
            await markAsRead()
            await subscribeToMessages()
        }
        .onAppear {
            // Mark as read when view appears
            Task {
                await markAsRead()
            }
        }
        .onDisappear {
            // Clean up subscription
            Task {
                await unsubscribeFromMessages()
            }
        }
    }
    
    private func loadMessages() async {
        print("📥 ChatView: Loading messages for conversation: \(conversation.id)")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let loadedMessages = try await messagingService.getMessages(conversationId: conversation.id, limit: 50)
            print("✅ ChatView: Loaded \(loadedMessages.count) messages")
            await MainActor.run {
                messages = loadedMessages
                isLoading = false
            }
        } catch {
            print("❌ ChatView: Error loading messages: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func sendMessage(text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSending = true
        
        do {
            let newMessage = try await messagingService.sendMessage(
                conversationId: conversation.id,
                text: text,
                mediaData: nil,
                messageType: .text
            )
            
            await MainActor.run {
                messages.append(newMessage)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error sending message: \(error)")
        }
        
        isSending = false
    }
    
    private func sendMedia(data: Data, type: MessageType) async {
        isSending = true
        
        do {
            let newMessage = try await messagingService.sendMessage(
                conversationId: conversation.id,
                text: nil,
                mediaData: data,
                messageType: type
            )
            
            await MainActor.run {
                messages.append(newMessage)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error sending media: \(error)")
        }
        
        isSending = false
    }
    
    private func markAsRead() async {
        do {
            try await messagingService.markAsRead(conversationId: conversation.id)
        } catch {
            print("Error marking as read: \(error)")
        }
    }
    
    private func subscribeToMessages() async {
        do {
            try await messagingService.subscribeToMessages(conversationId: conversation.id) {
                // Refresh messages when new message arrives
                Task { @MainActor in
                    await self.loadMessages()
                }
            }
        } catch {
            print("❌ Error subscribing to messages: \(error)")
        }
    }
    
    private func unsubscribeFromMessages() async {
        await messagingService.unsubscribeFromMessages(conversationId: conversation.id)
    }
}

