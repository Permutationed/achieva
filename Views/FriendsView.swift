//
//  FriendsView.swift
//  Bucketlist
//
//  Friends view with add friends, pending requests, and friends list
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
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("All Users").tag(0)
                    Text("Pending").tag(1)
                    Text("Friends").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected tab
                List {
                    if isLoading {
                        ProgressView("Loading...")
                    } else {
                        if let errorMessage = errorMessage {
                            Section {
                                Text("Error: \(errorMessage)")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if let successMessage = successMessage {
                            Section {
                                Text(successMessage)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if errorMessage == nil {
                        switch selectedTab {
                        case 0:
                            allUsersSection
                        case 1:
                            pendingRequestsSection
                        case 2:
                            friendsSection
                        default:
                            EmptyView()
                        }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    // MARK: - All Users Section
    
    private var allUsersSection: some View {
        Group {
            if allUsers.isEmpty {
                Text("No other users found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(allUsers) { userWithStatus in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userWithStatus.profile.displayName)
                                .font(.headline)
                            Text("@\(userWithStatus.profile.username)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Show appropriate button based on friendship status
                        if let status = userWithStatus.friendshipStatus {
                            switch status {
                            case .pending:
                                if userWithStatus.isIncomingRequest {
                                    // Incoming request - show accept/reject
                                    HStack(spacing: 12) {
                                        Button {
                                            acceptRequest(userWithStatus)
                                        } label: {
                                            Text("Accept")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            rejectRequest(userWithStatus)
                                        } label: {
                                            Text("Reject")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.red)
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else {
                                    // Outgoing request - show pending
                                    Text("Pending")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            case .accepted:
                                Text("Friends")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                            case .blocked:
                                Text("Blocked")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            // No friendship - show add button
                            Button {
                                sendFriendRequest(userWithStatus.profile)
                            } label: {
                                Text("Add")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Pending Requests Section
    
    private var pendingRequestsSection: some View {
        Group {
            if pendingRequests.isEmpty {
                Text("No pending requests")
                    .foregroundColor(.secondary)
            } else {
                ForEach(pendingRequests) { userWithStatus in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userWithStatus.profile.displayName)
                                .font(.headline)
                            Text("@\(userWithStatus.profile.username)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if userWithStatus.isIncomingRequest {
                                Text("Wants to be friends")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Request sent")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        if userWithStatus.isIncomingRequest {
                            HStack(spacing: 12) {
                                Button {
                                    acceptRequest(userWithStatus)
                                } label: {
                                    Text("Accept")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    rejectRequest(userWithStatus)
                                } label: {
                                    Text("Reject")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text("Pending")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Friends Section
    
    private var friendsSection: some View {
        Group {
            if friends.isEmpty {
                Text("No friends yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(friends) { userWithStatus in
                    HStack {
                        Text(userWithStatus.profile.displayName)
                            .font(.headline)
                        Spacer()
                        Text("@\(userWithStatus.profile.username)")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
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
            // Get friendships where current user is user_id_1
            let friendships1: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("user_id_1", value: userId)
                .execute()
                .value
            
            // Get friendships where current user is user_id_2
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
                // Don't clear successMessage here - let it persist
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
                
                // Clear any previous errors
                await MainActor.run {
                    errorMessage = nil
                }
                
                // Reload data
                await loadData()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to send request: \(error.localizedDescription)"
                    successMessage = nil
                }
                print("Error sending friend request: \(error)")
            }
        }
    }
    
    private func acceptRequest(_ userWithStatus: UserWithFriendshipStatus) {
        guard let friendshipId = userWithStatus.friendshipId else {
            Task { @MainActor in
                errorMessage = "Friendship ID not found"
                successMessage = nil
            }
            return
        }
        
        print("DEBUG: Accepting friend request with ID: \(friendshipId)")
        
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
                
                print("DEBUG: Updating friendship to accepted status")
                
                try await supabaseService.client
                    .from("friendships")
                    .update(update)
                    .eq("id", value: friendshipId)
                    .execute()
                
                print("DEBUG: Friendship update successful")
                
                // Clear any previous errors and show success
                await MainActor.run {
                    errorMessage = nil
                    successMessage = "Friend request accepted!"
                }
                
                // Small delay to ensure database has committed
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Reload data to reflect the change
                await loadData()
                
                // Switch to Friends tab to show the new friend
                await MainActor.run {
                    selectedTab = 2
                    // Clear success message after a delay
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                        await MainActor.run {
                            successMessage = nil
                        }
                    }
                }
            } catch {
                print("DEBUG: Error accepting friend request: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to accept request: \(error.localizedDescription)"
                    successMessage = nil
                }
            }
        }
    }
    
    private func rejectRequest(_ userWithStatus: UserWithFriendshipStatus) {
        guard let friendshipId = userWithStatus.friendshipId else {
            Task { @MainActor in
                errorMessage = "Friendship ID not found"
                successMessage = nil
            }
            return
        }
        
        print("DEBUG: Rejecting friend request with ID: \(friendshipId)")
        
        Task {
            do {
                try await supabaseService.client
                    .from("friendships")
                    .delete()
                    .eq("id", value: friendshipId)
                    .execute()
                
                print("DEBUG: Friendship deletion successful")
                
                // Clear any previous errors
                await MainActor.run {
                    errorMessage = nil
                    successMessage = "Request rejected"
                }
                
                // Small delay to ensure database has committed
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Reload data
                await loadData()
                
                // Clear success message after a delay
                await MainActor.run {
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                        await MainActor.run {
                            successMessage = nil
                        }
                    }
                }
            } catch {
                print("DEBUG: Error rejecting friend request: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to reject request: \(error.localizedDescription)"
                    successMessage = nil
                }
            }
        }
    }
}

#Preview {
    FriendsView()
}

