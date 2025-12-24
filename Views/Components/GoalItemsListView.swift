//
//  GoalItemsListView.swift
//  Bucketlist
//
//  Component to display and manage goal items (checklist)
//

import SwiftUI

struct GoalItemsListView: View {
    let goalId: UUID
    @Binding var items: [GoalItem]
    let onUpdate: () -> Void
    let onCreateItem: (String, Bool) async throws -> Void
    let onUpdateItem: (GoalItem, String, Bool) async throws -> Void
    let onDeleteItem: (GoalItem) async throws -> Void
    let onToggleItem: (GoalItem) async throws -> Void
    
    @State private var showingItemEditor = false
    @State private var editingItem: GoalItem?
    
    private var completedCount: Int {
        items.filter { $0.completed }.count
    }
    
    private var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(completedCount) / Double(items.count)
    }
    
    var body: some View {
        Section {
            if items.isEmpty {
                HStack {
                    Text("No items yet")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                // Progress indicator
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(completedCount)/\(items.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: progress)
                        .tint(.blue)
                }
                .padding(.vertical, 4)
                
                // Items list
                ForEach(items) { item in
                    GoalItemRow(
                        item: item,
                        onToggle: {
                            Task {
                                try? await onToggleItem(item)
                                onUpdate()
                            }
                        },
                        onEdit: {
                            editingItem = item
                            showingItemEditor = true
                        },
                        onDelete: {
                            Task {
                                try? await onDeleteItem(item)
                                onUpdate()
                            }
                        }
                    )
                }
            }
            
            // Add item button
            Button {
                editingItem = nil
                showingItemEditor = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Item")
                }
                .foregroundColor(.blue)
            }
        } header: {
            Text("Items")
        }
        .sheet(isPresented: $showingItemEditor) {
            GoalItemEditor(
                goalId: goalId,
                existingItem: editingItem,
                onSave: { title, completed in
                    if let existing = editingItem {
                        try await onUpdateItem(existing, title, completed)
                    } else {
                        try await onCreateItem(title, completed)
                    }
                    onUpdate()
                }
            )
        }
    }
}

#Preview {
    List {
        GoalItemsListView(
            goalId: UUID(),
            items: .constant([
                GoalItem(goalId: UUID(), title: "Item 1", completed: false),
                GoalItem(goalId: UUID(), title: "Item 2", completed: true),
                GoalItem(goalId: UUID(), title: "Item 3", completed: false)
            ]),
            onUpdate: {},
            onCreateItem: { _, _ in },
            onUpdateItem: { _, _, _ in },
            onDeleteItem: { _ in },
            onToggleItem: { _ in }
        )
    }
}

