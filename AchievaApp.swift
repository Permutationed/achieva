//
//  AchievaApp.swift
//  Achieva
//
//  Main app entry point
//

import SwiftUI

@main
struct AchievaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize services (non-blocking)
        // These are lazy singletons, so accessing them here just ensures they exist
        // Actual initialization happens on first use
        _ = SupabaseService.shared
        _ = AuthStore.shared
        _ = NotificationService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .onOpenURL { url in
                    // Handle OAuth callback and password reset recovery
                    Task {
                        do {
                            // Check if this is a password reset recovery link
                            if url.absoluteString.contains("type=recovery") {
                                // Handle password reset recovery
                                try await SupabaseService.shared.client.auth.session(from: url)
                                // User will need to set a new password - this is handled by the session
                                await AuthStore.shared.observeAuthState()
                            } else {
                                // Regular OAuth callback
                                try await SupabaseService.shared.client.auth.session(from: url)
                                // Reload auth state after OAuth callback
                                await AuthStore.shared.observeAuthState()
                            }
                        } catch {
                            print("Error handling URL callback: \(error.localizedDescription)")
                        }
                    }
                }
        }
    }
}

// MARK: - AppDelegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Setup notification handling
        NotificationService.shared.setupNotificationHandling()
        
        // Request notification authorization after a short delay (non-blocking)
        // Only request on real devices, not simulator
        #if !targetEnvironment(simulator)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            await NotificationService.shared.requestAuthorization()
        }
        #endif
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationService.shared.setDeviceToken(deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Silently ignore on simulator - push notifications don't work there
        // This error is expected: "no valid aps-environment entitlement string found"
        #if targetEnvironment(simulator)
        // Do nothing on simulator - this is expected
        #else
        // Only log error on real device
        print("❌ Failed to register for remote notifications: \(error)")
        #endif
    }
}
