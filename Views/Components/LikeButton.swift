//
//  LikeButton.swift
//  Achieva
//
//  Reusable like button component
//

import SwiftUI

struct LikeButton: View {
    let isLiked: Bool
    let likesCount: Int
    let onToggle: () -> Void
    
    @State private var isAnimating = false
    @State private var isLoading = false
    
    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            
            // Animate on toggle
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            
            // Reset animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
            
            onToggle()
        }) {
            HStack(spacing: 6) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isLiked ? .red : .secondary)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                
                if likesCount > 0 {
                    Text("\(likesCount)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(isLiked ? .red : .secondary)
                }
            }
            .opacity(isLoading ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
}

#Preview {
    HStack(spacing: 20) {
        LikeButton(isLiked: false, likesCount: 0) {
            print("Toggle like")
        }
        
        LikeButton(isLiked: true, likesCount: 5) {
            print("Toggle like")
        }
        
        LikeButton(isLiked: false, likesCount: 42) {
            print("Toggle like")
        }
    }
    .padding()
}

