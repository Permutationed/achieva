//
//  NewConversationView.swift
//  Achieva
//
//  View to start a new conversation with a friend
//

import SwiftUI

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    @StateObject private var messagingService = MessagingService.shared
    @State private var friends: [Profile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    let onConversationCreated: (Conversation) -> Void
    
    private var filteredFriends: [Profile] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { friend in
            friend.fullName.localizedCaseInsensitiveContains(searchText) ||
            friend.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading && friends.isEmpty {
                    ProgressView()
                } else if friends.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No friends yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("Add friends to start messaging")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(filteredFriends) { friend in
                            Button {
                                Task {
                                    await startConversation(with: friend)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(name: friend.fullName, size: 48)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(friend.fullName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("@\(friend.username)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search friends")
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadFriends()
            }
        }
    }
    
    private func loadFriends() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let currentUserId = authStore.userId else { return }
            
            let friendships = try await supabaseService.getFriends(forUserId: currentUserId)
            let friendIds = friendships.map { friendship in
                friendship.userId1 == currentUserId ? friendship.userId2 : friendship.userId1
            }
            
            if !friendIds.isEmpty {
                friends = try await supabaseService.getProfiles(userIds: friendIds)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading friends: \(error)")
        }
        
        isLoading = false
    }
    
    private func startConversation(with friend: Profile) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let conversation = try await messagingService.createDirectConversation(with: friend.id)
            onConversationCreated(conversation)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            print("Error creating conversation: \(error)")
            isLoading = false
        }
    }
}


