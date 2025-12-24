//
//  GoalDetailView.swift
//  Bucketlist
//
//  Goal detail view redesigned to match HTML design
//

import SwiftUI

struct GoalDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var supabaseService = SupabaseService.shared
    @StateObject private var authStore = AuthStore.shared
    
    let goal: Goal
    @State private var items: [GoalItem] = []
    @State private var isLoading = false
    @State private var showingEditGoal = false
    @State private var showingAddPhoto = false
    @State private var newItemTitle = ""
    @State private var isAddingItem = false
    @State private var isSavingItem = false
    @State private var currentGoalStatus: GoalStatus
    
    init(goal: Goal) {
        self.goal = goal
        self._currentGoalStatus = State(initialValue: goal.status)
    }
    
    private var completedItemsCount: Int {
        items.filter { $0.completed }.count
    }
    
    private var progressPercentage: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedItemsCount) / Double(items.count)
    }
    
    private var allItemsCompleted: Bool {
        !items.isEmpty && items.allSatisfy { $0.completed }
    }
    
    private var updatedGoal: Goal {
        Goal(
            id: goal.id,
            ownerId: goal.ownerId,
            title: goal.title,
            body: goal.body,
            status: currentGoalStatus,
            visibility: goal.visibility,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt
        )
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            mainContent
        }
        .navigationBarHidden(true)
        .task {
            await loadItems()
            await syncGoalStatusOnAppear()
        }
        .sheet(isPresented: $showingEditGoal) {
            EditGoalView(goal: updatedGoal)
        }
        .onChange(of: items.count) { _ in
            Task {
                await checkAndUpdateGoalStatus()
            }
        }
        .onChange(of: completedItemsCount) { _ in
            Task {
                await checkAndUpdateGoalStatus()
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text("Goal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separator).opacity(0.5)),
                    alignment: .bottom
                )
                
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Goal Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text(goal.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                                .tracking(-0.5)
                            
                            // Cover Image (if exists)
                            if let coverImageUrl = goal.coverImageUrl, !coverImageUrl.isEmpty, let imageUrl = URL(string: coverImageUrl) {
                                AsyncImage(url: imageUrl) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                        .frame(height: 200)
                                        .overlay(ProgressView())
                                }
                            }
                            
                            if let body = goal.body, !body.isEmpty {
                                Text(body)
                                    .font(.system(size: 17))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(4)
                            }
                            
                            HStack(spacing: 8) {
                                // Status Badge
                                HStack(spacing: 4) {
                                    Image(systemName: currentGoalStatus == .active ? "bolt.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text(currentGoalStatus == .active ? "Active" : "Completed")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(currentGoalStatus == .active ? .blue : .green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(currentGoalStatus == .active ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                                .cornerRadius(20)
                                
                                // Visibility Badge
                                HStack(spacing: 4) {
                                    Image(systemName: visibilityIcon(for: goal.visibility))
                                        .font(.system(size: 12))
                                    Text(visibilityText(for: goal.visibility))
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .cornerRadius(20)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // Items Section
                        if !items.isEmpty || true {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Items (\(items.count))")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if !items.isEmpty {
                                        Text("\(completedItemsCount) of \(items.count)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                
                                VStack(spacing: 0) {
                                    // Progress Bar
                                    if !items.isEmpty {
                                        GeometryReader { geometry in
                                            ZStack(alignment: .leading) {
                                                Rectangle()
                                                    .fill(Color(.systemGray5))
                                                    .frame(height: 4)
                                                
                                                Rectangle()
                                                    .fill(currentGoalStatus == .completed ? Color.green : Color.blue)
                                                    .frame(width: geometry.size.width * progressPercentage, height: 4)
                                                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progressPercentage)
                                            }
                                        }
                                        .frame(height: 4)
                                    }
                                    
                                    // Items List
                                    VStack(spacing: 0) {
                                        ForEach(items) { item in
                                            ItemRow(item: item, onToggle: {
                                                toggleItem(item)
                                            })
                                            
                                            if item.id != items.last?.id {
                                                Divider()
                                                    .padding(.leading, 60)
                                            }
                                        }
                                        
                                        // Add New Item Input (when active)
                                        if isAddingItem {
                                            Divider()
                                                .padding(.leading, 16)
                                            
                                            HStack(spacing: 12) {
                                                Image(systemName: "circle")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(Color(.systemGray3))
                                                
                                                TextField("Enter item title...", text: $newItemTitle, onCommit: {
                                                    addNewItem()
                                                })
                                                .font(.system(size: 17, weight: .medium))
                                                .foregroundColor(.primary)
                                                .disabled(isSavingItem)
                                                
                                                // Checkmark to confirm
                                                Button {
                                                    addNewItem()
                                                } label: {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .green)
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingItem)
                                                
                                                // X to cancel
                                                Button {
                                                    cancelAddItem()
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(isSavingItem)
                                            }
                                            .padding(16)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                        
                                        // Add New Item Button
                                        if !isAddingItem {
                                            Divider()
                                                .padding(.leading, 16)
                                            
                                            Button {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    isAddingItem = true
                                                }
                                            } label: {
                                                HStack(spacing: 12) {
                                                    Image(systemName: "plus")
                                                        .font(.system(size: 20))
                                                    .foregroundColor(currentGoalStatus == .completed ? .green : .blue)
                                                
                                                Text("Add New Item")
                                                    .font(.system(size: 17, weight: .medium))
                                                    .foregroundColor(currentGoalStatus == .completed ? .green : .blue)
                                                    
                                                    Spacer()
                                                }
                                                .padding(16)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // Actions Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Actions")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 0) {
                                Button {
                                    showingEditGoal = true
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill((currentGoalStatus == .completed ? Color.green : Color.blue).opacity(0.1))
                                                .frame(width: 32, height: 32)
                                            
                                            Image(systemName: "pencil")
                                                .font(.system(size: 16))
                                                .foregroundColor(currentGoalStatus == .completed ? .green : .blue)
                                        }
                                        
                                        Text("Edit Goal")
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                            .padding(.horizontal, 16)
                        }
                        
                        
                        // Bottom spacing
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
    
    private func visibilityIcon(for visibility: GoalVisibility) -> String {
        switch visibility {
        case .public: return "globe"
        case .friends: return "person.2"
        case .custom: return "lock"
        }
    }
    
    private func visibilityText(for visibility: GoalVisibility) -> String {
        switch visibility {
        case .public: return "Public"
        case .friends: return "Friends"
        case .custom: return "Custom"
        }
    }
    
    private func loadItems() {
        isLoading = true
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
                
                // Check if goal status needs to be updated after loading items
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
        // Use the helper function to sync status based on current goal and items
        do {
            // Create a goal with current items for sync check
            let goalWithItems = Goal(
                id: goal.id,
                ownerId: goal.ownerId,
                title: goal.title,
                body: goal.body,
                status: currentGoalStatus,
                visibility: goal.visibility,
                createdAt: goal.createdAt,
                updatedAt: goal.updatedAt,
                items: items.isEmpty ? nil : items
            )
            
            let syncedGoal = try await supabaseService.syncGoalStatusIfNeeded(goal: goalWithItems)
            
            // Update local status if it changed
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
        // Only update if there are items and all are completed
        guard !items.isEmpty else { return }
        
        let shouldBeCompleted = items.allSatisfy { $0.completed }
        
        // Only update if status needs to change
        if shouldBeCompleted && currentGoalStatus != .completed {
            await updateGoalStatus(to: .completed)
        } else if !shouldBeCompleted && currentGoalStatus == .completed {
            // If items are uncompleted, change back to active
            await updateGoalStatus(to: .active)
        }
    }
    
    private func updateGoalStatus(to newStatus: GoalStatus) async {
        do {
            struct GoalStatusUpdate: Encodable {
                let status: String
            }
            
            let _: [Goal] = try await supabaseService.client
                .from("goals")
                .update(GoalStatusUpdate(status: newStatus.rawValue))
                .eq("id", value: goal.id)
                .execute()
                .value
            
            await MainActor.run {
                currentGoalStatus = newStatus
            }
            
            print("✅ Goal status updated to: \(newStatus.rawValue)")
        } catch {
            print("❌ Error updating goal status: \(error)")
        }
    }
    
    private func toggleItem(_ item: GoalItem) {
        Task {
            do {
                struct UpdatePayload: Encodable {
                    let completed: Bool
                }
                
                let _: [GoalItem] = try await supabaseService.client
                    .from("goal_items")
                    .update(UpdatePayload(completed: !item.completed))
                    .eq("id", value: item.id)
                    .execute()
                    .value
                
                // Reload items to reflect changes
                await loadItems()
                
                // Check and update goal status after toggling
                await checkAndUpdateGoalStatus()
            } catch {
                print("Error toggling item: \(error)")
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
                
                let itemInsert = GoalItemInsert(
                    goal_id: goal.id,
                    title: trimmedTitle,
                    completed: false
                )
                
                let _: [GoalItem] = try await supabaseService.client
                    .from("goal_items")
                    .insert(itemInsert, returning: .representation)
                    .execute()
                    .value
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        newItemTitle = ""
                        isAddingItem = false
                        isSavingItem = false
                    }
                }
                
                // Reload items to show the new one
                await loadItems()
                
                // Check and update goal status after adding
                await checkAndUpdateGoalStatus()
            } catch {
                print("Error adding item: \(error)")
                await MainActor.run {
                    isSavingItem = false
                }
            }
        }
    }
    
    private func cancelAddItem() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            newItemTitle = ""
            isAddingItem = false
        }
    }
}

// MARK: - Item Row Component
struct ItemRow: View {
    let item: GoalItem
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(item.completed ? .green : Color(.systemGray3))
                
                Text(item.title)
                    .font(.system(size: 17, weight: item.completed ? .regular : .medium))
                    .foregroundColor(item.completed ? .secondary : .primary)
                    .strikethrough(item.completed, color: .secondary)
                
                Spacer()
            }
            .padding(16)
            .contentShape(Rectangle())
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
                title: "Learn to Surf in Bali",
                body: "Catch the perfect wave at Canggu beach. Need to book lessons and buy a decent rash guard before the trip in August.",
                status: .active,
                visibility: .public,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
}
