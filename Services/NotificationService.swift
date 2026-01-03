//
//  NotificationService.swift
//  Achieva
//
//  Service for managing push notifications
//

import Foundation
import UserNotifications
import UIKit
import Supabase

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    private let supabaseService = SupabaseService.shared
    private var notificationDelegate: NotificationDelegate?
    
    private init() {
        // Check current authorization status asynchronously (non-blocking)
        Task { @MainActor in
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            await MainActor.run {
                isAuthorized = granted
            }
            
            if granted {
                await registerForPushNotifications()
            }
            
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Push Notification Registration
    
    func registerForPushNotifications() async {
        // Skip registration on simulator - push notifications don't work there
        #if targetEnvironment(simulator)
        print("⚠️ Skipping push notification registration on simulator")
        return
        #endif
        
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func setDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        
        print("📱 Device token received: \(token)")
        
        // Store token in Supabase
        Task {
            await storeDeviceToken(token)
        }
    }
    
    // MARK: - Device Token Storage
    
    private func storeDeviceToken(_ token: String) async {
        guard let userId = AuthStore.shared.userId else {
            print("⚠️ Cannot store device token: User not authenticated")
            return
        }
        
        do {
            struct DeviceTokenInsert: Encodable {
                let user_id: UUID
                let device_token: String
                let platform: String
            }
            
            let insert = DeviceTokenInsert(
                user_id: userId,
                device_token: token,
                platform: "ios"
            )
            
            // Use upsert to handle token updates
            try await supabaseService.client
                .from("user_devices")
                .upsert(insert, onConflict: "user_id,device_token")
                .execute()
            
            print("✅ Device token stored in Supabase")
        } catch {
            print("❌ Error storing device token: \(error)")
        }
    }
    
    // MARK: - Notification Handling
    
    func setupNotificationHandling() {
        let delegate = NotificationDelegate()
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }
    
    func handleNotificationReceived(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        print("📬 Notification received: \(userInfo)")
        
        // Handle different notification types
        if let type = userInfo["type"] as? String {
            switch type {
            case "friend_request":
                handleFriendRequestNotification(userInfo)
            case "collaboration_request":
                handleCollaborationRequestNotification(userInfo)
            case "comment":
                handleCommentNotification(userInfo)
            case "like":
                handleLikeNotification(userInfo)
            default:
                print("Unknown notification type: \(type)")
            }
        }
    }
    
    private func handleFriendRequestNotification(_ userInfo: [AnyHashable: Any]) {
        // Post notification to refresh friends view
        NotificationCenter.default.post(name: .friendRequestReceivedNotification, object: nil)
    }
    
    private func handleCollaborationRequestNotification(_ userInfo: [AnyHashable: Any]) {
        // Post notification to refresh collaboration requests
        NotificationCenter.default.post(name: .collaborationRequestReceivedNotification, object: nil)
    }
    
    private func handleCommentNotification(_ userInfo: [AnyHashable: Any]) {
        // Post notification to refresh comments
        if let goalIdString = userInfo["goal_id"] as? String,
           let goalId = UUID(uuidString: goalIdString) {
            NotificationCenter.default.post(
                name: .commentReceivedNotification,
                object: nil,
                userInfo: ["goalId": goalId]
            )
        }
    }
    
    private func handleLikeNotification(_ userInfo: [AnyHashable: Any]) {
        // Post notification to refresh likes
        if let goalIdString = userInfo["goal_id"] as? String,
           let goalId = UUID(uuidString: goalIdString) {
            NotificationCenter.default.post(
                name: .likeReceivedNotification,
                object: nil,
                userInfo: ["goalId": goalId]
            )
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
        
        // Handle notification on main actor
        Task { @MainActor in
            NotificationService.shared.handleNotificationReceived(notification)
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification tap
        if let type = userInfo["type"] as? String {
            switch type {
            case "friend_request":
                // Navigate to friends view
                NotificationCenter.default.post(name: .navigateToFriendsViewNotification, object: nil)
            case "collaboration_request":
                // Navigate to collaboration requests
                NotificationCenter.default.post(name: .navigateToCollaborationRequestsNotification, object: nil)
            case "comment", "like":
                // Navigate to goal detail if goal_id is provided
                if let goalIdString = userInfo["goal_id"] as? String,
                   let goalId = UUID(uuidString: goalIdString) {
                    NotificationCenter.default.post(
                        name: .navigateToGoalDetailNotification,
                        object: nil,
                        userInfo: ["goalId": goalId]
                    )
                }
            default:
                break
            }
        }
        
        completionHandler()
    }
}

