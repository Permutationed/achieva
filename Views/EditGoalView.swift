//
//  EditGoalView.swift
//  Bucketlist
//
//  Edit existing goal view
//

import SwiftUI

struct EditGoalView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    
    let goal: Goal
    
    @State private var title: String
    @State private var goalBody: String
    @State private var status: GoalStatus
    @State private var visibility: GoalVisibility
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    init(goal: Goal) {
        self.goal = goal
        _title = State(initialValue: goal.title)
        _goalBody = State(initialValue: goal.body ?? "")
        _status = State(initialValue: goal.status)
        _visibility = State(initialValue: goal.visibility)
    }
    
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
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateGoal()
                    }
                    .disabled(title.isEmpty || isUpdating)
                }
            }
        }
    }
    
    private func updateGoal() {
        guard !title.isEmpty else {
            errorMessage = "Title is required"
            return
        }
        
        isUpdating = true
        errorMessage = nil
        
        Task {
            do {
                struct GoalUpdate: Encodable {
                    let title: String
                    let body: String?
                    let status: String
                    let visibility: String
                }
                
                let updateData = GoalUpdate(
                    title: title,
                    body: goalBody.isEmpty ? nil : goalBody,
                    status: status.rawValue,
                    visibility: visibility.rawValue
                )
                
                try await supabaseService.client
                    .from("goals")
                    .update(updateData)
                    .eq("id", value: goal.id)
                    .execute()
                
                await MainActor.run {
                    isUpdating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = "Failed to update goal: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    EditGoalView(goal: Goal(
        ownerId: UUID(),
        title: "Sample Goal",
        body: "Sample description",
        status: .active,
        visibility: .public
    ))
}

