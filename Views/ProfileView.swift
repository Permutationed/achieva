//
//  ProfileView.swift
//  Achieva
//
//  Profile view redesigned to match HTML design
//

import SwiftUI
import Supabase

struct ProfileView: View {
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditProfile = false
    @State private var goals: [Goal] = []
    @State private var draftGoals: [Goal] = []
    @State private var friendsCount: Int = 0
    @State private var isLoading = false
    @State private var isLoadingDrafts = false
    @State private var selectedCategory: String = "All Goals"
    @State private var showingCreateGoal = false
    @State private var editingGoal: Goal?
    @State private var showingDeleteConfirmation = false
    @State private var goalToDelete: Goal?
    @State private var isLoadingRequests = false
    @State private var likesByGoalId: [UUID: (count: Int, isLiked: Bool)] = [:]
    @State private var commentCountsByGoalId: [UUID: Int] = [:]
    @State private var taggedUsersByGoalId: [UUID: Set<UUID>] = [:]
    @State private var showingNotifications = false
    @State private var unreadNotificationCount = 0
    
    // Pagination state
    @State private var isLoadingMore = false
    @State private var hasMoreGoals = true
    private let pageSize = 20
    
    var filteredGoals: [Goal] {
        switch selectedCategory {
        case "Active Goals":
            return goals.filter { $0.status == .active && !$0.isDraft }
        case "Completed Goals":
            return goals.filter { $0.status == .completed && !$0.isDraft }
        case "Drafts":
            return draftGoals
        default: // "All Goals"
            return goals.filter { !$0.isDraft }
        }
    }
    
    var goalsCount: Int {
        filteredGoals.count
    }
    
    var totalLikes: Int {
        likesByGoalId.values.reduce(0) { $0 + $1.count }
    }
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Profile Section
                        VStack(spacing: 16) {
                            // Avatar with edit button
                            ZStack(alignment: .bottomTrailing) {
                                AvatarView(
                                    name: authStore.profile?.fullName ?? "User",
                                    size: 96,
                                    avatarUrl: authStore.profile?.avatarUrl
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray5), lineWidth: 2)
                                )
                                
