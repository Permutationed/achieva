//
//  ShareHelper.swift
//  Achieva
//
//  Utility for sharing goals via iOS share sheet
//

import SwiftUI
import UIKit

struct ShareHelper {
    /// Shares a goal using the iOS share sheet directly
    /// - Parameters:
    ///   - goal: The goal to share
    ///   - ownerName: The name of the goal owner
    ///   - isOwnGoal: Whether this is the current user's own goal
    static func shareGoal(
        goal: Goal,
        ownerName: String?,
        isOwnGoal: Bool
    ) {
        // Generate context-aware message
        let shareText: String
        if isOwnGoal {
            shareText = "Check out my goal: \(goal.title)!"
        } else {
            let name = ownerName ?? "Someone"
            shareText = "Check out \(name)'s goal: \(goal.title)!"
        }
        
        // Create share items
        var shareItems: [Any] = [shareText]
        
        // Add goal URL
        if let url = URL(string: generateGoalURL(goalId: goal.id)) {
            shareItems.append(url)
        }
        
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Could not find root view controller for share sheet")
            return
        }
        
        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // Create and present share sheet
        let activityViewController = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        topController.present(activityViewController, animated: true)
    }
    
    /// Generates a shareable URL for a goal
    /// - Parameter goalId: The UUID of the goal
    /// - Returns: A URL string that can be shared
    static func generateGoalURL(goalId: UUID) -> String {
        // Deep link format for future implementation
        return "achieva://goal/\(goalId.uuidString)"
    }
}

