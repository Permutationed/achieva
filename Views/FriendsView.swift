//
//  FriendsView.swift
//  Bucketlist
//
//  Friends view redesigned to match the provided HTML design
//

import SwiftUI

struct FriendsView: View {
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    @State private var allUsers: [UserWithFriendshipStatus] = []
    @State private var pendingRequests: [UserWithFriendshipStatus] = []
    @State private var friends: [UserWithFriendshipStatus] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var selectedTab = 0 // 0 = All Friends, 1 = Suggestions
    @State private var searchText = ""
    @State private var showingProfile = false
    
    // Filtered data based on search
    private var filteredFriends: [UserWithFriendshipStatus] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { user in
            user.profile.displayName.localizedCaseInsensitiveContains(searchText) ||
            user.profile.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredSuggestions: [UserWithFriendshipStatus] {
        let nonFriends = allUsers.filter { user in
            user.friendshipStatus == nil || (user.friendshipStatus == .pending && !user.isIncomingRequest)
        }
        if searchText.isEmpty {
            return nonFriends
        }
        return nonFriends.filter { user in
            user.profile.displayName.localizedCaseInsensitiveContains(searchText) ||
            user.profile.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var incomingRequests: [UserWithFriendshipStatus] {
        pendingRequests.filter { $0.isIncomingRequest }
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Feed Header
                FeedHeaderView(
                    title: "Friends",
                    currentUserDisplayName: authStore.profile?.displayName ?? "User",
                    onProfileTap: {
                        showingProfile = true
                    }
                )
                
                // Header with search and tabs
                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18))
                        
                        TextField("Find friends or bucketlisters...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(24)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Segmented Buttons
                    HStack(spacing: 8) {
                        Button {
                            selectedTab = 0
                        } label: {
                            Text("All Friends")
                                .font(.system(size: 14, weight: selectedTab == 0 ? .semibold : .medium))
                                .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedTab == 0 ? Color(.systemBackground) : Color.clear)
                                .cornerRadius(24)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            selectedTab = 1
                        } label: {
                            Text("Suggestions")
                                .font(.system(size: 14, weight: selectedTab == 1 ? .semibold : .medium))
                                .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedTab == 1 ? Color(.systemBackground) : Color.clear)
                                .cornerRadius(24)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(24)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
                
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 0) {
                        // Friend Requests Section (only show if there are incoming requests)
                        if !incomingRequests.isEmpty {
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Friend Requests")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("(\(incomingRequests.count))")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    Button("See All") {
                                        // TODO: Navigate to full requests list
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                
                                // Show first 2 requests (or all if less than 2)
                                ForEach(Array(incomingRequests.prefix(2))) { request in
                                    FriendRequestRow(userWithStatus: request) {
                                        acceptRequest(request)
                                    } onDelete: {
                                        rejectRequest(request)
                                    }
                                }
                            }
                            .padding(.top, 8)
                            
                            // Divider
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                                .padding(.top, 8)
                        }
                        
                        // Main Content based on selected tab
                        if selectedTab == 0 {
                            // All Friends Tab
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Your Friends")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    // Sort dropdown (placeholder)
                                    HStack(spacing: 4) {
                                        Text("Sort by: Active")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                
                                if isLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else if filteredFriends.isEmpty {
                                    Text("No friends yet")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                } else {
                                    ForEach(filteredFriends) { friend in
                                        FriendRow(userWithStatus: friend) {
                                            // Chat action (placeholder)
                                        } onRemove: {
                                            removeFriend(friend)
                                        }
                                    }
                                }
                                
                                // Invite Friends Card
                                Button {
                                    // TODO: Invite friends action
                                } label: {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                            .frame(width: 40, height: 40)
                                            .background(Color(.systemGray5))
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Invite Friends")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.primary)
                                            Text("Share your bucketlist journey")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(16)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                            }
                            .padding(.top, 16)
                        } else {
                            // Suggestions Tab
                            VStack(alignment: .leading, spacing: 0) {
                                if isLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else if filteredSuggestions.isEmpty {
                                    Text("No suggestions")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                } else {
                                    ForEach(filteredSuggestions) { user in
                                        SuggestionRow(userWithStatus: user) {
                                            sendFriendRequest(user.profile)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 16)
                        }
                        
                        // Bottom padding
                        Spacer()
                            .frame(height: 20)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showingProfile) {
            NavigationView {
                ProfileView()
            }
        }
    }
    
    // MARK: - Friend Request Row
    
    struct FriendRequestRow: View {
        let userWithStatus: UserWithFriendshipStatus
        let onConfirm: () -> Void
        let onDelete: () -> Void
        
        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    AvatarView(name: userWithStatus.profile.displayName, size: 56)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userWithStatus.profile.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // TODO: Add mutual friends count when available
                        Text("12 mutual friends")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(timeAgoString(from: userWithStatus.profile.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Button {
                        onConfirm()
                    } label: {
                        Text("Confirm")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.blue)
                            .cornerRadius(24)
                            .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onDelete()
                    } label: {
                        Text("Delete")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color(.systemGray5))
                            .cornerRadius(24)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 72)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray5)),
                alignment: .bottom
            )
        }
        
        private func timeAgoString(from date: Date) -> String {
            let now = Date()
            let components = Calendar.current.dateComponents([.hour, .day], from: date, to: now)
            
            if let days = components.day, days > 0 {
                return "\(days)d"
            } else if let hours = components.hour, hours > 0 {
                return "\(hours)h"
            } else {
                return "now"
            }
        }
    }
    
    // MARK: - Friend Row
    