                                Button {
                                    showingEditProfile = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color(.systemBackground), lineWidth: 3)
                                        )
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: 4)
                            }
                            
                            // Name and username
                            VStack(spacing: 8) {
                                Text(authStore.profile?.fullName ?? "User")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("@\(authStore.profile?.username ?? "username")")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                // Bio placeholder (no bio field in Profile model yet)
                                if authStore.profile != nil {
                                    Text("")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 280)
                                }
                            }
                            
                            // Stats Grid
                            HStack(spacing: 12) {
                                StatCard(value: "\(goalsCount)", label: "Goals")
                                StatCard(value: "\(friendsCount)", label: "Friends")
                                StatCard(value: "\(totalLikes)", label: "Likes")
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        
                        // Category Filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                CategoryChip(title: "All Goals", isSelected: selectedCategory == "All Goals") {
                                    selectedCategory = "All Goals"
                                }
                                CategoryChip(title: "Active", isSelected: selectedCategory == "Active Goals") {
                                    selectedCategory = "Active Goals"
                                }
                                CategoryChip(title: "Completed", isSelected: selectedCategory == "Completed Goals") {
                                    selectedCategory = "Completed Goals"
                                }
                                CategoryChip(title: "Archived", isSelected: selectedCategory == "Archived Goals") {
                                    selectedCategory = "Archived Goals"
                                }
                                CategoryChip(title: "Drafts", isSelected: selectedCategory == "Drafts") {
                                    selectedCategory = "Drafts"
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 16)
                        
                        // Bucket List Section (Goals)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Bucket List")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("\(goalsCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 24)
                            
                            if isLoading && goals.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else if filteredGoals.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 48))
                                        .foregroundStyle(Color.secondary)
                                    Text(goals.isEmpty ? "No goals yet" : "No \(selectedCategory.lowercased())")
                                        .font(.headline)
                                        .foregroundStyle(Color.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(filteredGoals) { goal in
                                        NavigationLink(destination: GoalDetailView(goal: goal)) {
                                            let likesData = likesByGoalId[goal.id] ?? (count: 0, isLiked: false)
                                            FeedGoalCardView(
                                                goal: goal,
                                                ownerDisplayName: authStore.profile?.fullName,
                                                ownerUsername: authStore.profile?.username,
                                                ownerProfile: authStore.profile,
                                                collaboratorProfiles: [:],
                                                taggedUserIds: taggedUsersByGoalId[goal.id],
                                                isLiked: likesData.isLiked,
                                                likesCount: likesData.count,
                                                commentsCount: commentCountsByGoalId[goal.id] ?? 0,
                                                onLikeTap: {
                                                    handleLikeToggle(goalId: goal.id, currentIsLiked: likesData.isLiked)
                                                },
                                                onShareTap: {
                                                    ShareHelper.shareGoal(
                                                        goal: goal,
                                                        ownerName: authStore.profile?.fullName,
                                                        isOwnGoal: true
                                                    )
                                                }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier(goal.title)
                                        .onAppear {
                                            // Load more when approaching the end (only for "All Goals" or "Active Goals")
                                            if (selectedCategory == "All Goals" || selectedCategory == "Active Goals"),
                                               let index = filteredGoals.firstIndex(where: { $0.id == goal.id }),
                                               index >= filteredGoals.count - 3,
                                               hasMoreGoals,
                                               !isLoadingMore {
                                                Task {
                                                    await loadMoreProfileGoals()
                                                }
                                            }
                                        }
                                        .contextMenu {
                                            Button {
                                                editingGoal = goal
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            
                                            if goal.isDraft {
                                                Button {
                                                    Task {
                                                        await publishDraft(goal)
                                                    }
                                                } label: {
                                                    Label("Publish", systemImage: "paperplane")
                                                }
                                            }
                                            
                                            Button(role: .destructive) {
                                                goalToDelete = goal
                                                showingDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                    
                                    // Loading indicator for pagination
                                    if isLoadingMore {
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                    } else if !hasMoreGoals && !filteredGoals.isEmpty && (selectedCategory == "All Goals" || selectedCategory == "Active Goals") {
                                        Text("No more goals to load")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding()
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 24)
                        
                        // Bottom spacing
                        Spacer()
                            .frame(height: 100)
                    }
                }
                .navigationBarHidden(true)
                .safeAreaInset(edge: .top) {
                    ZStack(alignment: .leading) {
                        FeedHeaderView(
                            title: "Your Profile",
                            currentUserDisplayName: authStore.profile?.fullName ?? authStore.profile?.username ?? "You",
                            currentUserAvatarUrl: authStore.profile?.avatarUrl,
                            unreadNotificationCount: unreadNotificationCount,
                            onNotificationsTap: {
                                showingNotifications = true
                            },
                            onProfileTap: {
                                showingEditProfile = true
                            }
                        )
                    }
                }
                
                // Floating Action Button
                Button {
                    showingCreateGoal = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.blue))
                        .shadow(color: Color.blue.opacity(0.25), radius: 14, x: 0, y: 10)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 18)
                .accessibilityLabel(Text("Create goal"))
                .accessibilityIdentifier("CreateGoalButton")
            }
        }
        .task {
            await loadProfileData()
            await loadDrafts()
        }
        .refreshable {
            await loadProfileData()
            await loadDrafts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goalPublishedNotification)) { _ in
            Task {
                await loadProfileData()
                await loadDrafts()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .draftCreatedNotification)) { notification in
            // Immediately add the draft to local cache
            if let goal = notification.userInfo?["goal"] as? Goal {
                Task {
                    await MainActor.run {
                        // Add to draftGoals if not already present
                        if !draftGoals.contains(where: { $0.id == goal.id }) {
                            draftGoals.insert(goal, at: 0) // Insert at beginning
                            print("✅ Added draft to local cache: \(goal.title)")
                        }
                    }
                    
                    // Also load full details in background to ensure we have everything
                    await loadDrafts()
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
                .onDisappear {
                    Task {
                        await loadProfileData()
                    }
                }
        }
        .sheet(isPresented: $showingCreateGoal) {
            CreateGoalView()
                .onDisappear {
                    Task {
                        // Refresh both published goals and drafts
                        await loadDrafts()
                        await loadProfileData()
                    }
                }
        }
        .sheet(item: $editingGoal) { goal in
            EditGoalView(goal: goal)
                .onDisappear {
                    Task {
                        await loadProfileData()
                    }
                }
        }
        .alert("Delete Goal", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                goalToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let goal = goalToDelete {
                    deleteGoal(goal)
                }
                goalToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this goal? This action cannot be undone.")
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        .onChange(of: showingNotifications) { oldValue, newValue in
            if oldValue && !newValue {
                // Sheet was dismissed, refresh the count
                Task {
                    await loadUnreadNotifications()
                }
            }
        }
        .task {
            await loadProfileData()
            await loadDrafts()
            await loadUnreadNotifications()
        }
    }
    
    private func loadUnreadNotifications() async {
        guard let userId = authStore.userId else { return }
        
        do {
            let count = try await supabaseService.getUnreadNotificationCount(userId: userId)
            await MainActor.run {
                unreadNotificationCount = count
            }
        } catch {
            print("Error loading unread notification count: \(error)")
        }
    }
    
    private func loadProfileData() async {
        guard let userId = authStore.userId else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            guard let currentUserId = authStore.userId else {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            // Step 1: Load first page of owned goals and friends count in parallel
            async let ownedGoalsTask = supabaseService.fetchGoalsWithItems(filterOwnerId: currentUserId, limit: pageSize, offset: 0)
            
            async let friendsCountTask: Int = {
                let friendships: [Friendship] = try await supabaseService.client
                    .from("friendships")
                    .select()
                    .or("user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(userId.uuidString)")
                    .eq("status", value: "accepted")
                    .execute()
                    .value
                return friendships.count
            }()
            
            // Wait for parallel loads
            let ownedGoals = try await ownedGoalsTask
            let friendsCount = try await friendsCountTask
            
            // Filter out drafts
            let goalsResponse = ownedGoals.filter { !$0.isDraft }
            
            // Check if there are more goals to load
            await MainActor.run {
                hasMoreGoals = goalsResponse.count == pageSize
            }
            
            print("📊 Profile: Loaded \(goalsResponse.count) published owned goals")
            
            // Step 2: Batch load all collaborators for all goals (already included from fetchGoalsWithItems)
            // Goals from fetchGoalsWithItems already have collaborators loaded, so we can use them directly
            var goalsWithCollaborators = goalsResponse
            
            // Step 3: Parallelize status syncing, collaboration requests, likes, and comments
            let goalIds = goalsWithCollaborators.map { $0.id }
            
            // Optimize: Only sync status for goals that actually need it
            let goalsToSync = goalsWithCollaborators.filter { goal in
                guard let items = goal.items, !items.isEmpty else { return false }
                let allCompleted = items.allSatisfy { $0.completed }
                return (allCompleted && goal.status != .completed) || (!allCompleted && goal.status == .completed)
            }
            
            async let syncedGoalsTask: [Goal] = {
                guard !goalsToSync.isEmpty else { return goalsWithCollaborators }
                
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
                    
                    return goalsWithCollaborators.map { syncedMap[$0.id] ?? $0 }
                }
            }()
            
            async let likesDataTask = supabaseService.getLikesForGoals(goalIds: goalIds)
            async let commentCountsTask = supabaseService.getCommentCountsForGoals(goalIds: goalIds)
            async let taggedUsersTask = supabaseService.getTaggedUsersForGoals(goalIds: goalIds)
            
            // Wait for parallel operations
            let syncedGoals = try await syncedGoalsTask
            let likesData = try await likesDataTask
            let commentCounts = try await commentCountsTask
            let taggedUsersMap = try await taggedUsersTask
            
            await MainActor.run {
                self.goals = syncedGoals
                self.taggedUsersByGoalId = taggedUsersMap
                self.friendsCount = friendsCount
                self.likesByGoalId = likesData
                self.commentCountsByGoalId = commentCounts
                self.isLoading = false
            }
        } catch is CancellationError {
            // SwiftUI frequently cancels in-flight tasks during refresh/navigation.
            // Treat as a non-error and keep existing profile content.
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
            
            // Only log/show actual errors, not cancellations
            await MainActor.run {
                self.isLoading = false
            }
            print("Error loading profile data: \(error)")
        }
    }
    
    private func loadMoreProfileGoals() async {
        guard !isLoadingMore && hasMoreGoals, let userId = authStore.userId else { return }
        
        await MainActor.run {
            isLoadingMore = true
        }
        
        do {
            let offset = goals.count
            let newGoals = try await supabaseService.fetchGoalsWithItems(filterOwnerId: userId, limit: pageSize, offset: offset)
            
            // Filter out drafts
            let newPublishedGoals = newGoals.filter { !$0.isDraft }
            
            // Check if there are more goals
            let hasMore = newPublishedGoals.count == pageSize
            
            if newPublishedGoals.isEmpty {
                await MainActor.run {
                    hasMoreGoals = false
                    isLoadingMore = false
                }
                return
            }
            
            // Load additional data for new goals
            let goalIds = newPublishedGoals.map { $0.id }
            
            async let likesDataTask = supabaseService.getLikesForGoals(goalIds: goalIds)
            async let commentCountsTask = supabaseService.getCommentCountsForGoals(goalIds: goalIds)
            async let taggedUsersTask = supabaseService.getTaggedUsersForGoals(goalIds: goalIds)
            
            let likesData = try await likesDataTask
            let commentCounts = try await commentCountsTask
            let taggedUsersMap = try await taggedUsersTask
            
            await MainActor.run {
                self.goals.append(contentsOf: newPublishedGoals)
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
        } catch {
            print("Error loading more profile goals: \(error)")
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }
    
    private func deleteGoal(_ goal: Goal) {
        Task {
            do {
                try await supabaseService.client
                    .from("goals")
                    .delete()
                    .eq("id", value: goal.id)
                    .execute()
                
                _ = await MainActor.run {
                    Task {
                        await loadProfileData()
                    }
                }
            } catch {
                print("Error deleting goal: \(error)")
            }
        }
    }
    
    
    
    private func loadDrafts() async {
        guard let userId = authStore.userId else { return }
        
        // Don't show loading if we already have drafts cached (optimistic update)
        let hasCachedDrafts = await MainActor.run {
            return !draftGoals.isEmpty
        }
        
        if !hasCachedDrafts {
            await MainActor.run {
                isLoadingDrafts = true
            }
        }
        
        do {
            print("📝 ProfileView: Starting to load drafts for user \(userId)")
            let drafts = try await supabaseService.fetchDraftGoals(forUserId: userId)
            print("📝 ProfileView: Successfully fetched \(drafts.count) drafts")
            
            await MainActor.run {
                // Merge with existing drafts (preserve optimistically added drafts)
                var mergedDrafts = drafts
                
                // Add any drafts that are in draftGoals but not in the fetched list
                // This preserves drafts that were just created but might not be in the DB yet
                // IMPORTANT: Only preserve cached drafts that are still drafts (isDraft == true)
                for existingDraft in self.draftGoals {
                    // Only add if it's still a draft and not already in the merged list
                    if existingDraft.isDraft && !mergedDrafts.contains(where: { $0.id == existingDraft.id }) {
                        mergedDrafts.insert(existingDraft, at: 0)
                    }
                }
                
                // Remove duplicates and sort by created_at (newest first)
                // Filter to only include actual drafts (isDraft == true)
                var uniqueDrafts: [Goal] = []
                var seenIds: Set<UUID> = []
                for draft in mergedDrafts.sorted(by: { $0.createdAt > $1.createdAt }) {
                    // Only include if it's a draft and we haven't seen it before
                    if draft.isDraft && !seenIds.contains(draft.id) {
                        uniqueDrafts.append(draft)
                        seenIds.insert(draft.id)
                    }
                }
                
                self.draftGoals = uniqueDrafts
                self.isLoadingDrafts = false
            }
        } catch is CancellationError {
            // SwiftUI frequently cancels in-flight tasks during refresh/navigation.
            // Treat as a non-error and keep existing draft content.
            await MainActor.run {
                self.isLoadingDrafts = false
            }
        } catch {
            // URLSession cancellations can also surface as URLError.cancelled
            if let urlError = error as? URLError, urlError.code == .cancelled {
                await MainActor.run {
                    self.isLoadingDrafts = false
                }
                return
            }
            
            // Only log/show actual errors, not cancellations
            print("❌ Error loading drafts: \(error)")
            print("   Error type: \(type(of: error))")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key: \(key.stringValue)")
                    print("   Context: \(context.debugDescription)")
                    print("   Coding path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: \(type)")
                    print("   Context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type)")
                    print("   Context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("   Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            await MainActor.run {
                // Don't clear existing drafts on error - preserve cached drafts
                // Only clear if we have no cached drafts
                if self.draftGoals.isEmpty {
                    self.draftGoals = []
                }
                self.isLoadingDrafts = false
            }
        }
    }
    
    private func publishDraft(_ goal: Goal) async {
        do {
                    try await supabaseService.publishDraft(goalId: goal.id)
            await loadDrafts()
            await loadProfileData()
        } catch {
            print("Error publishing draft: \(error)")
        }
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

// Stat Card Component
private struct StatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// Category Chip Component
private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .blue : .secondary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
        .accessibilityLabel(title)
    }
}


#Preview {
    ProfileView()
}
