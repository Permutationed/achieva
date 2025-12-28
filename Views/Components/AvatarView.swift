//
//  AvatarView.swift
//  Achieva
//
//  Simple initials-based avatar (no mock remote images).
//

import SwiftUI

struct AvatarView: View {
    let name: String
    var size: CGFloat = 36
    var avatarUrl: String? = nil

    private var initials: String {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(2)
        let chars = parts.compactMap { $0.first }
        if chars.isEmpty {
            return "?"
        }
        return String(chars).uppercased()
    }

    var body: some View {
        Group {
            if let avatarUrl = avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    fallbackAvatar
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                fallbackAvatar
            }
        }
        .accessibilityLabel(Text("Avatar"))
    }
    
    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.9),
                            Color.blue.opacity(0.55),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.system(size: max(12, size * 0.38), weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}