    struct FriendRow: View {
        let userWithStatus: UserWithFriendshipStatus
        let onChat: () -> Void
        let onRemove: () -> Void
        
        var body: some View {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(name: userWithStatus.profile.displayName, size: 48)
                    
                    // Online indicator (placeholder - would need real online status)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(userWithStatus.profile.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // TODO: Add activity status when available
                    Text("Online now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    onChat()
                } label: {
                    Image(systemName: "message")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                // TODO: Navigate to friend profile
            }
        }
    }
    
    // MARK: - Suggestion Row
    
    struct SuggestionRow: View {
        let userWithStatus: UserWithFriendshipStatus
        let onAdd: () -> Void
        
        var body: some View {
            HStack(spacing: 16) {
                AvatarView(name: userWithStatus.profile.displayName, size: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(userWithStatus.profile.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("@\(userWithStatus.profile.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if userWithStatus.friendshipStatus == .pending && !userWithStatus.isIncomingRequest {
                    Text("Pending")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Button {
                        onAdd()
                    } label: {
                        Text("Add")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        guard let userId = authStore.userId else {
            await MainActor.run {
                self.allUsers = []
                self.pendingRequests = []
                self.friends = []
                self.isLoading = false
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load all profiles (excluding current user)
            let allProfiles: [Profile] = try await supabaseService.client
                .from("profiles")
                .select()
                .neq("id", value: userId)
                .execute()
                .value
            
            // Load all friendships involving current user
            let friendships1: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("user_id_1", value: userId)
                .execute()
                .value
            
            let friendships2: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("user_id_2", value: userId)
                .execute()
                .value
            
            let friendships = friendships1 + friendships2
            
            // Create a map of user ID to friendship
            var friendshipMap: [UUID: Friendship] = [:]
            for friendship in friendships {
                let otherUserId = friendship.userId1 == userId ? friendship.userId2 : friendship.userId1
                friendshipMap[otherUserId] = friendship
            }
            
            // Combine profiles with friendship status
            var allUsersWithStatus: [UserWithFriendshipStatus] = []
            var pendingList: [UserWithFriendshipStatus] = []
            var friendsList: [UserWithFriendshipStatus] = []
            
            for profile in allProfiles {
                let friendship = friendshipMap[profile.id]
                let isIncoming = friendship?.userId2 == userId && friendship?.status == .pending
                
                let userWithStatus = UserWithFriendshipStatus(
                    profile: profile,
                    friendshipStatus: friendship?.status,
                    friendshipId: friendship?.id,
                    isIncomingRequest: isIncoming
                )
                
                allUsersWithStatus.append(userWithStatus)
                
                // Categorize
                if let status = friendship?.status {
                    if status == .pending {
                        pendingList.append(userWithStatus)
                    } else if status == .accepted {
                        friendsList.append(userWithStatus)
                    }
                }
            }
            
            await MainActor.run {
                self.allUsers = allUsersWithStatus
                self.pendingRequests = pendingList
                self.friends = friendsList
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.allUsers = []
                self.pendingRequests = []
                self.friends = []
                self.errorMessage = "Failed to load: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("Error loading friends data: \(error)")
        }
    }
    
    // MARK: - Friend Request Actions
    
    private func sendFriendRequest(_ profile: Profile) {
        guard let userId = authStore.userId else {
            errorMessage = "User not authenticated"
            return
        }
        
        Task {
            do {
                struct FriendRequest: Encodable {
                    let user_id_1: UUID
                    let user_id_2: UUID
                    let status: String
                }
                
                let request = FriendRequest(
                    user_id_1: userId,
                    user_id_2: profile.id,
                    status: "pending"
                )
                
                try await supabaseService.client
                    .from("friendships")
                    .insert(request)
                    .execute()
                
                await MainActor.run {
                    errorMessage = nil
                }
                
                await loadData()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to send request: \(error.localizedDescription)"
                }
                print("Error sending friend request: \(error)")
            }
        }
    }
    
    private func acceptRequest(_ userWithStatus: UserWithFriendshipStatus) {
        guard let friendshipId = userWithStatus.friendshipId else {
            Task { @MainActor in
                errorMessage = "Friendship ID not found"
            }
            return
        }
        
        Task {
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
                
                await MainActor.run {
                    errorMessage = nil
                    successMessage = "Friend request accepted!"
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000)
                await loadData()
                
                await MainActor.run {
                    selectedTab = 0
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            successMessage = nil
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to accept request: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func rejectRequest(_ userWithStatus: UserWithFriendshipStatus) {
        guard let friendshipId = userWithStatus.friendshipId else {
            Task { @MainActor in
                errorMessage = "Friendship ID not found"
            }
            return
        }
        
        Task {
            do {
                try await supabaseService.client
                    .from("friendships")
                    .delete()
                    .eq("id", value: friendshipId)
                    .execute()
                
                await MainActor.run {
                    errorMessage = nil
                    successMessage = "Request rejected"
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000)
                await loadData()
                
                await MainActor.run {
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            successMessage = nil
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to reject request: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Remove Friend
    
    private func removeFriend(_ userWithStatus: UserWithFriendshipStatus) {
        guard let friendshipId = userWithStatus.friendshipId else {
            Task { @MainActor in
                errorMessage = "Friendship ID not found"
            }
            return
        }
        
        Task {
            do {
                try await supabaseService.client
                    .from("friendships")
                    .delete()
                    .eq("id", value: friendshipId)
                    .execute()
                
                await MainActor.run {
                    errorMessage = nil
                    successMessage = "Friend removed"
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000)
                await loadData()
                
                await MainActor.run {
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            successMessage = nil
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to remove friend: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    FriendsView()
}
