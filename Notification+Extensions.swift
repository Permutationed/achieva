//
//  Notification+Extensions.swift
//  Achieva
//
//  Custom notification names for cross-view communication
//

import Foundation

extension Notification.Name {
    static let goalPublishedNotification = Notification.Name("goalPublishedNotification")
    static let draftCreatedNotification = Notification.Name("draftCreatedNotification")
    static let collaborationAcceptedNotification = Notification.Name("collaborationAcceptedNotification")
    static let goalArchivedNotification = Notification.Name("goalArchivedNotification")
    static let goalUnarchivedNotification = Notification.Name("goalUnarchivedNotification")
    
    // Push notification related
    static let friendRequestReceivedNotification = Notification.Name("friendRequestReceivedNotification")
    static let collaborationRequestReceivedNotification = Notification.Name("collaborationRequestReceivedNotification")
    static let commentReceivedNotification = Notification.Name("commentReceivedNotification")
    static let likeReceivedNotification = Notification.Name("likeReceivedNotification")
    
    // Navigation notifications
    static let navigateToFriendsViewNotification = Notification.Name("navigateToFriendsViewNotification")
    static let navigateToCollaborationRequestsNotification = Notification.Name("navigateToCollaborationRequestsNotification")
    static let navigateToGoalDetailNotification = Notification.Name("navigateToGoalDetailNotification")
}

