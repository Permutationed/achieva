//
//  FeedProgressBarView.swift
//  Achieva
//
//  Progress section inspired by the provided HTML.
//

import SwiftUI

struct FeedProgressBarView: View {
    let completed: Int
    let total: Int
    let isCompleted: Bool
    
    init(completed: Int, total: Int, isCompleted: Bool = false) {
        self.completed = completed
        self.total = total
        self.isCompleted = isCompleted
    }

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }
    
    private var accentColor: Color {
        isCompleted ? .green : .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text("Progress")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()

                Text("\(completed)/\(total) completed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 8)
                    Capsule()
                        .fill(accentColor)
                        .frame(width: proxy.size.width * fraction, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}



