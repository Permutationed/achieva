//
//  PinnedGoalsView.swift
//  Achieva
//
//  View for displaying pinned goals in a conversation
//

import SwiftUI

struct PinnedGoalsView: View {
    let conversationId: UUID
    let conversationName: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    @State private var goals: [Goal] = []
    @State private var profilesById: [UUID: Profile] = [:]
    @State private var taggedUserIdsByGoalId: [UUID: Set<UUID>] = [:]
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Collaboration Hub Info Card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "pin.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tagged Goals")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Goals tagged in this conversation appear here. Tag friends when creating or editing goals to share them.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if goals.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "pin")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                
                                Text("No pinned goals yet")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Tag friends when creating or editing goals to share them here")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            // Goals List
                            VStack(spacing: 16) {
                                ForEach(goals) { goal in
                                    PinnedGoalCard(
                                        goal: goal,
                                        ownerProfile: profilesById[goal.ownerId],
                                        taggedUserIds: taggedUserIdsByGoalId[goal.id] ?? [],
                                        taggedProfiles: (taggedUserIdsByGoalId[goal.id] ?? []).compactMap { profilesById[$0] }
                                    )
                                }
                            }
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Pinned Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Show more options
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 40, height: 40)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Pinned Goals")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("with \(conversationName)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task {
            await loadGoals()
        }
    }
    
    private func loadGoals() async {
        isLoading = true
        
        do {
            // Get ALL goal IDs tagged in this conversation (for any user)
            let tags: [GoalTag] = try await supabaseService.client
                .from("goal_tags")
                .select()
                .eq("conversation_id", value: conversationId)
                .execute()
                .value
            
            // Get unique goal IDs (a goal can be tagged to multiple users)
            let taggedGoalIds = Set(tags.map { $0.goalId })
            
            // Fetch all tagged goals
            var fetchedGoals: [Goal] = []
            if !taggedGoalIds.isEmpty {
                let taggedGoals: [Goal] = try await supabaseService.client
                    .from("goals")
                    .select()
                    .in("id", values: Array(taggedGoalIds))
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                fetchedGoals.append(contentsOf: taggedGoals)
            }
            
            await MainActor.run {
                self.goals = fetchedGoals
                self.isLoading = false
            }
            
            // Load profiles for owners and tagged users
            var userIds = Set<UUID>()
            var taggedMap: [UUID: Set<UUID>] = [:]
            
            for goal in fetchedGoals {
                userIds.insert(goal.ownerId)
                
                // Get tagged users for this goal
                let goalTags = tags.filter { $0.goalId == goal.id }
                let taggedIds = Set(goalTags.map { $0.userId })
                taggedMap[goal.id] = taggedIds
                
                for userId in taggedIds {
                    userIds.insert(userId)
                }
            }
            
            let profiles = try await supabaseService.getProfiles(userIds: Array(userIds))
            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            
            await MainActor.run {
                self.profilesById = profileMap
                self.taggedUserIdsByGoalId = taggedMap
            }
        } catch {
            print("Error loading pinned goals: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct PinnedGoalCard: View {
    let goal: Goal
    let ownerProfile: Profile?
    let taggedUserIds: Set<UUID>
    let taggedProfiles: [Profile]
    
    private var statusBadge: (text: String, color: Color, bgColor: Color) {
        switch goal.status {
        case .active:
            return ("Active", .orange, Color.orange.opacity(0.1))
        case .completed:
            return ("Completed", .green, Color.green.opacity(0.1))
        case .archived:
            return ("Archived", .gray, Color(.systemGray6))
        }
    }
    
    private var progress: Double {
        guard let items = goal.items, !items.isEmpty else { return 0 }
        let completed = items.filter { $0.completed }.count
        return Double(completed) / Double(items.count)
    }
    
    private var iconName: String {
        // Simple icon mapping based on title keywords
        let title = goal.title.lowercased()
        if title.contains("travel") || title.contains("visit") || title.contains("trip") || title.contains("flight") {
            return "airplane"
        } else if title.contains("scuba") || title.contains("dive") || title.contains("water") {
            return "water.waves"
        } else if title.contains("run") || title.contains("marathon") || title.contains("race") {
            return "figure.run"
        } else {
            return "target"
        }
    }
    
    private var iconColor: Color {
        let title = goal.title.lowercased()
        if title.contains("travel") || title.contains("visit") || title.contains("trip") || title.contains("flight") {
            return .orange
        } else if title.contains("scuba") || title.contains("dive") || title.contains("water") {
            return .blue
        } else if title.contains("run") || title.contains("marathon") || title.contains("race") {
            return .red
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: iconName)
                            .foregroundColor(iconColor)
                            .font(.system(size: 16))
                        
                        Text(goal.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(statusBadge.text)
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusBadge.bgColor)
                        .foregroundColor(statusBadge.color)
                        .cornerRadius(8)
                }
                
                // Progress bar
                if let items = goal.items, !items.isEmpty {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 6)
                                .cornerRadius(3)
                            
                            Rectangle()
                                .fill(progress > 0.5 ? .green : .blue)
                                .frame(width: geometry.size.width * progress, height: 6)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 6)
                    .padding(.bottom, 12)
                }
                
                HStack {
                    // Tagged user avatars
                    if !taggedProfiles.isEmpty {
                        HStack(spacing: -8) {
                            ForEach(Array(taggedProfiles.prefix(3))) { profile in
                                AvatarView(name: profile.fullName, size: 24, avatarUrl: profile.avatarUrl)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(.systemBackground), lineWidth: 2)
                                    )
                            }
                            
                            if taggedProfiles.count > 3 {
                                Text("+\(taggedProfiles.count - 3)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.gray)
                                    .frame(width: 24, height: 24)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(.systemBackground), lineWidth: 2)
                                    )
                            }
                        }
                        
                        Text("Tagged by \(ownerProfile?.fullName ?? "User")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    // Pinned date
                    Text(formatPinnedDate(goal.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formatPinnedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Pinned Today"
        } else if calendar.isDateInYesterday(date) {
            return "Pinned Yesterday"
        } else {
            let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if daysAgo < 7 {
                return "Pinned \(daysAgo) days ago"
            } else if daysAgo < 30 {
                let weeksAgo = daysAgo / 7
                return "Pinned \(weeksAgo) week\(weeksAgo == 1 ? "" : "s") ago"
            } else {
                return "Pinned 1 week ago"
            }
        }
    }
}

