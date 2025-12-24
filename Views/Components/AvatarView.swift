//
//  AvatarView.swift
//  Bucketlist
//
//  Simple initials-based avatar (no mock remote images).
//

import SwiftUI

struct AvatarView: View {
    let name: String
    var size: CGFloat = 36

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
        .accessibilityLabel(Text("Avatar"))
    }
}



