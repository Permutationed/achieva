//
//  FeedGoalCardView.swift
//  Bucketlist
//
//  Goal card view inspired by the provided HTML feed cards.
//

import SwiftUI

struct FeedGoalCardView: View {
    let goal: Goal
    let ownerDisplayName: String?
    let ownerUsername: String?

    var onMoreTap: (() -> Void)?
    var onShareTap: (() -> Void)?

    private var displayNameForAvatar: String {
        ownerDisplayName ?? ownerUsername ?? "User"
    }

    private var displayNameForHeader: String {
        ownerDisplayName ?? ownerUsername ?? "Unknown"
    }

    private var timeAgoText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: goal.createdAt, relativeTo: Date())
    }

    private var completedCount: Int {
        goal.items?.filter { $0.completed }.count ?? 0
    }

    private var totalCount: Int {
        goal.items?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                AvatarView(name: displayNameForAvatar, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayNameForHeader)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    Text(timeAgoText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Content
            VStack(alignment: .leading, spacing: 10) {
                Text(goal.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                
                // Cover Image (if exists)
                if let coverImageUrl = goal.coverImageUrl, !coverImageUrl.isEmpty {
                    AsyncImage(url: URL(string: coverImageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                        case .empty:
                            // Loading - show placeholder
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(height: 180)
                                .overlay(
                                    ProgressView()
                                )
                        case .failure:
                            // Failed to load - don't show anything
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                if let body = goal.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(body)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Progress (only if we have real goal_items)
            if totalCount > 0 {
                FeedProgressBarView(completed: completedCount, total: totalCount, isCompleted: goal.status == .completed)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Footer actions (no mock counts)
            HStack {
                HStack(spacing: 18) {
                    Label {
                        Text(goal.visibility.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.secondary)
                    } icon: {
                        Image(systemName: visibilityIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }

                    Label {
                        Text(goal.status.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(goal.status == .completed ? Color.green : Color.secondary)
                    } icon: {
                        Image(systemName: statusIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(goal.status == .completed ? Color.green : Color.secondary)
                    }
                }

                Spacer()

                Button {
                    onShareTap?()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Share"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 1),
                alignment: .top
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    goal.status == .completed 
                        ? Color.green.opacity(0.3) 
                        : Color.black.opacity(0.05), 
                    lineWidth: goal.status == .completed ? 2 : 1
                )
        )
        .shadow(
            color: goal.status == .completed 
                ? Color.green.opacity(0.15) 
                : Color.black.opacity(0.06), 
            radius: 10, 
            x: 0, 
            y: 6
        )
    }

    private var visibilityIcon: String {
        switch goal.visibility {
        case .public: return "globe"
        case .friends: return "person.2.fill"
        case .custom: return "person.crop.circle.badge.checkmark"
        }
    }

    private var statusIcon: String {
        switch goal.status {
        case .active: return "circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
}



