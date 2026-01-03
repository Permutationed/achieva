//
//  NotificationsView.swift
//  Achieva
//
//  View to display all notifications (messages, goal tags, friend requests)
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    
    @State private var notifications: [AppNotification] = []
    @State private var friendRequests: [UserWithFriendshipStatus] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedNotification: AppNotification?
    @State private var showingChat = false
    @State private var showingGoalDetail = false
    @State private var selectedConversationId: UUID?
    @State private var selectedGoalId: UUID?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading notifications...")
                } else if allNotifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No notifications")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        // All Notifications Section
                        ForEach(allNotifications) { item in
                            NotificationRow(
                                notification: item.notification,
                                friendRequest: item.friendRequest,
                                onTap: {
                                    handleNotificationTap(item)
                                },
                                onMarkAsRead: {
                                    if let notification = item.notification {
                                        Task {
                                            try? await supabaseService.markNotificationAsRead(notificationId: notification.id)
                                            await loadNotifications()
                                        }
                                    }
                                },
                                onAcceptFriendRequest: {
                                    if let friendRequest = item.friendRequest {
                                        Task {
                                            await acceptFriendRequest(friendRequest)
                                        }
                                    }
                                },
                                onRejectFriendRequest: {
                                    if let friendRequest = item.friendRequest {
                                        Task {
                                            await rejectFriendRequest(friendRequest)
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !allNotifications.isEmpty {
                        Button("Mark All Read") {
                            Task {
                                if let userId = authStore.userId {
                                    try? await supabaseService.markAllNotificationsAsRead(userId: userId)
                                    await loadNotifications()
                                }
                            }
                        }
                        .font(.system(size: 14))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadNotifications()
            }
            .sheet(isPresented: $showingChat) {
                if let conversationId = selectedConversationId {
                    ChatViewFromId(conversationId: conversationId)
                }
            }
            .sheet(isPresented: $showingGoalDetail) {
                if let goalId = selectedGoalId {
                    GoalDetailViewFromId(goalId: goalId)
                }
            }
        }
    }
    
    // Combined list of notifications and friend requests
    private var allNotifications: [NotificationItem] {
        var items: [NotificationItem] = []
        
        // Add database notifications
        for notification in notifications {
            items.append(NotificationItem(notification: notification, friendRequest: nil))
        }
        
        // Add friend requests as notifications
        for friendRequest in friendRequests {
            // Create a notification-like item for friend requests
            let friendRequestNotification = AppNotification(
                userId: authStore.userId ?? UUID(),
                type: .friendRequest,
                title: "\(friendRequest.profile.fullName) sent you a friend request",
                body: "@\(friendRequest.profile.username)",
                relatedId: friendRequest.profile.id
            )
            items.append(NotificationItem(notification: friendRequestNotification, friendRequest: friendRequest))
        }
        
        // Sort by date (most recent first)
        return items.sorted { item1, item2 in
            let date1 = item1.notification?.createdAt ?? Date()
            let date2 = item2.notification?.createdAt ?? Date()
            return date1 > date2
        }
    }
    
    private func loadNotifications() async {
        guard let userId = authStore.userId else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Load notifications from database
            let dbNotifications = try await supabaseService.getNotifications(userId: userId, limit: 100)
            
            // Load friend requests
            let friendships: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .or("user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(userId.uuidString)")
                .eq("status", value: "pending")
                .execute()
                .value
            
            // Filter incoming friend requests
            let incomingFriendRequests = friendships.filter { friendship in
                friendship.userId2 == userId
            }
            
            // Load profiles for friend requests
            let friendRequestUserIds = incomingFriendRequests.map { $0.userId1 }
            var friendRequestUsers: [UserWithFriendshipStatus] = []
            
            if !friendRequestUserIds.isEmpty {
                let profiles = try await supabaseService.getProfiles(userIds: friendRequestUserIds)
                friendRequestUsers = profiles.map { profile in
                    let friendship = incomingFriendRequests.first { $0.userId1 == profile.id }
                    return UserWithFriendshipStatus(
                        profile: profile,
                        friendshipStatus: .pending,
                        friendshipId: friendship?.id,
                        isIncomingRequest: true
                    )
                }
            }
            
            await MainActor.run {
                self.notifications = dbNotifications
                self.friendRequests = friendRequestUsers
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load notifications: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func handleNotificationTap(_ item: NotificationItem) {
        guard let notification = item.notification else { return }
        
        // Mark as read if unread
        if !notification.isRead {
            Task {
                try? await supabaseService.markNotificationAsRead(notificationId: notification.id)
                await loadNotifications()
            }
        }
        
        // Handle navigation based on type
        switch notification.type {
        case .message:
            if let conversationId = notification.relatedId {
                selectedConversationId = conversationId
                showingChat = true
            }
        case .goalTag:
            if let goalId = notification.relatedId {
                selectedGoalId = goalId
                showingGoalDetail = true
            }
        case .friendRequest:
            // Friend requests are handled in the row component
            break
        }
    }
    
    private func acceptFriendRequest(_ userWithStatus: UserWithFriendshipStatus) async {
        guard let friendshipId = userWithStatus.friendshipId else { return }
        
        do {
            struct FriendshipUpdate: Encodable {
                let status: String
                let established_at: String
            }
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let update = FriendshipUpdate(
                status: "accepted",
                established_at: dateFormatter.string(from: Date())
            )
            
            try await supabaseService.client
                .from("friendships")
                .update(update)
                .eq("id", value: friendshipId)
                .execute()
            
            // Refresh notifications
            await loadNotifications()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to accept friend request: \(error.localizedDescription)"
            }
        }
    }
    
    private func rejectFriendRequest(_ userWithStatus: UserWithFriendshipStatus) async {
        guard let friendshipId = userWithStatus.friendshipId else { return }
        
        do {
            try await supabaseService.client
                .from("friendships")
                .delete()
                .eq("id", value: friendshipId)
                .execute()
            
            // Refresh notifications
            await loadNotifications()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to reject friend request: \(error.localizedDescription)"
            }
        }
    }
}

// Helper struct to combine notifications and friend requests
private struct NotificationItem: Identifiable {
    let id = UUID()
    let notification: AppNotification?
    let friendRequest: UserWithFriendshipStatus?
}

// Notification row component
private struct NotificationRow: View {
    let notification: AppNotification?
    let friendRequest: UserWithFriendshipStatus?
    let onTap: () -> Void
    let onMarkAsRead: () -> Void
    let onAcceptFriendRequest: () -> Void
    let onRejectFriendRequest: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Icon based on type
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                        .frame(width: 40, height: 40)
                        .background(iconColor.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if let body = bodyText {
                            Text(body)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Text(timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Unread indicator
                    if isUnread {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Accept/Reject buttons for friend requests
            if friendRequest != nil {
                HStack(spacing: 12) {
                    Button {
                        onAcceptFriendRequest()
                    } label: {
                        Text("Accept")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onRejectFriendRequest()
                    } label: {
                        Text("Reject")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 52)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isUnread {
                Button("Mark Read") {
                    onMarkAsRead()
                }
                .tint(.blue)
            }
        }
    }
    
    private var iconName: String {
        if let notification = notification {
            switch notification.type {
            case .message:
                return "message.fill"
            case .goalTag:
                return "tag.fill"
            case .friendRequest:
                return "person.badge.plus.fill"
            }
        }
        return "bell.fill"
    }
    
    private var iconColor: Color {
        if let notification = notification {
            switch notification.type {
            case .message:
                return .blue
            case .goalTag:
                return .orange
            case .friendRequest:
                return .green
            }
        }
        return .gray
    }
    
    private var title: String {
        notification?.title ?? "Notification"
    }
    
    private var bodyText: String? {
        notification?.body
    }
    
    private var timeAgo: String {
        notification?.timeAgo ?? ""
    }
    
    private var isUnread: Bool {
        notification?.isRead == false
    }
}

// Wrapper view to load ChatView from conversation ID
private struct ChatViewFromId: View {
    let conversationId: UUID
    @StateObject private var messagingService = MessagingService.shared
    @State private var conversation: Conversation?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let conversation = conversation {
                ChatView(conversation: conversation)
            } else if isLoading {
                ProgressView("Loading conversation...")
            } else {
                Text("Conversation not found")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await loadConversation()
        }
    }
    
    private func loadConversation() async {
        do {
            let conversations = try await messagingService.getConversations()
            if let found = conversations.first(where: { $0.id == conversationId }) {
                await MainActor.run {
                    self.conversation = found
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("Error loading conversation: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// Wrapper view to load GoalDetailView from goal ID
private struct GoalDetailViewFromId: View {
    let goalId: UUID
    @ObservedObject var supabaseService = SupabaseService.shared
    @State private var goal: Goal?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let goal = goal {
                GoalDetailView(goal: goal)
            } else if isLoading {
                ProgressView("Loading goal...")
            } else {
                Text("Goal not found")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await loadGoal()
        }
    }
    
    private func loadGoal() async {
        do {
            let goals: [Goal] = try await supabaseService.client
                .from("goals")
                .select()
                .eq("id", value: goalId)
                .limit(1)
                .execute()
                .value
            
            if let foundGoal = goals.first {
                await MainActor.run {
                    // Load items for the goal
                    Task {
                        let items: [GoalItem] = try await supabaseService.client
                            .from("goal_items")
                            .select()
                            .eq("goal_id", value: goalId)
                            .execute()
                            .value
                        
                        var goalWithItems = foundGoal
                        goalWithItems.items = items
                        
                        await MainActor.run {
                            self.goal = goalWithItems
                            self.isLoading = false
                        }
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("Error loading goal: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

#Preview {
    NotificationsView()
}

