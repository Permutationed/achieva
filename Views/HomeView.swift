//
//  HomeView.swift
//  Bucketlist
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

    @State private var profilesById: [UUID: Profile] = [:]
    
    var body: some View {
        NavigationView {
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

                        ForEach(goals) { goal in
                            let ownerProfile = profilesById[goal.ownerId]
                            NavigationLink(destination: GoalDetailView(goal: goal)) {
                                FeedGoalCardView(
                                    goal: goal,
                                    ownerDisplayName: ownerProfile?.displayName,
                                    ownerUsername: ownerProfile?.username
                                )
                            }
                            .buttonStyle(.plain)
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
                        title: "Bucketlist",
                        currentUserDisplayName: authStore.profile?.displayName ?? authStore.profile?.username ?? "You",
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
                .task {
                    await loadFeed()
                }
                .refreshable {
                    await loadFeed()
                }
            }
        }
    }
    
    private func loadFeed() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Feed: all goals visible to the current user via RLS.
            // Include goal_items as `items` (real data, no mock counts).
            let response: [Goal] = try await supabaseService.client
                .from("goals")
                .select("*, items:goal_items(*)")
                .order("created_at", ascending: false)
                .execute()
                .value

            let ownerIds = Array(Set(response.map(\.ownerId)))
            let ownerProfiles = try await loadProfiles(userIds: ownerIds)
            let profileMap = Dictionary(uniqueKeysWithValues: ownerProfiles.map { ($0.id, $0) })

            // Sync goal statuses based on items completion
            var syncedGoals: [Goal] = []
            for goal in response {
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
                self.profilesById = profileMap
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
            await MainActor.run {
                self.errorMessage = "Failed to load feed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func loadProfiles(userIds: [UUID]) async throws -> [Profile] {
        guard !userIds.isEmpty else { return [] }
        let values: [any PostgrestFilterValue] = userIds.map { $0.uuidString }
        let response: [Profile] = try await supabaseService.client
            .from("profiles")
            .select("id,username,display_name,date_of_birth,created_at,updated_at")
            .in("id", values: values)
            .execute()
            .value
        return response
    }
}

#Preview {
    HomeView()
}
