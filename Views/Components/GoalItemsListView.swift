//
//  GoalItemsListView.swift
//  Achieva
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
    @State private var newItemTitle = ""
    @State private var isAddingItem = false
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Items (\(items.count))")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !items.isEmpty {
                    let completedCount = items.filter { $0.completed }.count
                    Text("\(completedCount) of \(items.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Items list
            if items.isEmpty && !isAddingItem {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No items yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(items) { item in
                    GoalItemRow(
                        item: item,
                        onToggle: {
                            Task {
                                await toggleItem(item)
                            }
                        },
                        onEdit: {
                            editingItem = item
                            showingItemEditor = true
                        },
                        onDelete: {
                            Task {
                                await deleteItem(item)
                            }
                        }
                    )
                    
                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                // Add new item input
                if isAddingItem {
                    Divider()
                        .padding(.leading, 16)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "circle")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter item title...", text: $newItemTitle)
                            .textFieldStyle(.plain)
                            .disabled(isProcessing)
                        
                        Button {
                            Task {
                                await addNewItem()
                            }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .green)
                        }
                        .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                        
                        Button {
                            isAddingItem = false
                            newItemTitle = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                        }
                        .disabled(isProcessing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            
            // Add item button
            if !isAddingItem {
                Button {
                    editingItem = nil
                    showingItemEditor = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        Text("Add Item")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingItemEditor) {
            GoalItemEditor(
                goalId: goalId,
                existingItem: editingItem,
                onSave: { title, completed in
                    if let item = editingItem {
                        await updateItem(item, title: title, completed: completed)
                    } else {
                        await addNewItemWithTitle(title, completed: completed)
                    }
                }
            )
        }
    }
    
    private func toggleItem(_ item: GoalItem) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await onToggleItem(item)
            await onUpdate()
        } catch {
            print("Error toggling item: \(error)")
        }
    }
    
    private func addNewItem() async {
        let trimmedTitle = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await onCreateItem(trimmedTitle, false)
            await MainActor.run {
                newItemTitle = ""
                isAddingItem = false
            }
            await onUpdate()
        } catch {
            print("Error adding item: \(error)")
        }
    }
    
    private func addNewItemWithTitle(_ title: String, completed: Bool) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await onCreateItem(title, completed)
            await MainActor.run {
                showingItemEditor = false
                editingItem = nil
            }
            await onUpdate()
        } catch {
            print("Error adding item: \(error)")
        }
    }
    
    private func updateItem(_ item: GoalItem, title: String, completed: Bool) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await onUpdateItem(item, title, completed)
            await MainActor.run {
                showingItemEditor = false
                editingItem = nil
            }
            await onUpdate()
        } catch {
            print("Error updating item: \(error)")
        }
    }
    
    private func deleteItem(_ item: GoalItem) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await onDeleteItem(item)
            await onUpdate()
        } catch {
            print("Error deleting item: \(error)")
        }
    }
}

#Preview {
    GoalItemsListView(
        goalId: UUID(),
        items: .constant([
            GoalItem(id: UUID(), goalId: UUID(), title: "Item 1", completed: false, createdAt: Date(), updatedAt: Date()),
            GoalItem(id: UUID(), goalId: UUID(), title: "Item 2", completed: true, createdAt: Date(), updatedAt: Date())
        ]),
        onUpdate: {},
        onCreateItem: { _, _ in },
        onUpdateItem: { _, _, _ in },
        onDeleteItem: { _ in },
        onToggleItem: { _ in }
    )
}

