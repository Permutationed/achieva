//
//  GoalsView.swift
//  Bucketlist
//
//  Goals list view with create and delete
//

import SwiftUI

struct GoalsView: View {
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreateGoal = false
    @State private var editingGoal: Goal?
    
    var body: some View {
        NavigationView {
            List {
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                if isLoading {
                    Section {
                        ProgressView()
                    }
                } else if goals.isEmpty {
                    Section {
                        Text("No goals yet")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(goals) { goal in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.title)
                                .font(.headline)
                            if let body = goal.body, !body.isEmpty {
                                Text(body)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                editingGoal = goal
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                            
                            Button(role: .destructive) {
                                deleteGoal(goal)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateGoal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateGoal) {
                CreateGoalView()
                    .onDisappear {
                        loadGoals()
                    }
            }
            .sheet(item: $editingGoal) { goal in
                EditGoalView(goal: goal)
                    .onDisappear {
                        loadGoals()
                    }
            }
            .task {
                loadGoals()
            }
            .refreshable {
                loadGoals()
            }
        }
    }
    
    private func loadGoals() {
        guard let userId = authStore.userId else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response: [Goal] = try await supabaseService.client
                    .from("goals")
                    .select()
                    .eq("owner_id", value: userId)
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
                    self.errorMessage = "Failed to load goals: \(error.localizedDescription)"
                    self.isLoading = false
                }
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
                
                await MainActor.run {
                    loadGoals()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete goal: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    GoalsView()
}

