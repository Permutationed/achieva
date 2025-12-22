//
//  CreateGoalView.swift
//  Bucketlist
//
//  Create new goal view
//

import SwiftUI

struct CreateGoalView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    
    @State private var title = ""
    @State private var goalBody = ""
    @State private var status: GoalStatus = .active
    @State private var visibility: GoalVisibility = .public
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Goal Details") {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $goalBody, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Active").tag(GoalStatus.active)
                        Text("Completed").tag(GoalStatus.completed)
                        Text("Archived").tag(GoalStatus.archived)
                    }
                }
                
                Section("Visibility") {
                    Picker("Visibility", selection: $visibility) {
                        Text("Public").tag(GoalVisibility.public)
                        Text("Friends Only").tag(GoalVisibility.friends)
                        Text("Custom").tag(GoalVisibility.custom)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGoal()
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createGoal() {
        guard !title.isEmpty else {
            errorMessage = "Title is required"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            guard let userId = authStore.userId else {
                await MainActor.run {
                    errorMessage = "User not authenticated"
                    isCreating = false
                }
                return
            }
            
            do {
                let goal = Goal(
                    ownerId: userId,
                    title: title,
                    body: goalBody.isEmpty ? nil : goalBody,
                    status: status,
                    visibility: visibility
                )
                
                try await supabaseService.client
                    .from("goals")
                    .insert(goal)
                    .execute()
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create goal: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    CreateGoalView()
}

