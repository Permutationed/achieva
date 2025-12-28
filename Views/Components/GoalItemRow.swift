//
//  GoalItemRow.swift
//  Achieva
//
//  Component to display a single goal item (checklist item)
//

import SwiftUI

struct GoalItemRow: View {
    let item: GoalItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.completed ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            Text(item.title)
                .strikethrough(item.completed)
                .foregroundColor(item.completed ? .secondary : .primary)
                .font(.body)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    List {
        GoalItemRow(
            item: GoalItem(goalId: UUID(), title: "Sample item", completed: false),
            onToggle: {},
            onEdit: {},
            onDelete: {}
        )
        GoalItemRow(
            item: GoalItem(goalId: UUID(), title: "Completed item", completed: true),
            onToggle: {},
            onEdit: {},
            onDelete: {}
        )
    }
}

