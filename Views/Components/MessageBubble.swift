//
//  MessageBubble.swift
//  Achieva
//
//  Message bubble component for chat messages
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let senderName: String?
    let senderAvatarUrl: String?
    let currentUserId: UUID
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if let senderName = senderName, !isFromCurrentUser {
                    Text(senderName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                }
                
                HStack(alignment: .bottom, spacing: 8) {
                    if !isFromCurrentUser {
                        AvatarView(name: senderName ?? "User", size: 32, avatarUrl: senderAvatarUrl)
                    }
                    
                    VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                        // Media content
                        if let mediaUrl = message.mediaUrl, message.messageType == .image || message.messageType == .video || message.messageType == .audio || message.messageType == .file {
                            AsyncImage(url: URL(string: mediaUrl)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 200, height: 200)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 250, maxHeight: 300)
                                        .cornerRadius(12)
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                        .frame(width: 200, height: 200)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        
                        // Text content
                        if let text = message.text, !text.isEmpty, message.messageType == .text {
                            Text(text)
                                .font(.system(size: 15))
                                .foregroundColor(isFromCurrentUser ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                                .cornerRadius(20)
                        }
                    }
                    
                    if isFromCurrentUser {
                        AvatarView(name: senderName ?? "You", size: 32, avatarUrl: senderAvatarUrl)
                    }
                }
                
                Text(formatTime(message.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

