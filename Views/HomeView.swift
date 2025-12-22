//
//  HomeView.swift
//  Bucketlist
//
//  Home feed view showing goals (goals are posts)
//

import SwiftUI

struct HomeView: View {
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                ForEach(goals) { goal in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.headline)
                        if let body = goal.body, !body.isEmpty {
                            Text(body)
                                .font(.body)
                        }
                        HStack {
                            Text(goal.status.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(goal.visibility.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Home")
            .task {
                await loadGoals()
            }
            .refreshable {
                await loadGoals()
            }
        }
    }
    
    private func loadGoals() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load goals from Supabase (feed - all visible goals)
            // RLS policies will filter based on visibility and auth state
            let response: [Goal] = try await supabaseService.client
                .from("goals")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.goals = response
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.goals = []
                self.errorMessage = "Failed to load feed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

#Preview {
    HomeView()
}
