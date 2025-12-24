//
//  ProfileView.swift
//  Bucketlist
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
    @State private var showingSignOut = false
    @State private var goals: [Goal] = []
    @State private var friendsCount: Int = 0
    @State private var isLoading = false
    @State private var selectedCategory: String = "All Goals"
    @State private var showingCreateGoal = false
    @State private var editingGoal: Goal?
    @State private var showingDeleteConfirmation = false
    @State private var goalToDelete: Goal?
    
    var filteredGoals: [Goal] {
        switch selectedCategory {
        case "Active Goals":
            return goals.filter { $0.status == .active }
        case "Completed Goals":
            return goals.filter { $0.status == .completed }
        default: // "All Goals"
            return goals
        }
    }
    
    var goalsCount: Int {
        filteredGoals.count
    }
    
    var body: some View {
        NavigationView {
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
                                    name: authStore.profile?.displayName ?? "User",
                                    size: 96
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
                                Text(authStore.profile?.displayName ?? "User")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("@\(authStore.profile?.username ?? "username")")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                // Bio placeholder (no bio field in Profile model yet)
                                if let profile = authStore.profile {
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
                                StatCard(value: "0", label: "Likes")
                            }
                            .padding(.horizontal, 24)
                            
                            // Action Buttons
                            HStack(spacing: 12) {
                                Button {
                                    showingEditProfile = true
                                } label: {
                                    Text("Edit Profile")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(.label))
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    showingSignOut = true
                                } label: {
                                    Text("Sign Out")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(.separator), lineWidth: 1)
                                        )
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        
                        // Category Filters
                        HStack {
                            Spacer()
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
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
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
                                            FeedGoalCardView(
                                                goal: goal,
                                                ownerDisplayName: authStore.profile?.displayName,
                                                ownerUsername: authStore.profile?.username
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button {
                                                editingGoal = goal
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            
                                            Button(role: .destructive) {
                                                goalToDelete = goal
                                                showingDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
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
                            currentUserDisplayName: authStore.profile?.displayName ?? authStore.profile?.username ?? "You",
                            onNotificationsTap: {
                                showingEditProfile = true
                            },
                            onProfileTap: {
                                showingEditProfile = true
                            }
                        )
                        
                        // Back button overlay (only functional when presented as sheet)
     
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
            }
        }
        .task {
            await loadProfileData()
        }
        .refreshable {
            await loadProfileData()
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
        .alert("Sign Out", isPresented: $showingSignOut) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authStore.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func loadProfileData() async {
        guard let userId = authStore.userId else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Load user's goals with items
            let goalsResponse: [Goal] = try await supabaseService.client
                .from("goals")
                .select("*, items:goal_items(*)")
                .eq("owner_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
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
            
            // Sync goal statuses based on items completion
            var syncedGoals: [Goal] = []
            for goal in goalsResponse {
                do {
                    let syncedGoal = try await supabaseService.syncGoalStatusIfNeeded(goal: goal)
                    syncedGoals.append(syncedGoal)
                } catch {
                    // If sync fails, use original goal
                    print("Warning: Failed to sync status for goal \(goal.id): \(error)")
                    syncedGoals.append(goal)
                }
            }
            
            await MainActor.run {
                self.goals = syncedGoals
                self.friendsCount = friendsCount
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.goals = []
                self.friendsCount = 0
                self.isLoading = false
            }
            print("Error loading profile data: \(error)")
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
                
                await MainActor.run {
                    Task {
                        await loadProfileData()
                    }
                }
            } catch {
                print("Error deleting goal: \(error)")
            }
        }
    }
}

// Stat Card Component
struct StatCard: View {
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
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .blue : .secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    ProfileView()
}
