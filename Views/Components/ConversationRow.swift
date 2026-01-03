//
//  ConversationRow.swift
//  Achieva
//
//  Conversation list row component
//

import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: UUID
    let goalCount: Int?
    let onTap: () -> Void
    let onAvatarTap: (() -> Void)?
    
    init(conversation: Conversation, currentUserId: UUID, goalCount: Int?, onTap: @escaping () -> Void, onAvatarTap: (() -> Void)? = nil) {
        self.conversation = conversation
        self.currentUserId = currentUserId
        self.goalCount = goalCount
        self.onTap = onTap
        self.onAvatarTap = onAvatarTap
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                // Avatar (14x14 in HTML = 56pt in SwiftUI) - clickable to view profile
                Button {
                    onAvatarTap?()
                } label: {
                    if let otherProfile = conversation.otherParticipantProfile {
                        AvatarView(name: otherProfile.fullName, size: 56, avatarUrl: otherProfile.avatarUrl)
                    } else {
                        AvatarView(name: conversation.displayName(currentUserId: currentUserId), size: 56, avatarUrl: nil)
                    }
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Name and timestamp
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(conversation.displayName(currentUserId: currentUserId))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let lastMessageAt = conversation.lastMessageAt {
                            Text(formatTime(lastMessageAt))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Preview text
                    if let lastMessage = conversation.lastMessage {
                        Text(previewText(for: lastMessage))
                            .font(.system(size: 14))
                            .foregroundColor((conversation.unreadCount ?? 0) > 0 ? .primary : .secondary)
                            .fontWeight((conversation.unreadCount ?? 0) > 0 ? .medium : .regular)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    // Goal count
                    if let count = goalCount, count > 0 {
                        Text("\(count) goal\(count == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                // Unread indicator dot
                if let unreadCount = conversation.unreadCount, unreadCount > 0 {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
    }
    
    private func previewText(for message: Message) -> String {
        if let text = message.text, !text.isEmpty {
            return text
        }

        switch message.messageType {
        case .image:
            return "📷 Photo"
        case .video:
            return "🎥 Video"
        case .audio:
            return "🎤 Audio"
        case .file:
            return "📎 File"
        case .text:
            return ""
        }
    }

    private func iconForMessageType(_ type: MessageType) -> String {
        switch type {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "mic"
        case .file:
            return "doc"
        case .text:
            return ""
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if today
        if calendar.isDateInToday(date) {
            let minutesAgo = calendar.dateComponents([.minute], from: date, to: now).minute ?? 0
            if minutesAgo < 1 {
                return "now"
            } else if minutesAgo < 60 {
                return "\(minutesAgo)m"
            } else {
                let hoursAgo = minutesAgo / 60
                return "\(hoursAgo)h"
            }
        } else if calendar.isDateInYesterday(date) {
            return "1d"
        } else {
            let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if daysAgo < 7 {
                return "\(daysAgo)d"
            } else if daysAgo < 30 {
                let weeksAgo = daysAgo / 7
                return "\(weeksAgo)w"
            } else {
                return "1w+"
            }
        }
    }
}

