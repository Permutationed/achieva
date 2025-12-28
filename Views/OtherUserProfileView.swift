//
//  OtherUserProfileView.swift
//  Achieva
//
//  View for displaying another user's profile
//

import SwiftUI

struct OtherUserProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var supabaseService = SupabaseService.shared
    @StateObject private var authStore = AuthStore.shared
    
    let userId: UUID
    
    @State private var profile: Profile?
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var friendsCount: Int = 0
    @State private var selectedCategory: String = "All Goals"
    @State private var taggedUsersByGoalId: [UUID: Set<UUID>] = [:]
    
    var filteredGoals: [Goal] {
        switch selectedCategory {
        case "Active Goals":
            return goals.filter { $0.status == .active && !$0.isDraft }
        case "Completed Goals":
            return goals.filter { $0.status == .completed && !$0.isDraft }
        default: // "All Goals"
            return goals.filter { !$0.isDraft }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading && profile == nil {
                    ProgressView()
                } else if let profile = profile {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile Header
                            VStack(spacing: 16) {
                                AvatarView(
                                    name: profile.fullName,
                                    size: 96
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray5), lineWidth: 2)
                                )
                                
                                VStack(spacing: 8) {
                                    Text(profile.fullName)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("@\(profile.username)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                // Stats
                                HStack(spacing: 24) {
                                    StatCard(value: "\(filteredGoals.count)", label: "Goals")
                                    StatCard(value: "\(friendsCount)", label: "Friends")
                                }
                            }
                            .padding(.top, 20)
                            
                            // Category Filter
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    CategoryChip(
                                        title: "All Goals",
                                        isSelected: selectedCategory == "All Goals"
                                    ) {
                                        selectedCategory = "All Goals"
                                    }
                                    
                                    CategoryChip(
                                        title: "Active Goals",
                                        isSelected: selectedCategory == "Active Goals"
                                    ) {
                                        selectedCategory = "Active Goals"
                                    }
                                    
                                    CategoryChip(
                                        title: "Completed Goals",
                                        isSelected: selectedCategory == "Completed Goals"
                                    ) {
                                        selectedCategory = "Completed Goals"
                                    }
                                }
                                .padding(.horizontal, 18)
                            }
                            .padding(.vertical, 8)
                            
                            // Goals List
                            if filteredGoals.isEmpty {
                                VStack(spacing: 12) {
                                    Text("No goals yet")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Text("This user hasn't created any goals yet.")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 40)
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(filteredGoals) { goal in
                                        NavigationLink(destination: GoalDetailView(goal: goal)) {
                                            FeedGoalCardView(
                                                goal: goal,
                                                ownerDisplayName: profile.fullName,
                                                ownerUsername: profile.username,
                                                ownerProfile: profile,
                                                collaboratorProfiles: [:],
                                                taggedUserIds: taggedUsersByGoalId[goal.id]
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 18)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("User not found")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadProfile()
        }
    }
    
    private func loadProfile() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Load profile
            let profiles: [Profile] = try await supabaseService.client
                .from("profiles")
                .select("id,username,first_name,last_name,date_of_birth,created_at,updated_at")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            
            guard let loadedProfile = profiles.first else {
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            // Load goals (both owned and tagged)
            let loadedGoals = try await supabaseService.fetchGoalsWithItems(filterOwnerId: userId)
            let taggedGoals = try await supabaseService.getGoalsTaggedForUser(userId: userId)
            
            // Combine and remove duplicates
            var allGoals = loadedGoals
            let loadedGoalIds = Set(loadedGoals.map { $0.id })
            for taggedGoal in taggedGoals {
                if !loadedGoalIds.contains(taggedGoal.id) {
                    allGoals.append(taggedGoal)
                }
            }
            
            // Load friends count
            let friendships1: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("user_id_1", value: userId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            let friendships2: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("user_id_2", value: userId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            let friendsCount = friendships1.count + friendships2.count
            
            // Load tagged users for goals
            let goalIds = allGoals.map { $0.id }
            let taggedUsersMap = try await supabaseService.getTaggedUsersForGoals(goalIds: goalIds)
            
            await MainActor.run {
                self.profile = loadedProfile
                self.goals = allGoals
                self.friendsCount = friendsCount
                self.taggedUsersByGoalId = taggedUsersMap
                self.isLoading = false
            }
        } catch {
            print("Error loading other user profile: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// Reuse existing components
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
    }
}

