//
//  ChatPinnedHeader.swift
//  Achieva
//
//  Pinned goals button that navigates to PinnedGoalsView
//

import SwiftUI

struct ChatPinnedHeader: View {
    let conversationId: UUID
    let conversationName: String
    @State private var pinnedGoalsCount: Int = 0
    @State private var isLoading = true
    
    var body: some View {
        NavigationLink {
            PinnedGoalsView(conversationId: conversationId, conversationName: conversationName)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "pin.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pinned Goals")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isLoading {
                        Text("Loading...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(pinnedGoalsCount) shared goal\(pinnedGoalsCount == 1 ? "" : "s") in this chat")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.systemBackground)
                    .opacity(0.8)
            )
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator).opacity(0.5)),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            loadPinnedGoalsCount()
        }
    }
    
    private func loadPinnedGoalsCount() {
        Task {
            do {
                // Count ALL goals tagged in this conversation (for any user)
                let tags: [GoalTag] = try await SupabaseService.shared.client
                    .from("goal_tags")
                    .select("goal_id")
                    .eq("conversation_id", value: conversationId)
                    .execute()
                    .value
                
                // Get unique goal IDs (a goal can be tagged to multiple users)
                let uniqueGoalIds = Set(tags.map { $0.goalId })
                
                await MainActor.run {
                    self.pinnedGoalsCount = uniqueGoalIds.count
                    self.isLoading = false
                }
            } catch {
                print("Error loading pinned goals count: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
