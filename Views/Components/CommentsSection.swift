//
//  CommentsSection.swift
//  Achieva
//
//  Comments section component with real-time updates
//

import SwiftUI

struct CommentsSection: View {
    let goalId: UUID
    let currentUserId: UUID?
    
    @ObservedObject var supabaseService = SupabaseService.shared
    @State private var comments: [GoalComment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var newCommentText = ""
    @State private var isPostingComment = false
    @State private var editingComment: GoalComment?
    @State private var realtimeTask: Task<Void, Never>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Comments")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Comments list
            if comments.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No comments yet")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Text("Be the first to comment!")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(comments) { comment in
                            CommentRow(
                                comment: comment,
                                currentUserId: currentUserId,
                                onEdit: { comment in
                                    editingComment = comment
                                    newCommentText = comment.content
                                },
                                onDelete: { commentId in
                                    deleteComment(commentId: commentId)
                                }
                            )
                            
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            
            Divider()
            
            // Comment input
            HStack(alignment: .bottom, spacing: 12) {
                // Text field
                TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...4)
                    .disabled(isPostingComment)
                
                // Post button
                Button(action: {
                    if editingComment != nil {
                        updateComment()
                    } else {
                        postComment()
                    }
                }) {
                    if isPostingComment {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: editingComment != nil ? "checkmark" : "arrow.up.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary.opacity(0.5) : .blue)
                    }
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPostingComment)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .task {
            await loadComments()
            await subscribeToRealtime()
        }
        .onDisappear {
            unsubscribeFromRealtime()
        }
    }
    
    private func loadComments() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedComments = try await supabaseService.getComments(goalId: goalId)
            await MainActor.run {
                self.comments = loadedComments.sorted { $0.createdAt > $1.createdAt }
                self.isLoading = false
            }
        } catch {
            print("Error loading comments: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load comments"
                self.isLoading = false
            }
        }
    }
    
    private func postComment() {
        Task {
            await performPostComment()
        }
    }
    
    private func performPostComment() async {
        let content = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        isPostingComment = true
        
        do {
            let newComment = try await supabaseService.createComment(goalId: goalId, content: content)
            await MainActor.run {
                // Add to top of list (newest first)
                comments.insert(newComment, at: 0)
                newCommentText = ""
                isPostingComment = false
            }
        } catch {
            print("Error posting comment: \(error)")
            await MainActor.run {
                errorMessage = "Failed to post comment"
                isPostingComment = false
            }
        }
    }
    
    private func updateComment() {
        Task {
            await performUpdateComment()
        }
    }
    
    private func performUpdateComment() async {
        guard let comment = editingComment else { return }
        let content = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        isPostingComment = true
        
        do {
            let updatedComment = try await supabaseService.updateComment(commentId: comment.id, content: content)
            await MainActor.run {
                if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                    comments[index] = updatedComment
                }
                newCommentText = ""
                editingComment = nil
                isPostingComment = false
            }
        } catch {
            print("Error updating comment: \(error)")
            await MainActor.run {
                errorMessage = "Failed to update comment"
                isPostingComment = false
            }
        }
    }
    
    private func deleteComment(commentId: UUID) {
        Task {
            do {
                try await supabaseService.deleteComment(commentId: commentId)
                await MainActor.run {
                    comments.removeAll { $0.id == commentId }
                }
            } catch {
                print("Error deleting comment: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to delete comment"
                }
            }
        }
    }
    
    private func subscribeToRealtime() async {
        do {
            let channel = try await supabaseService.subscribeToComments(
                goalId: goalId,
                onNewComment: { comment in
                    Task { @MainActor in
                        // Only add if not already present (avoid duplicates)
                        if !comments.contains(where: { $0.id == comment.id }) {
                            comments.insert(comment, at: 0)
                        }
                    }
                },
                onUpdatedComment: { comment in
                    Task { @MainActor in
                        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                            comments[index] = comment
                        }
                    }
                },
                onDeletedComment: { commentId in
                    Task { @MainActor in
                        comments.removeAll { $0.id == commentId }
                    }
                }
            )
            
            await MainActor.run {
                self.realtimeTask = channel
            }
        } catch {
            print("Error subscribing to real-time comments: \(error)")
        }
    }
    
    private func unsubscribeFromRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }
}

#Preview {
    CommentsSection(
        goalId: UUID(),
        currentUserId: UUID()
    )
    .frame(height: 500)
}

