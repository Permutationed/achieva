//
//  FeedHeaderView.swift
//  Achieva
//
//  Header for the feed, inspired by the provided HTML.
//

import SwiftUI

struct FeedHeaderView: View {
    let title: String
    let currentUserDisplayName: String
    var currentUserAvatarUrl: String? = nil
    var unreadNotificationCount: Int = 0
    var onNotificationsTap: (() -> Void)?
    var onProfileTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)

                Spacer()

                Button {
                    onNotificationsTap?()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .padding(8)
                        
                        // Notification badge
                        if unreadNotificationCount > 0 {
                            Text("\(unreadNotificationCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Notifications"))
                .accessibilityIdentifier("NotificationsButton")

                Button {
                    onProfileTap?()
                } label: {
                    AvatarView(name: currentUserDisplayName, size: 36, avatarUrl: currentUserAvatarUrl)
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Profile"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.2)
        }
        .background(.ultraThinMaterial)
    }
}



