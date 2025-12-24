//
//  GoalItemEditor.swift
//  Bucketlist
//
//  Component for creating/editing a goal item
//

import SwiftUI

struct GoalItemEditor: View {
    @Environment(\.dismiss) var dismiss
    
    let goalId: UUID
    let existingItem: GoalItem?
    let onSave: (String, Bool) async throws -> Void
    
    @State private var title: String
    @State private var completed: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(goalId: UUID, existingItem: GoalItem? = nil, onSave: @escaping (String, Bool) async throws -> Void) {
        self.goalId = goalId
        self.existingItem = existingItem
        self.onSave = onSave
        _title = State(initialValue: existingItem?.title ?? "")
        _completed = State(initialValue: existingItem?.completed ?? false)
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Item Details") {
                    TextField("Title", text: $title)
                    
                    Toggle("Completed", isOn: $completed)
                }
            }
            .navigationTitle(existingItem == nil ? "New Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveItem() {
        guard !title.isEmpty else {
            errorMessage = "Title is required"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                try await onSave(title, completed)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save item: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    GoalItemEditor(
        goalId: UUID(),
        existingItem: nil,
        onSave: { _, _ in }
    )
}

