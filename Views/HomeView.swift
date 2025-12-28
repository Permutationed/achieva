//
//  HomeView.swift
//  Achieva
//
//  Home feed view showing goals (goals are posts)
//

import SwiftUI
import Supabase

struct HomeView: View {
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    @State private var goals: [Goal] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingProfile = false
    @State private var showingNotifications = false

    @State private var profilesById: [UUID: Profile] = [:]
    @State private var likesByGoalId: [UUID: (count: Int, isLiked: Bool)] = [:]
    @State private var commentCountsByGoalId: [UUID: Int] = [:]
    @State private var taggedUsersByGoalId: [UUID: Set<UUID>] = [:]
    
    // Pagination state
    @State private var isLoadingMore = false
    @State private var hasMoreGoals = true
    private let pageSize = 20
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.red.opacity(0.08))
                                )
                        }

                        if isLoading && goals.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 24)
                        }
                        
                        // Empty state when no goals are available
                        if !isLoading && goals.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "target")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.secondary)
                                
                                Text("No goals yet")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                                
                                Text("Create your first goal to get started!")
                                    .font(.body)
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }

                        ForEach(goals) { goal in
                            GoalCardRowView(
                                goal: goal,
                                ownerProfile: profilesById[goal.ownerId],
                                collaboratorProfiles: [:],
                                taggedUserIds: taggedUsersByGoalId[goal.id],
                                likesData: likesByGoalId[goal.id] ?? (count: 0, isLiked: false),
                                commentsCount: commentCountsByGoalId[goal.id] ?? 0,
                                onLikeTap: {
                                    handleLikeToggle(goalId: goal.id, currentIsLiked: likesByGoalId[goal.id]?.isLiked ?? false)
                                },
                                onShareTap: {
                                    ShareHelper.shareGoal(
                                        goal: goal,
                                        ownerName: profilesById[goal.ownerId]?.fullName,
                                        isOwnGoal: goal.ownerId == authStore.userId
                                    )
                                },
                                onAppear: {
                                    // Load more when approaching the end
                                    if let index = goals.firstIndex(where: { $0.id == goal.id }),
                                       index >= goals.count - 3,
                                       hasMoreGoals,
                                       !isLoadingMore {
                                        Task {
                                            await loadMoreGoals()
                                        }
                                    }
                                }
                            )
                        }
                        
                        // Loading indicator for pagination
                        if isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if !hasMoreGoals && !goals.isEmpty {
                            Text("No more goals to load")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        }

                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .background(Color(.systemGroupedBackground))
                .navigationBarHidden(true)
                .safeAreaInset(edge: .top) {
                    FeedHeaderView(
                        title: "Achieva",
                        currentUserDisplayName: authStore.profile?.fullName ?? authStore.profile?.username ?? "You",
                        onNotificationsTap: {
                            showingNotifications = true
                        },
                        onProfileTap: {
                            showingProfile = true
                        }
                    )
                }
                .sheet(isPresented: $showingProfile) {
                    NavigationView {
                        ProfileView()
                    }
                }
                .sheet(isPresented: $showingNotifications) {
                    NotificationsView()
                }
            }
            .task {
                await loadFeed()
            }
            .refreshable {
                await loadFeed()
            }
            .onReceive(NotificationCenter.default.publisher(for: .goalPublishedNotification)) { _ in
                Task {
                    await loadFeed()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .collaborationAcceptedNotification)) { _ in
                Task {
                    await loadFeed()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .commentReceivedNotification)) { notification in
                // Refresh feed to update comment counts
                Task {
                    await loadFeed()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .likeReceivedNotification)) { notification in
                // Refresh feed to update like counts
                Task {
                    await loadFeed()
                }
            }
        }
    }
    
    private func loadFeed() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            hasMoreGoals = true
        }
        
        do {
            // Step 1: Load first page of goals
            let mainGoals = try await supabaseService.fetchGoalsWithItems(filterOwnerId: nil, limit: pageSize, offset: 0)
            let response = mainGoals
            
            // Check if there are more goals to load
            await MainActor.run {
                hasMoreGoals = response.count == pageSize
            }
            
            print("📊 Feed query returned \(response.count) goals")
            if let currentUserId = authStore.userId {
                print("   Current user ID: \(currentUserId.uuidString)")
                let ownGoals = response.filter { $0.ownerId == currentUserId }
                let otherGoals = response.filter { $0.ownerId != currentUserId }
                print("   Own goals: \(ownGoals.count), Other users' goals: \(otherGoals.count)")
            }

            // Step 3: Parallelize profile loading, status syncing, likes, and comments using async let
            let ownerIds = Array(Set(response.map(\.ownerId)))
            let goalIds = response.map { $0.id }
            
            async let ownerProfilesTask = loadProfiles(userIds: ownerIds)
            
            // Optimize: Only sync status for goals that actually need it
            let goalsToSync = response.filter { goal in
                guard let items = goal.items, !items.isEmpty else { return false }
                let allCompleted = items.allSatisfy { $0.completed }
                return (allCompleted && goal.status != .completed) || (!allCompleted && goal.status == .completed)
            }
            
            async let syncedGoalsTask: [Goal] = {
                guard !goalsToSync.isEmpty else { return response }
                
                return await withTaskGroup(of: Goal.self, returning: [Goal].self) { group in
                    var syncedMap: [UUID: Goal] = [:]
                    
                    for goal in goalsToSync {
                        group.addTask {
                            do {
                                return try await supabaseService.syncGoalStatusIfNeeded(goal: goal)
                            } catch {
                                print("Warning: Failed to sync status for goal \(goal.id): \(error)")
                                return goal
                            }
                        }
                    }
                    
                    for await syncedGoal in group {
                        syncedMap[syncedGoal.id] = syncedGoal
                    }
                    
                    return response.map { syncedMap[$0.id] ?? $0 }
                }
            }()
            async let likesDataTask = supabaseService.getLikesForGoals(goalIds: goalIds)
            async let commentCountsTask = supabaseService.getCommentCountsForGoals(goalIds: goalIds)
            async let taggedUsersTask = supabaseService.getTaggedUsersForGoals(goalIds: goalIds)
            
            // Wait for all parallel operations
            let ownerProfiles = try await ownerProfilesTask
            let profileMap = Dictionary(uniqueKeysWithValues: ownerProfiles.map { ($0.id, $0) })
            let syncedGoals = try await syncedGoalsTask
            let likesData = try await likesDataTask
            let commentCounts = try await commentCountsTask
            let taggedUsersMap = try await taggedUsersTask

            await MainActor.run {
                self.goals = syncedGoals
                self.profilesById = profileMap
                self.likesByGoalId = likesData
                self.commentCountsByGoalId = commentCounts
                self.taggedUsersByGoalId = taggedUsersMap
                self.isLoading = false
            }
        } catch is CancellationError {
            // SwiftUI frequently cancels in-flight tasks during refresh/navigation.
            // Treat as a non-error and keep existing feed content.
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            // URLSession cancellations can also surface as URLError.cancelled
            if let urlError = error as? URLError, urlError.code == .cancelled {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            // Print detailed error for debugging
            print("❌ Error loading feed: \(error)")
            if let postgrestError = error as? PostgrestError {
                print("   Postgrest error: \(postgrestError)")
            }
            if let decodingError = error as? DecodingError {
                print("   Decoding error: \(decodingError)")
            }
            await MainActor.run {
                self.errorMessage = "Failed to load feed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func loadMoreGoals() async {
        guard !isLoadingMore && hasMoreGoals else { return }
        
        await MainActor.run {
            isLoadingMore = true
        }
        
        do {
            let offset = goals.count
            let newGoals = try await supabaseService.fetchGoalsWithItems(filterOwnerId: nil, limit: pageSize, offset: offset)
            
            // Check if there are more goals
            let hasMore = newGoals.count == pageSize
            
            if newGoals.isEmpty {
                await MainActor.run {
                    hasMoreGoals = false
                    isLoadingMore = false
                }
                return
            }
            
            // Load additional data for new goals
            let ownerIds = Array(Set(newGoals.map(\.ownerId)))
            let goalIds = newGoals.map { $0.id }
            
            async let ownerProfilesTask = loadProfiles(userIds: ownerIds)
            async let likesDataTask = supabaseService.getLikesForGoals(goalIds: goalIds)
            async let commentCountsTask = supabaseService.getCommentCountsForGoals(goalIds: goalIds)
            async let taggedUsersTask = supabaseService.getTaggedUsersForGoals(goalIds: goalIds)
            
            let ownerProfiles = try await ownerProfilesTask
            let profileMap = Dictionary(uniqueKeysWithValues: ownerProfiles.map { ($0.id, $0) })
            let likesData = try await likesDataTask
            let commentCounts = try await commentCountsTask
            let taggedUsersMap = try await taggedUsersTask
            
            await MainActor.run {
                self.goals.append(contentsOf: newGoals)
                // Merge new profiles into existing dictionary
                for (id, profile) in profileMap {
                    self.profilesById[id] = profile
                }
                // Merge new likes data
                for (id, data) in likesData {
                    self.likesByGoalId[id] = data
                }
                // Merge new comment counts
                for (id, count) in commentCounts {
                    self.commentCountsByGoalId[id] = count
                }
                // Merge new tagged users
                for (id, users) in taggedUsersMap {
                    self.taggedUsersByGoalId[id] = users
                }
                self.hasMoreGoals = hasMore
                self.isLoadingMore = false
            }
        } catch is CancellationError {
            // SwiftUI frequently cancels in-flight tasks during refresh/navigation.
            // Treat as a non-error and keep existing feed content.
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            // URLSession cancellations can also surface as URLError.cancelled
            if let urlError = error as? URLError, urlError.code == .cancelled {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            // Print detailed error for debugging
            print("❌ Error loading feed: \(error)")
            if let postgrestError = error as? PostgrestError {
                print("   Postgrest error: \(postgrestError)")
            }
            if let decodingError = error as? DecodingError {
                print("   Decoding error: \(decodingError)")
            }
            await MainActor.run {
                self.errorMessage = "Failed to load feed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // Removed prefetchGoalDetail - it was causing unnecessary network calls
    // Goals are already loaded in the feed, so prefetching is redundant
    
    private func loadProfiles(userIds: [UUID]) async throws -> [Profile] {
        guard !userIds.isEmpty else { return [] }
        
        // Check cache first to avoid unnecessary network calls
        let cache = DataCache.shared
        var cachedProfiles: [Profile] = []
        var uncachedUserIds: [UUID] = []
        
        for userId in userIds {
            if let cached = cache.getCachedProfile(userId) {
                cachedProfiles.append(cached)
            } else {
                uncachedUserIds.append(userId)
            }
        }
        
        // If all profiles are cached, return them
        if uncachedUserIds.isEmpty {
            return cachedProfiles
        }
        
        // Fetch only uncached profiles (batch if needed)
        let batchSize = 100
        var allProfiles: [Profile] = []
        
        for i in stride(from: 0, to: uncachedUserIds.count, by: batchSize) {
            let batch = Array(uncachedUserIds[i..<min(i + batchSize, uncachedUserIds.count)])
            let values: [any PostgrestFilterValue] = batch.map { $0.uuidString }
            let response: [Profile] = try await supabaseService.client
                .from("profiles")
                .select("id,username,first_name,last_name,date_of_birth,created_at,updated_at")
                .in("id", values: values)
                .execute()
                .value
            allProfiles.append(contentsOf: response)
        }
        
        // Cache the newly fetched profiles
        await MainActor.run {
            for profile in allProfiles {
                cache.cacheProfile(profile)
            }
        }
        
        // Return both cached and newly fetched profiles
        return cachedProfiles + allProfiles
    }
    
    private func handleLikeToggle(goalId: UUID, currentIsLiked: Bool) {
        Task {
            do {
                if currentIsLiked {
                    try await supabaseService.unlikeGoal(goalId: goalId)
                } else {
                    try await supabaseService.likeGoal(goalId: goalId)
                }
                
                // Update local state optimistically
                await MainActor.run {
                    if var currentLikes = likesByGoalId[goalId] {
                        currentLikes.isLiked.toggle()
                        currentLikes.count += currentIsLiked ? -1 : 1
                        likesByGoalId[goalId] = currentLikes
                    } else {
                        likesByGoalId[goalId] = (count: currentIsLiked ? 0 : 1, isLiked: !currentIsLiked)
                    }
                }
                
                // Refresh likes data from server to ensure accuracy
                let updatedLikes = try await supabaseService.getLikesForGoals(goalIds: [goalId])
                await MainActor.run {
                    if let updated = updatedLikes[goalId] {
                        likesByGoalId[goalId] = updated
                    }
                }
            } catch {
                print("Error toggling like: \(error)")
                // Revert optimistic update on error
                await MainActor.run {
                    if var currentLikes = likesByGoalId[goalId] {
                        currentLikes.isLiked = currentIsLiked
                        currentLikes.count += currentIsLiked ? 1 : -1
                        likesByGoalId[goalId] = currentLikes
                    }
                }
            }
        }
    }
}

// Helper view to simplify ForEach body and help compiler type-checking
private struct GoalCardRowView: View {
    let goal: Goal
    let ownerProfile: Profile?
    let collaboratorProfiles: [UUID: Profile]
    let taggedUserIds: Set<UUID>?
    let likesData: (count: Int, isLiked: Bool)
    let commentsCount: Int
    let onLikeTap: () -> Void
    let onShareTap: () -> Void
    let onAppear: (() -> Void)?
    
    init(
        goal: Goal,
        ownerProfile: Profile?,
        collaboratorProfiles: [UUID: Profile],
        taggedUserIds: Set<UUID>?,
        likesData: (count: Int, isLiked: Bool),
        commentsCount: Int,
        onLikeTap: @escaping () -> Void,
        onShareTap: @escaping () -> Void,
        onAppear: (() -> Void)? = nil
    ) {
        self.goal = goal
        self.ownerProfile = ownerProfile
        self.collaboratorProfiles = collaboratorProfiles
        self.taggedUserIds = taggedUserIds
        self.likesData = likesData
        self.commentsCount = commentsCount
        self.onLikeTap = onLikeTap
        self.onShareTap = onShareTap
        self.onAppear = onAppear
    }
    
    var body: some View {
        NavigationLink(destination: GoalDetailView(goal: goal)) {
            FeedGoalCardView(
                goal: goal,
                ownerDisplayName: ownerProfile?.fullName,
                ownerUsername: ownerProfile?.username,
                ownerProfile: ownerProfile,
                collaboratorProfiles: collaboratorProfiles,
                taggedUserIds: taggedUserIds,
                isLiked: likesData.isLiked,
                likesCount: likesData.count,
                commentsCount: commentsCount,
                onLikeTap: onLikeTap,
                onShareTap: onShareTap
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            onAppear?()
        }
    }
}

#Preview {
    HomeView()
}
