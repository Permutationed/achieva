//
//  GoalDetailView.swift
//  Achieva
//
//  Goal detail view - UI redesign only (keeps same endpoints + data flow)
//

import SwiftUI
import UIKit

struct GoalDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var supabaseService = SupabaseService.shared
    @StateObject private var authStore = AuthStore.shared

    let goal: Goal

    // Data
    @State private var items: [GoalItem] = []
    @State private var isLoading = false
    @State private var ownerProfile: Profile?
    @State private var ownerGoalsCount: Int = 0
    @State private var isLiked: Bool = false
    @State private var likesCount: Int = 0
    @State private var isTogglingLike = false

    // UI state
    @State private var showingEditGoal = false
    @State private var showingMenu = false
    @State private var showingOwnerProfile = false

    // Add item
    @State private var newItemTitle = ""
    @State private var isAddingItem = false
    @State private var isSavingItem = false

    // Status / permissions
    @State private var currentGoalStatus: GoalStatus
    @State private var canEdit = false
    @State private var isOwner = false
    
    // Tagged users
    @State private var taggedUsers: [Profile] = []
    @State private var isLoadingTaggedUsers = false
    
    // Publishing state
    @State private var isPublishing = false
    @State private var publishError: String?
    @State private var showingPublishError = false
    @State private var showingPublishSuccess = false

    init(goal: Goal) {
        self.goal = goal
        self._currentGoalStatus = State(initialValue: goal.status)
        // Initialize items from goal if available (prevents loading skeleton flash)
        self._items = State(initialValue: goal.items ?? [])
        // Initialize isOwner synchronously based on goal data
        // This ensures the view shows correctly immediately
        if let userId = AuthStore.shared.userId {
            self._isOwner = State(initialValue: goal.ownerId == userId)
        } else {
            self._isOwner = State(initialValue: false)
        }
    }

    // MARK: - Derived
    private var completedItemsCount: Int { items.filter { $0.completed }.count }
    private var incompleteItems: [GoalItem] { items.filter { !$0.completed } }
    private var completedItems: [GoalItem] { items.filter { $0.completed } }
    private var nextItem: GoalItem? { incompleteItems.first }
    
    // Computed property to check ownership synchronously
    private var isViewingOtherUsersGoal: Bool {
        guard let userId = authStore.userId else { return true }
        return goal.ownerId != userId
    }

    private var progressPercentage: Double {
        // For other people's completed goals, show full progress
        if isViewingOtherUsersGoal && currentGoalStatus == .completed {
            return 1.0
        }
        guard !items.isEmpty else { return 0 }
        return Double(completedItemsCount) / Double(items.count)
    }

    private var allItemsCompleted: Bool {
        !items.isEmpty && items.allSatisfy { $0.completed }
    }

    private var headerSubtitle: String {
        if items.isEmpty { return "Add a step to get moving." }
        if allItemsCompleted { return "Complete • Nice work." }
        if items.count == 1 { return completedItemsCount == 1 ? "Complete • Nice work." : "1 step • Let’s do it." }
        return "\(completedItemsCount) of \(items.count) completed"
    }

    private var momentumCopy: String {
        if items.isEmpty { return "Start with one small step." }
        if allItemsCompleted { return "Locked in. Want to run it back next week?" }
        if incompleteItems.count == 1 { return "One more. Finish strong." }
        if completedItemsCount == 0 { return "Let’s start. Knock out the first one." }
        return ""
    }

    // MARK: - View
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Top nav row (minimal, quiet)
                    topNavRow
                        .padding(.horizontal, 18)
                        .padding(.top, 10)

                    // Hero Image Section (if cover image exists)
                    if let coverImageUrl = goal.coverImageUrl, !coverImageUrl.isEmpty {
                        heroImageSection
                            .padding(.horizontal, 18)
                    }

                    // Hero header
                    heroHeader
                        .padding(.horizontal, 18)
                        .padding(.top, goal.coverImageUrl == nil ? 6 : 12)

                    // Tagged Users Section (prominent location)
                    if !taggedUsers.isEmpty {
                        taggedUsersSection
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                    }

                    // Progress + microcopy
                    progressBlock
                        .padding(.horizontal, 18)

                    // Owner Context (if viewing someone else's goal)
                    if isViewingOtherUsersGoal {
                        ownerContextCard
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                    }

                    // Next Up (if any) - only show for owner
                    if isOwner {
                        if let next = nextItem {
                            nextUpCard(next)
                                .padding(.horizontal, 18)
                        } else if items.isEmpty {
                            emptyNextUp
                                .padding(.horizontal, 18)
                        }
                    }

                    // Items
                    itemsBlock
                        .padding(.horizontal, 18)

                    // Comments section (only for published goals)
                    if !goal.isDraft {
                        CommentsSection(
                            goalId: goal.id,
                            currentUserId: authStore.userId
                        )
                        .padding(.horizontal, 18)
                    }

                    // Completion moment
                    if allItemsCompleted {
                        completionCard
                            .padding(.horizontal, 18)
                    }

                    // Bottom padding
                    Color.clear
                        .frame(height: 30)
                }
                .padding(.bottom, 96) // room for add composer
            }

            // Bottom add composer (primary action)
            bottomComposer
        }
        .navigationBarHidden(true)
        .task {
            // Parallelize all data loading
            if isViewingOtherUsersGoal {
                // Load owner profile, tagged users, and likes in parallel
                async let ownerProfileTask = loadOwnerProfile()
                async let taggedUsersTask = loadTaggedUsers()
                async let likesTask = loadLikes()
                
                // Load items (non-blocking, starts Task internally)
                loadItems()
                
                // Wait for parallel operations
                await ownerProfileTask
                await taggedUsersTask
                await likesTask
            } else {
                // Load tagged users and likes in parallel
                async let taggedUsersTask = loadTaggedUsers()
                async let likesTask = loadLikes()
                
                // Load items (non-blocking, starts Task internally)
                loadItems()
                
                // Wait for parallel operations
                await taggedUsersTask
                await likesTask
            }
            
            // Sync status and check permissions after data is loaded
            await syncGoalStatusOnAppear()
            await checkPermissions()
        }
        .sheet(isPresented: $showingOwnerProfile) {
            if let profileToView = ownerProfile {
                OtherUserProfileView(userId: profileToView.id)
            }
        }
        .sheet(isPresented: $showingEditGoal) {
            EditGoalView(goal: goal)
        }
        .confirmationDialog("Goal Options", isPresented: $showingMenu, titleVisibility: .hidden) {
            if canEdit {
                Button("Edit Goal") { showingEditGoal = true }
            }
            
            if !goal.isDraft {
                Button("Share Goal") {
                    shareGoal()
                }
            }
            
            if canEdit && currentGoalStatus != .archived {
                Button("Archive Goal", role: .destructive) {
                    Task { await archiveGoal() }
                }
            }
            
            if canEdit && currentGoalStatus == .archived {
                Button("Unarchive Goal") {
                    Task { await unarchiveGoal() }
                }
            }

            if goal.isDraft && isOwner {
                Button("Publish Draft") { Task { await publishDraft() } }
            }


        }
        .alert("Publish Error", isPresented: $showingPublishError) {
            Button("OK") { publishError = nil }
        } message: {
            Text(publishError ?? "An error occurred while publishing.")
        }
        .alert("Draft Published!", isPresented: $showingPublishSuccess) {
            Button("OK") { handlePublishSuccess() }
        } message: {
            Text("Your draft has been published and is now visible to others.")
        }
        .onChange(of: goal.id) { _, _ in
            // When goal changes, reset ownership and reload
            Task {
                // Recompute ownership immediately
                if let userId = authStore.userId {
                    await MainActor.run {
                        isOwner = goal.ownerId == userId
                    }
                }
                if !isOwner {
                    await loadOwnerProfile()
                }
                await checkPermissions()
            }
        }
        .onChange(of: items.count) { _, _ in
            Task { await checkAndUpdateGoalStatus() }
        }
        .onChange(of: completedItemsCount) { _, _ in
            Task { await checkAndUpdateGoalStatus() }
        }
    }

    // MARK: - UI Pieces

    private var topNavRow: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            // Only show menu button for owners
            if isOwner {
                Button { showingMenu = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                }
                .accessibilityIdentifier("GoalOptionsButton")
                .buttonStyle(.plain)
            }
        }
    }

    private var heroImageSection: some View {
        Group {
            if let coverImageUrl = goal.coverImageUrl, !coverImageUrl.isEmpty, let imageUrl = URL(string: coverImageUrl) {
                ZStack(alignment: .topTrailing) {
                    RemoteImage(url: imageUrl, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Status Badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(currentGoalStatus == .active ? Color.blue : Color.green)
                            .frame(width: 6, height: 6)
                        Text(currentGoalStatus == .active ? "In Progress" : "Completed")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(20)
                    .padding(12)
                }
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(goal.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .tracking(-0.6)
                .lineLimit(3)

            HStack(spacing: 12) {
                // Category/Visibility badge
                HStack(spacing: 6) {
                    Image(systemName: visibilityIcon(for: goal.visibility))
                        .font(.system(size: 12, weight: .semibold))
                    Text(visibilityTextShort(for: goal.visibility))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)

                // Date added
                Text("Added \(formatDate(goal.createdAt))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)

            // Description if exists
            if let body = goal.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .padding(.top, 8)
            }

            if !momentumCopy.isEmpty && isOwner {
                Text(momentumCopy)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ownerContextCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("GOAL OWNER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.6)
                    .padding(.leading, 4)

                HStack(spacing: 12) {
                    // Owner Avatar
                    if let profile = ownerProfile {
                        AvatarView(name: profile.fullName, size: 48)
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 48, height: 48)
                    }

                    // Owner Info
                    VStack(alignment: .leading, spacing: 4) {
                        if let profile = ownerProfile {
                            Text(profile.fullName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)

                            HStack(spacing: 4) {
                                Text("@\(profile.username)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                if ownerGoalsCount > 0 {
                                    Text("• \(ownerGoalsCount) goals completed")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text("Loading...")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // View Profile Button
                    Button {
                        showingOwnerProfile = true
                    } label: {
                        Text("View Profile")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
            }
            
        }
    }
    
    private var taggedUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                Text("Tagged Friends")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Text("(\(taggedUsers.count))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(taggedUsers) { profile in
                        VStack(spacing: 6) {
                            AvatarView(name: profile.fullName, size: 56, avatarUrl: profile.avatarUrl)
                            Text(profile.fullName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        .frame(width: 80)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                )
        )
        .shadow(color: Color.blue.opacity(0.1), radius: 10, x: 0, y: 3)
    }

    private var progressBlock: some View {
        VStack(spacing: 10) {
            ProgressBar(value: progressPercentage)
                .frame(height: 10)

            HStack {
                // Lightweight “chips” that are informational (not attention hogs)
                InfoPill(icon: visibilityIcon(for: goal.visibility), text: visibilityTextShort(for: goal.visibility))
                InfoPill(icon: currentGoalStatus == .active ? "bolt.fill" : "checkmark.seal.fill",
                         text: currentGoalStatus == .active ? "Active" : "Completed")
                Spacer()
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    private func nextUpCard(_ next: GoalItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NEXT UP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.6)
                Spacer()
            }

            Button { toggleItem(next) } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemBlue).opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(next.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)

                        Text("Tap to mark complete")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(Color(.systemGray3))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    private var emptyNextUp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEXT UP")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.6)

            Text("Add your first step below.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Text("Start tiny. Momentum compounds.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    private var itemsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Steps")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                if !items.isEmpty {
                    Text("\(incompleteItems.count) left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 0) {
                if isLoading {
                    ItemsSkeleton()
                        .padding(.vertical, 10)
                } else if items.isEmpty {
                    EmptyItemsCard(isOwnerOrCollaborator: isOwner)
                        .padding(.vertical, 10)
                } else {
                    // Incomplete
                    ForEach(incompleteItems) { item in
                        ItemRowRedesignedV2(
                            item: item,
                            style: .active,
                            onToggle: { toggleItem(item) }
                        )
                        if item.id != incompleteItems.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }

                    // Completed divider + completed items (collapsed tone)
                    if !completedItems.isEmpty {
                        Divider().padding(.leading, 16)

                        ForEach(completedItems) { item in
                            ItemRowRedesignedV2(
                                item: item,
                                style: .completed,
                                onToggle: { toggleItem(item) }
                            )
                            if item.id != completedItems.last?.id {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
        }
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Goal complete")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Nice work. Archive it or run it back next week.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            Text(goal.isDraft ? "Draft" : "Published")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 3, height: 3)

            Text(visibilityText(for: goal.visibility))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    // Bottom composer: different for owner vs viewer, and draft vs published
    private var bottomComposer: some View {
        VStack(spacing: 10) {
            Divider().opacity(0.4)

            // Draft approval/publish button (sticky at bottom)
            if goal.isDraft {
                if isOwner {
                    // Owner: Publish Draft button
                    Button {
                        Task { await publishDraft() }
                    } label: {
                        HStack {
                            if isPublishing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isPublishing ? "Publishing..." : "Publish Draft")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isPublishing ? Color.blue.opacity(0.7) : Color.blue)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPublishing)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                } else {
                    // Viewer (not owner): No actions - just empty space
                    Color.clear
                        .frame(height: 14)
                }
            } else {
                // Published goal: Normal behavior
                if isOwner {
                    // Owner/Collaborator: Add item composer
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)

                        TextField("Add a step…", text: $newItemTitle, onCommit: {
                            addNewItem()
                        })
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(isSavingItem)

                        Button {
                            addNewItem()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(canSubmitNewItem ? Color.blue : Color(.systemGray4))
                                    .frame(width: 46, height: 36)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmitNewItem || isSavingItem)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                } else {
                    // Viewer: Show like button
                    HStack(spacing: 16) {
                        LikeButton(isLiked: isLiked, likesCount: likesCount) {
                            toggleLike()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                }
            }
        }
        .background(.ultraThinMaterial)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var canSubmitNewItem: Bool {
        !newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Helpers (keep endpoints)
    private func visibilityIcon(for visibility: GoalVisibility) -> String {
        switch visibility {
        case .public: return "globe"
        case .friends: return "person.2"
        case .custom: return "person.2.badge.gearshape"
        case .private: return "lock.fill"
        }
    }

    private func visibilityText(for visibility: GoalVisibility) -> String {
        switch visibility {
        case .public: return "Public visibility"
        case .friends: return "Friends only"
        case .custom: return "Custom"
        case .private: return "Private"
        }
    }

    private func visibilityTextShort(for visibility: GoalVisibility) -> String {
        switch visibility {
        case .public: return "Public"
        case .friends: return "Friends"
        case .custom: return "Custom"
        case .private: return "Private"
        }
    }

    // MARK: - Data Loading (unchanged endpoints)
    private func loadItems() {
        // Only show loading if we don't have items yet
        let shouldShowLoading = items.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        
        Task {
            do {
                let fetchedItems: [GoalItem] = try await supabaseService.client
                    .from("goal_items")
                    .select()
                    .eq("goal_id", value: goal.id)
                    .order("created_at")
                    .execute()
                    .value

                await MainActor.run {
                    self.items = fetchedItems
                    self.isLoading = false
                }

                await checkAndUpdateGoalStatus()
            } catch {
                print("Error loading items: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func syncGoalStatusOnAppear() async {
        do {
            let goalWithItems = Goal(
                id: goal.id,
                ownerId: goal.ownerId,
                title: goal.title,
                body: goal.body,
                status: currentGoalStatus,
                visibility: goal.visibility,
                createdAt: goal.createdAt,
                updatedAt: goal.updatedAt,
                isDraft: goal.isDraft,
                items: items.isEmpty ? nil : items
            )

            let syncedGoal = try await supabaseService.syncGoalStatusIfNeeded(goal: goalWithItems)

            if syncedGoal.status != currentGoalStatus {
                await MainActor.run {
                    currentGoalStatus = syncedGoal.status
                }
            }
        } catch {
            print("Error syncing goal status on appear: \(error)")
        }
    }

    private func checkAndUpdateGoalStatus() async {
        guard !items.isEmpty else { return }

        let shouldBeCompleted = items.allSatisfy { $0.completed }

        if shouldBeCompleted && currentGoalStatus != .completed {
            await updateGoalStatus(to: .completed)
        } else if !shouldBeCompleted && currentGoalStatus == .completed {
            await updateGoalStatus(to: .active)
        }
    }

    private func updateGoalStatus(to newStatus: GoalStatus) async {
        do {
            struct GoalStatusUpdate: Encodable { let status: String }

            let _: [Goal] = try await supabaseService.client
                .from("goals")
                .update(GoalStatusUpdate(status: newStatus.rawValue))
                .eq("id", value: goal.id)
                .execute()
                .value

            await MainActor.run { currentGoalStatus = newStatus }
            print("✅ Goal status updated to: \(newStatus.rawValue)")
        } catch {
            print("❌ Error updating goal status: \(error)")
        }
    }

    private func toggleItem(_ item: GoalItem) {
        // Optimistic update - update UI immediately
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let previousCompleted = items[index].completed
            let previousStatus = currentGoalStatus
            
            // Create new item with toggled completed state
            let updatedItem = GoalItem(
                id: items[index].id,
                goalId: items[index].goalId,
                title: items[index].title,
                completed: !items[index].completed,
                createdAt: items[index].createdAt,
                updatedAt: Date()
            )
            items[index] = updatedItem
            
            // Check if goal should be completed
            let allCompleted = items.allSatisfy { $0.completed }
            if allCompleted && currentGoalStatus != .completed {
                currentGoalStatus = .completed
            } else if !allCompleted && currentGoalStatus == .completed {
                currentGoalStatus = .active
            }
            
            // Sync with server in background
            Task {
                do {
                    struct UpdatePayload: Encodable { let completed: Bool }

                    let _: [GoalItem] = try await supabaseService.client
                        .from("goal_items")
                        .update(UpdatePayload(completed: !previousCompleted))
                        .eq("id", value: item.id)
                        .execute()
                        .value

                    // Refresh items to ensure consistency
                    loadItems()
                    await checkAndUpdateGoalStatus()
                } catch {
                    print("Error toggling item: \(error)")
                    // Revert optimistic update on error
                    await MainActor.run {
                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                            let revertedItem = GoalItem(
                                id: items[index].id,
                                goalId: items[index].goalId,
                                title: items[index].title,
                                completed: previousCompleted,
                                createdAt: items[index].createdAt,
                                updatedAt: items[index].updatedAt
                            )
                            items[index] = revertedItem
                            currentGoalStatus = previousStatus
                        }
                    }
                }
            }
        }
    }

    private func addNewItem() {
        let trimmedTitle = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isSavingItem = true

        Task {
            do {
                struct GoalItemInsert: Encodable {
                    let goal_id: UUID
                    let title: String
                    let completed: Bool
                }

                let itemInsert = GoalItemInsert(goal_id: goal.id, title: trimmedTitle, completed: false)

                let _: [GoalItem] = try await supabaseService.client
                    .from("goal_items")
                    .insert(itemInsert, returning: .representation)
                    .execute()
                    .value

                await MainActor.run {
                    newItemTitle = ""
                    isSavingItem = false
                }

                loadItems()
                await checkAndUpdateGoalStatus()
            } catch {
                print("Error adding item: \(error)")
                await MainActor.run { isSavingItem = false }
            }
        }
    }

    private func checkPermissions() async {
        guard let userId = authStore.userId else {
            await MainActor.run {
                canEdit = false
                isOwner = false
            }
            return
        }
        
        let owner = goal.ownerId == userId

        await MainActor.run {
            isOwner = owner
            // Only owners can edit - tagged users cannot edit
            canEdit = owner
        }
    }

    private func publishDraft() async {
        await MainActor.run {
            isPublishing = true
            publishError = nil
            showingPublishSuccess = false
        }

        do {
                    try await supabaseService.publishDraft(goalId: goal.id)
            await MainActor.run {
                isPublishing = false
                showingPublishSuccess = true
            }
        } catch {
            let errorMessage = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
            await MainActor.run {
                isPublishing = false
                publishError = "Failed to publish draft: \(errorMessage)"
                showingPublishError = true
            }
        }
    }

    private func handlePublishSuccess() {
        NotificationCenter.default.post(name: .goalPublishedNotification, object: nil)
        dismiss()
    }

    private func loadOwnerProfile() async {
        do {
            // Load owner profile
            let profiles: [Profile] = try await supabaseService.client
                .from("profiles")
                .select("id,username,first_name,last_name,date_of_birth,created_at,updated_at")
                .eq("id", value: goal.ownerId)
                .limit(1)
                .execute()
                .value

            await MainActor.run {
                self.ownerProfile = profiles.first
            }

            // Load owner's completed goals count
            let completedGoals: [Goal] = try await supabaseService.client
                .from("goals")
                .select("id")
                .eq("owner_id", value: goal.ownerId)
                .eq("status", value: "completed")
                .eq("is_draft", value: false)
                .execute()
                .value

            await MainActor.run {
                self.ownerGoalsCount = completedGoals.count
            }
        } catch {
            print("Error loading owner profile: \(error)")
        }
    }
    
    private func loadTaggedUsers() async {
        await MainActor.run {
            isLoadingTaggedUsers = true
        }
        
        do {
            // Load users tagged in this goal
            let tags: [GoalTag] = try await supabaseService.client
                .from("goal_tags")
                .select()
                .eq("goal_id", value: goal.id)
                .execute()
                .value
            
            let taggedUserIds = tags.map { $0.userId }
            
            if !taggedUserIds.isEmpty {
                let profiles: [Profile] = try await supabaseService.client
                    .from("profiles")
                    .select("id,username,first_name,last_name,date_of_birth,created_at,updated_at")
                    .in("id", values: taggedUserIds.map { $0.uuidString })
                    .execute()
                    .value
                
                await MainActor.run {
                    self.taggedUsers = profiles
                    self.isLoadingTaggedUsers = false
                }
            } else {
                await MainActor.run {
                    self.taggedUsers = []
                    self.isLoadingTaggedUsers = false
                }
            }
        } catch {
            print("Error loading tagged users: \(error)")
            await MainActor.run {
                self.isLoadingTaggedUsers = false
            }
        }
    }
    
    private func loadLikes() async {
        do {
            let likesData = try await supabaseService.getLikesForGoals(goalIds: [goal.id])
            if let data = likesData[goal.id] {
                await MainActor.run {
                    self.isLiked = data.isLiked
                    self.likesCount = data.count
                }
            }
        } catch {
            print("Error loading likes: \(error)")
        }
    }
    
    private func toggleLike() {
        guard !isTogglingLike else { return }
        
        let previousIsLiked = isLiked
        let previousCount = likesCount
        
        // Optimistic update
        Task { @MainActor in
            isTogglingLike = true
            isLiked.toggle()
            likesCount += previousIsLiked ? -1 : 1
        }
        
        Task {
            do {
                if previousIsLiked {
                    try await supabaseService.unlikeGoal(goalId: goal.id)
                } else {
                    try await supabaseService.likeGoal(goalId: goal.id)
                }
                
                // Refresh from server to ensure accuracy
                let updatedLikes = try await supabaseService.getLikesForGoals(goalIds: [goal.id])
                await MainActor.run {
                    if let updated = updatedLikes[goal.id] {
                        isLiked = updated.isLiked
                        likesCount = updated.count
                    }
                    isTogglingLike = false
                }
            } catch {
                print("Error toggling like: \(error)")
                // Revert optimistic update
                await MainActor.run {
                    isLiked = previousIsLiked
                    likesCount = previousCount
                    isTogglingLike = false
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func shareGoal() {
        ShareHelper.shareGoal(
            goal: goal,
            ownerName: ownerProfile?.fullName ?? ownerProfile?.username,
            isOwnGoal: goal.ownerId == authStore.userId
        )
    }
    
    private func archiveGoal() async {
        do {
            try await supabaseService.archiveGoal(goalId: goal.id)
            await MainActor.run {
                currentGoalStatus = .archived
            }
            // Post notification to refresh views
            NotificationCenter.default.post(name: .goalPublishedNotification, object: nil)
        } catch {
            print("Error archiving goal: \(error)")
        }
    }
    
    private func unarchiveGoal() async {
        do {
            try await supabaseService.unarchiveGoal(goalId: goal.id)
            // Determine new status based on items
            let shouldBeCompleted = !items.isEmpty && items.allSatisfy { $0.completed }
            await MainActor.run {
                currentGoalStatus = shouldBeCompleted ? .completed : .active
            }
            // Post notification to refresh views
            NotificationCenter.default.post(name: .goalPublishedNotification, object: nil)
        } catch {
            print("Error unarchiving goal: \(error)")
        }
    }

    private var coverImageUrl: String? {
        goal.coverImageUrl
    }
}

// MARK: - Components (UI only)

private struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))

                RoundedRectangle(cornerRadius: 8)
                    .fill(fillColor(for: value))
                    .frame(width: max(10, geo.size.width * value))
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: value)
            }
        }
        .frame(height: 10)
    }

    private func fillColor(for v: Double) -> Color {
        // Always show green when progress is complete (100%)
        if v >= 1 { return .green }
        if v >= 0.7 { return .blue.opacity(0.9) }
        return .blue
    }
}

private struct InfoPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(.systemGray6))
        .cornerRadius(999)
    }
}

private struct EmptyItemsCard: View {
    let isOwnerOrCollaborator: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No steps yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            Text(isOwnerOrCollaborator 
                ? "Add one small step below. You'll build momentum fast."
                : "This goal doesn't have any steps yet.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ItemsSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3) { _ in
                HStack(spacing: 12) {
                    Circle().fill(Color(.systemGray5)).frame(width: 26, height: 26)
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)).frame(height: 16)
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
        }
        .redacted(reason: .placeholder)
    }
}

private enum ItemRowStyle {
    case active
    case completed
}

private struct ItemRowRedesignedV2: View {
    let item: GoalItem
    let style: ItemRowStyle
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(item.completed ? .green : Color(.systemGray3))

                Text(item.title)
                    .font(.system(size: 16, weight: item.completed ? .regular : .semibold))
                    .foregroundColor(item.completed ? .secondary : .primary)
                    .strikethrough(item.completed, color: .secondary)
                    .lineLimit(3)

                Spacer()

                if style == .active {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(style == .completed ? Color(.systemGray6).opacity(0.25) : Color.clear)
            .opacity(style == .completed ? 0.65 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
struct GoalDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GoalDetailView(
            goal: Goal(
                id: UUID(),
                ownerId: UUID(),
                title: "Activities for the week",
                body: nil,
                status: .active,
                visibility: .public,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
}
