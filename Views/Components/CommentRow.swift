//
//  CommentRow.swift
//  Achieva
//
//  Individual comment row component
//

import SwiftUI

struct CommentRow: View {
    let comment: GoalComment
    let currentUserId: UUID?
    let onEdit: ((GoalComment) -> Void)?
    let onDelete: ((UUID) -> Void)?
    
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    
    private var isOwnComment: Bool {
        guard let currentUserId = currentUserId else { return false }
        return comment.userId == currentUserId
    }
    
    private var authorName: String {
        comment.authorProfile?.fullName ?? comment.authorProfile?.username ?? "Unknown"
    }
    
    private var authorAvatar: String? {
        nil // Profile doesn't have avatarUrl yet
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            if let avatarUrl = authorAvatar, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(
                            Text(String(authorName.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(authorName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    )
            }
            
            // Comment content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(authorName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(timeAgoString(from: comment.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Edit/Delete menu for own comments
                    if isOwnComment {
                        Menu {
                            if let onEdit = onEdit {
                                Button(action: {
                                    onEdit(comment)
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                            
                            Button(role: .destructive, action: {
                                showingDeleteConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(4)
                        }
                    }
                }
                
                if comment.updatedAt > comment.createdAt {
                    Text("(edited)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Text(comment.content)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .confirmationDialog("Delete Comment", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteComment()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
    }
    
    private func deleteComment() {
        guard !isDeleting else { return }
        isDeleting = true
        
        Task {
            await MainActor.run {
                onDelete?(comment.id)
                isDeleting = false
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    VStack(spacing: 0) {
        CommentRow(
            comment: GoalComment(
                id: UUID(),
                goalId: UUID(),
                userId: UUID(),
                content: "This is a great goal! Good luck!",
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-3600),
                authorProfile: Profile(
                    id: UUID(),
                    username: "johndoe",
                    firstName: "John",
                    lastName: "Doe",
                    dateOfBirth: Date(),
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ),
            currentUserId: UUID(),
            onEdit: { _ in },
            onDelete: { _ in }
        )
        
        Divider()
        
        CommentRow(
            comment: GoalComment(
                id: UUID(),
                goalId: UUID(),
                userId: UUID(),
                content: "Amazing progress! Keep it up!",
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: Date().addingTimeInterval(-7200)
            ),
            currentUserId: nil,
            onEdit: nil,
            onDelete: nil
        )
    }
    .background(Color(.systemGroupedBackground))
}

