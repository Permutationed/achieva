//
//  FriendsView.swift
//  Achieva
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
    @State private var processingRequestIds: Set<UUID> = [] // Track requests being processed
    @State private var showingFullRequestsList = false
    @State private var showingUserSearch = false
    @State private var selectedFriendProfile: UUID?
    @State private var showingFriendProfile = false
    @State private var selectedConversation: Conversation?
    @StateObject private var messagingService = MessagingService.shared
    @State private var conversations: [Conversation] = []
    @State private var goalCountsByConversationId: [UUID: Int] = [:]
    @State private var showingAddFriendsModal = false
    @State private var isLoadingConversations = false
    @State private var isCreatingConversation = false
    
    // Computed property: Friends without existing conversations
    private var friendsWithoutConversations: [UserWithFriendshipStatus] {
        guard let currentUserId = authStore.userId else { return [] }
        
        // Get user IDs from existing conversations
        let conversationUserIds = Set(conversations.compactMap { conversation in
            conversation.participants?.first(where: { $0.userId != currentUserId })?.userId
        })
        
        // Return friends who don't have conversations
        return friends.filter { friend in
            !conversationUserIds.contains(friend.profile.id)
        }
    }
    
    // Filtered data based on search
    private var filteredFriends: [UserWithFriendshipStatus] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { user in
            user.profile.fullName.localizedCaseInsensitiveContains(searchText) ||
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
            user.profile.fullName.localizedCaseInsensitiveContains(searchText) ||
            user.profile.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var incomingRequests: [UserWithFriendshipStatus] {
        pendingRequests.filter { $0.isIncomingRequest }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Sticky Header
                    VStack(spacing: 0) {
                        HStack {
                            Text("Friends")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button {
                                showingAddFriendsModal = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundColor(.primary)
                                    .frame(width: 40, height: 40)
                                    .background(Color.clear)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        
                        // Search Bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 20))
                            
                            TextField("Search friends", text: $searchText)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        
                        Divider()
                            .background(Color(.separator))
                    }
                    .background(.ultraThinMaterial)
                    .zIndex(1)
                    
                    // Scrollable Content
                    ScrollView {
                        VStack(spacing: 0) {
                            // Invite Friends Card
                            Button {
                                showingAddFriendsModal = true
                            } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.05))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 22))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Invite Friends")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Grow your achieva circle")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    ZStack {
                                        Circle()
                                            .fill(Color(.systemBackground))
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(16)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            // Suggested Section
                            VStack(spacing: 0) {
                                HStack {
                                    Text("SUGGESTED")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(0.5)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                                
                                // Horizontal scroll of suggestions
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        if filteredSuggestions.isEmpty {
                                            VStack(spacing: 8) {
                                                Image(systemName: "person.2.slash")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.secondary)
                                                
                                                Text("No suggestions available")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 20)
                                        } else {
                                            // Suggestions
                                            ForEach(Array(filteredSuggestions.prefix(4))) { suggestion in
                                                SuggestedUserView(
                                                    user: suggestion.profile,
                                                    onAdd: {
                                                        sendFriendRequest(suggestion.profile)
                                                    }
                                                )
                                            }
                                            
                                            // Find More item
                                            Button {
                                                showingUserSearch = true
                                            } label: {
                                                VStack(spacing: 8) {
                                                    ZStack {
                                                        Circle()
                                                            .stroke(Color(.systemGray4), lineWidth: 2)
                                                            .frame(width: 64, height: 64)
                                                        
                                                        Image(systemName: "person.2")
                                                            .font(.system(size: 32))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Text("Find More")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.bottom, 16)
                                
                                Divider()
                                    .background(Color(.separator).opacity(0.5))
                                    .padding(.top, 8)
                            }
                            
                            // Friend Requests Section
                            if !incomingRequests.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Text("Friend Requests")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if incomingRequests.count > 1 {
                                            Button {
                                                showingFullRequestsList = true
                                            } label: {
                                                Text("See All")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                    .padding(.bottom, 12)
                                    
                                    // Show first request inline
                                    if let firstRequest = incomingRequests.first {
                                        FriendRequestRow(
                                            userWithStatus: firstRequest,
                                            isProcessing: processingRequestIds.contains(firstRequest.friendshipId ?? UUID()),
                                            onConfirm: {
                                                acceptRequest(firstRequest)
                                            },
                                            onDelete: {
                                                rejectRequest(firstRequest)
                                            }
                                        )
                                    }
                                }
                                .padding(.bottom, 8)
                                
                                Divider()
                                    .background(Color(.separator).opacity(0.5))
                            }
                            
                            // Messages Section
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Messages")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                                
                                if isLoadingConversations {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else if conversations.isEmpty && friendsWithoutConversations.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "bubble.left.and.bubble.right")
                                            .font(.system(size: 48))
                                            .foregroundColor(.secondary)
                                        
                                        Text("No conversations yet")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Start chatting with friends to propose goals and collaborate!")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 32)
                                } else {
                                    // Show existing conversations
                                    ForEach(conversations) { conversation in
                                        ConversationRow(
                                            conversation: conversation,
                                            currentUserId: authStore.userId ?? UUID(),
                                            goalCount: goalCountsByConversationId[conversation.id],
                                            onTap: {
                                                selectedConversation = conversation
                                            },
                                            onAvatarTap: {
                                                if let otherUserId = conversation.otherParticipantProfile?.id {
                                                    selectedFriendProfile = otherUserId
                                                    showingFriendProfile = true
                                                }
                                            }
                                        )
                                    }
                                    
                                    // Show friends without conversations
                                    ForEach(friendsWithoutConversations) { friend in
                                        FriendConversationRow(
                                            friend: friend.profile,
                                            isLoading: isCreatingConversation,
                                            onTap: {
                                                Task {
                                                    await createConversationWithFriend(friendId: friend.profile.id)
                                                }
                                            },
                                            onAvatarTap: {
                                                selectedFriendProfile = friend.profile.id
                                                showingFriendProfile = true
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatView(conversation: conversation)
            }
        }
        .task {
            await loadData()
            await loadConversations()
        }
        .refreshable {
            await loadData()
            await loadConversations()
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendRequestReceivedNotification)) { _ in
            Task {
                await loadData()
            }
        }
        .fullScreenCover(isPresented: $showingAddFriendsModal) {
            AddFriendsModal(
                onSearchByUsername: {
                    showingUserSearch = true
                },
                onSuggestedFriends: {
                    showingUserSearch = true
                }
            )
        }
        .sheet(isPresented: $showingProfile) {
            NavigationView {
                ProfileView()
            }
        }
        .sheet(isPresented: $showingFullRequestsList) {
            FriendRequestsListView(
                requests: pendingRequests,
                isLoading: isLoading,
                onAccept: { request in
                    await acceptRequestAsync(request)
                },
                onReject: { request in
                    await rejectRequestAsync(request)
                },
                onRefresh: {
                    await loadData()
                }
            )
        }
        .sheet(isPresented: $showingUserSearch) {
            UserSearchView {
                // Refresh friends list after sending request
                Task {
                    await loadData()
                }
            }
        }
        .sheet(isPresented: $showingFriendProfile) {
            if let friendId = selectedFriendProfile {
                OtherUserProfileView(userId: friendId)
            }
        }
    }
    
    // MARK: - Load Conversations
    
    private func loadConversations() async {
        await MainActor.run {
            isLoadingConversations = true
        }
        
        do {
            let loadedConversations = try await messagingService.getConversations()
            print("✅ FriendsView: Loaded \(loadedConversations.count) conversations")
            
            // Load goal counts for conversations (non-blocking - don't fail if this errors)
            let conversationIds = loadedConversations.map { $0.id }
            let goalCounts = try? await supabaseService.getGoalCountsForConversations(conversationIds: conversationIds)
            
            await MainActor.run {
                conversations = loadedConversations
                goalCountsByConversationId = goalCounts ?? [:]
                isLoadingConversations = false
            }
        } catch {
            // Handle cancellation errors gracefully (they're not real errors)
            if let urlError = error as? URLError, urlError.code == .cancelled {
                print("⚠️ Conversation loading cancelled (this is normal when navigating quickly)")
                await MainActor.run {
                    isLoadingConversations = false
                    // Don't set error message for cancellations
                }
                return
            }
            
            print("❌ Error loading conversations: \(error)")
            if let decodingError = error as? DecodingError {
                print("   Decoding error details: \(decodingError)")
            }
            await MainActor.run {
                isLoadingConversations = false
                errorMessage = "Failed to load conversations: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Friend Conversation Row (for friends without conversations)
    
    struct FriendConversationRow: View {
        let friend: Profile
        let isLoading: Bool
        let onTap: () -> Void
        let onAvatarTap: (() -> Void)?
        
        init(friend: Profile, isLoading: Bool, onTap: @escaping () -> Void, onAvatarTap: (() -> Void)? = nil) {
            self.friend = friend
            self.isLoading = isLoading
            self.onTap = onTap
            self.onAvatarTap = onAvatarTap
        }
        
        var body: some View {
            Button {
                onTap()
            } label: {
                HStack(spacing: 16) {
                    // Avatar - clickable to view profile
                    Button {
                        onAvatarTap?()
                    } label: {
                        AvatarView(name: friend.fullName, size: 56, avatarUrl: friend.avatarUrl)
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Name
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(friend.fullName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        // "Start conversation" text
                        Text("Start conversation")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color(.systemBackground))
            .disabled(isLoading)
        }
    }
    
    // MARK: - Friend Request Row
    
    struct FriendRequestRow: View {
        let userWithStatus: UserWithFriendshipStatus
        let isProcessing: Bool
        let onConfirm: () -> Void
        let onDelete: () -> Void
        
        var body: some View {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    AvatarView(name: userWithStatus.profile.fullName, size: 56, avatarUrl: userWithStatus.profile.avatarUrl)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userWithStatus.profile.fullName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("@\(userWithStatus.profile.username)")
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
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Confirm")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(isProcessing ? Color.blue.opacity(0.6) : Color.blue)
                        .cornerRadius(24)
                        .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                    
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
                    .disabled(isProcessing)
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
    
    // MARK: - Suggested User View
    
    struct SuggestedUserView: View {
        let user: Profile
        let onAdd: () -> Void
        @State private var isAdded = false
        
        var body: some View {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(name: user.fullName, size: 64, avatarUrl: user.avatarUrl)
                    
                    // Plus button / Checkmark overlay
                    Button {
                        if !isAdded {
                            isAdded = true
                            onAdd()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isAdded ? Color.green : Color.blue)
                                .frame(width: 24, height: 24)
                            
                            if isAdded {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 2, y: 2)
                }
                
                Text(user.fullName.components(separatedBy: " ").first ?? user.fullName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 72)
            }
        }
    }
    
    // MARK: - Friend Row
    
    struct FriendRow: View {
        let userWithStatus: UserWithFriendshipStatus
        let onChat: () -> Void
        let onRemove: () -> Void
        let onTap: () -> Void
        
        var body: some View {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(name: userWithStatus.profile.fullName, size: 48, avatarUrl: userWithStatus.profile.avatarUrl)
                    
                    // Online indicator removed - not implemented yet
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(userWithStatus.profile.fullName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Show username instead of online status (online status not implemented)
                    Text("@\(userWithStatus.profile.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Message button
                Button {
                    onChat()
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }
    
    private func startChat(with friend: Profile) async {
        print("💬 FriendsView: Starting chat with friend: \(friend.fullName) (\(friend.id))")
        do {
            let conversation = try await messagingService.createDirectConversation(with: friend.id)
            print("✅ FriendsView: Conversation created/retrieved: \(conversation.id)")
            await MainActor.run {
                selectedConversation = conversation
                print("✅ FriendsView: selectedConversation set to: \(conversation.id)")
            }
        } catch {
            print("❌ FriendsView: Error starting chat: \(error)")
            await MainActor.run {
                errorMessage = "Failed to start conversation: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Suggestion Row
    
    struct SuggestionRow: View {
        let userWithStatus: UserWithFriendshipStatus
        let onAdd: () -> Void
        
        var body: some View {
            HStack(spacing: 16) {
                AvatarView(name: userWithStatus.profile.fullName, size: 48, avatarUrl: userWithStatus.profile.avatarUrl)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(userWithStatus.profile.fullName)
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
                // Don't clear existing data if not authenticated - might be temporary
                self.isLoading = false
            }
            return
        }
        
        // Only set loading if we don't have cached data
        let hasCachedData = !friends.isEmpty || !pendingRequests.isEmpty
        await MainActor.run {
            isLoading = !hasCachedData
            errorMessage = nil
        }
        
        do {
            // Load all profiles (excluding current user)
            let allProfiles: [Profile] = try await supabaseService.client
                .from("profiles")
                .select("id,username,first_name,last_name,date_of_birth,avatar_url,created_at,updated_at")
                .neq("id", value: userId)
                .execute()
                .value
            
            // Load all friendships involving current user (excluding blocked)
            // Query friendships where current user is user_id_1
            let friendships1: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("user_id_1", value: userId)
                .neq("status", value: "blocked")
                .execute()
                .value
            
            // Query friendships where current user is user_id_2
            let friendships2: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("user_id_2", value: userId)
                .neq("status", value: "blocked")
                .execute()
                .value
            
            let friendships = friendships1 + friendships2
            
            print("📊 FriendsView: Loaded \(friendships.count) total friendships")
            print("   user_id_1 matches: \(friendships1.count), user_id_2 matches: \(friendships2.count)")
            let acceptedFriendships = friendships.filter { $0.status == .accepted }
            let pendingFriendships = friendships.filter { $0.status == .pending }
            print("   Accepted: \(acceptedFriendships.count), Pending: \(pendingFriendships.count)")
            
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
            
            print("📊 FriendsView: Categorized users")
            print("   Total users: \(allUsersWithStatus.count)")
            print("   Friends: \(friendsList.count)")
            print("   Pending requests: \(pendingList.count)")
            
            await MainActor.run {
                self.allUsers = allUsersWithStatus
                self.pendingRequests = pendingList
                self.friends = friendsList
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            // Don't clear existing data on error - preserve cache
            await MainActor.run {
                self.errorMessage = "Failed to load: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("Error loading friends data: \(error)")
            print("⚠️ Preserving existing friends data: \(friends.count) friends, \(pendingRequests.count) pending")
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
            Task {
                await MainActor.run {
                    errorMessage = "Friendship ID not found"
                }
            }
            return
        }
        
        // Prevent duplicate requests
        guard !processingRequestIds.contains(friendshipId) else { return }
        
        Task {
            // Mark as processing
            await MainActor.run {
                processingRequestIds.insert(friendshipId)
                errorMessage = nil
            }
            
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
                
                // Immediately refresh data (no delay)
                await loadData()
                
                await MainActor.run {
                    processingRequestIds.remove(friendshipId)
                    successMessage = "Friend request accepted!"
                    selectedTab = 0 // Switch to friends tab to show the new friend
                    
                    // Clear success message after 3 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            successMessage = nil
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    processingRequestIds.remove(friendshipId)
                    errorMessage = "Failed to accept request: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func acceptRequestAsync(_ userWithStatus: UserWithFriendshipStatus) async {
        guard let friendshipId = userWithStatus.friendshipId else {
            await MainActor.run {
                errorMessage = "Friendship ID not found"
            }
            return
        }
        
        // Prevent duplicate requests
        guard !processingRequestIds.contains(friendshipId) else { return }
        
        // Mark as processing
        await MainActor.run {
            processingRequestIds.insert(friendshipId)
            errorMessage = nil
        }
        
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
            
            // Immediately refresh data
            await loadData()
            
            await MainActor.run {
                processingRequestIds.remove(friendshipId)
                successMessage = "Friend request accepted!"
                selectedTab = 0 // Switch to friends tab to show the new friend
                
                // Clear success message after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        successMessage = nil
                    }
                }
            }
        } catch {
            await MainActor.run {
                processingRequestIds.remove(friendshipId)
                errorMessage = "Failed to accept request: \(error.localizedDescription)"
            }
        }
    }
    
    private func rejectRequestAsync(_ userWithStatus: UserWithFriendshipStatus) async {
        guard let friendshipId = userWithStatus.friendshipId else {
            await MainActor.run {
                errorMessage = "Friendship ID not found"
            }
            return
        }
        
        // Prevent duplicate requests
        guard !processingRequestIds.contains(friendshipId) else { return }
        
        // Mark as processing
        await MainActor.run {
            processingRequestIds.insert(friendshipId)
            errorMessage = nil
        }
        
        do {
            try await supabaseService.client
                .from("friendships")
                .delete()
                .eq("id", value: friendshipId)
                .execute()
            
            // Immediately refresh data
            await loadData()
            
            await MainActor.run {
                processingRequestIds.remove(friendshipId)
                successMessage = "Request rejected"
                
                // Clear success message after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        successMessage = nil
                    }
                }
            }
        } catch {
            await MainActor.run {
                processingRequestIds.remove(friendshipId)
                errorMessage = "Failed to reject request: \(error.localizedDescription)"
            }
        }
    }
    
    private func rejectRequest(_ userWithStatus: UserWithFriendshipStatus) {
        guard let friendshipId = userWithStatus.friendshipId else {
            Task {
                await MainActor.run {
                    errorMessage = "Friendship ID not found"
                }
            }
            return
        }
        
        // Prevent duplicate requests
        guard !processingRequestIds.contains(friendshipId) else { return }
        
        Task {
            // Mark as processing
            await MainActor.run {
                processingRequestIds.insert(friendshipId)
                errorMessage = nil
            }
            
            do {
                try await supabaseService.client
                    .from("friendships")
                    .delete()
                    .eq("id", value: friendshipId)
                    .execute()
                
                // Immediately refresh data (no delay)
                await loadData()
                
                await MainActor.run {
                    processingRequestIds.remove(friendshipId)
                    successMessage = "Request rejected"
                    
                    // Clear success message after 3 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            successMessage = nil
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    processingRequestIds.remove(friendshipId)
                    errorMessage = "Failed to reject request: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Create Conversation with Friend
    
    private func createConversationWithFriend(friendId: UUID) async {
        guard !isCreatingConversation else { return }
        
        await MainActor.run {
            isCreatingConversation = true
        }
        
        do {
            let conversation = try await messagingService.createDirectConversation(with: friendId)
            print("✅ Created conversation with friend: \(friendId)")
            
            // Reload conversations to include the new one
            await loadConversations()
            
            // Navigate to the new conversation
            await MainActor.run {
                selectedConversation = conversation
                isCreatingConversation = false
            }
        } catch {
            print("❌ Error creating conversation: \(error)")
            await MainActor.run {
                isCreatingConversation = false
                errorMessage = "Failed to start conversation: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Remove Friend
    
    private func removeFriend(_ userWithStatus: UserWithFriendshipStatus) {
        guard let friendshipId = userWithStatus.friendshipId else {
            Task {
                await MainActor.run {
                    errorMessage = "Friendship ID not found"
                }
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
                
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        successMessage = nil
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
