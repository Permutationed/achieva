//
//  FeedGoalCardView.swift
//  Achieva
//
//  Goal card view inspired by the provided HTML feed cards.
//

import SwiftUI
import UIKit



struct FeedGoalCardView: View {
    let goal: Goal
    let ownerDisplayName: String?
    let ownerUsername: String?
    let ownerProfile: Profile?
    let collaboratorProfiles: [UUID: Profile]
    let taggedUserIds: Set<UUID>?
    
    // Likes state
    var isLiked: Bool = false
    var likesCount: Int = 0
    
    // Comments count
    var commentsCount: Int = 0

    var onMoreTap: (() -> Void)?
    var onShareTap: (() -> Void)?
    var onLikeTap: (() -> Void)?
    
    init(
        goal: Goal,
        ownerDisplayName: String? = nil,
        ownerUsername: String? = nil,
        ownerProfile: Profile? = nil,
        collaboratorProfiles: [UUID: Profile] = [:],
        taggedUserIds: Set<UUID>? = nil,
        isLiked: Bool = false,
        likesCount: Int = 0,
        commentsCount: Int = 0,
        onLikeTap: (() -> Void)? = nil,
        onShareTap: (() -> Void)? = nil
    ) {
        self.goal = goal
        self.ownerDisplayName = ownerDisplayName
        self.ownerUsername = ownerUsername
        self.ownerProfile = ownerProfile
        self.collaboratorProfiles = collaboratorProfiles
        self.taggedUserIds = taggedUserIds
        self.isLiked = isLiked
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.onLikeTap = onLikeTap
        self.onShareTap = onShareTap
    }

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
        ZStack(alignment: .topTrailing) {
            cardContent
            if goal.isDraft {
                draftBadge
            }
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
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with owner
            HStack(spacing: 12) {
                AvatarView(name: ownerProfile?.fullName ?? ownerDisplayName ?? "Unknown", size: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(ownerProfile?.fullName ?? ownerDisplayName ?? "Unknown")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: goal.createdAt, relativeTo: Date()))
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
                
                // Cover Image (if exists) - between title and description
                if let coverImageUrl = goal.coverImageUrl, !coverImageUrl.isEmpty {
                    if let imageUrl = URL(string: coverImageUrl) {
                        RemoteImage(url: imageUrl, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    } else {
                        // Invalid URL - log it (outside ViewBuilder)
                        let _ = print("⚠️ Invalid image URL: \(coverImageUrl)")
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

            // Footer actions
            HStack {
                HStack(spacing: 16) {
                    // Like button
                    LikeButton(isLiked: isLiked, likesCount: likesCount) {
                        onLikeTap?()
                    }
                    
                    // Comment count
                    if commentsCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.secondary)
                            Text("\(commentsCount)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: visibilityIcon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.secondary)
                        Text(goal.visibility.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(statusColor)
                        Text(goal.status.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(statusColor)
                    }
                    
                    // Tag indicator
                    if let taggedIds = taggedUserIds, !taggedIds.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.blue)
                            Text("\(taggedIds.count)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.blue)
                        }
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
    }
    
    private var draftBadge: some View {
        Text("DRAFT")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange)
            .cornerRadius(8)
            .padding(.top, 12)
            .padding(.trailing, 12)
    }

    private var visibilityIcon: String {
        switch goal.visibility {
        case .public: return "globe"
        case .friends: return "person.2.fill"
        case .custom: return "person.crop.circle.badge.checkmark"
        case .private: return "lock.fill"
        }
    }

    private var statusIcon: String {
        switch goal.status {
        case .active: return "circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    private var statusColor: Color {
        switch goal.status {
        case .active: return .blue
        case .completed: return .green
        case .archived: return .secondary
        }
    }
}



