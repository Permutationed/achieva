//
//  NotificationsView.swift
//  Achieva
//
//  View to display all notifications (collaboration requests, friend requests, likes, comments)
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    
    @State private var friendRequests: [UserWithFriendshipStatus] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading notifications...")
                } else if friendRequests.isEmpty {
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
                        // Friend Requests Section
                        if !friendRequests.isEmpty {
                            Section {
                                ForEach(friendRequests) { user in
                                    NotificationFriendRow(userWithStatus: user)
                                }
                            } header: {
                                Text("Friend Requests")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadNotifications()
            }
        }
    }
    
    private func loadNotifications() async {
        guard let userId = authStore.userId else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
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
                friendship.userId2 == userId // Incoming requests have current user as userId2
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
}

// Simple notification row components (different from the full-featured ones in Components)
private struct NotificationFriendRow: View {
    let userWithStatus: UserWithFriendshipStatus
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: userWithStatus.profile.fullName, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(userWithStatus.profile.fullName)
                    .font(.headline)
                Text("@\(userWithStatus.profile.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NotificationsView()
}

