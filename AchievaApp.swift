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
        // Initialize Supabase service
        _ = SupabaseService.shared
        // Initialize AuthStore
        _ = AuthStore.shared
        // Initialize NotificationService
        _ = NotificationService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .onOpenURL { url in
                    // Handle OAuth callback
                    Task {
                        do {
                            try await SupabaseService.shared.client.auth.session(from: url)
                            // Reload auth state after OAuth callback
                            await AuthStore.shared.observeAuthState()
                        } catch {
                            print("Error handling OAuth callback: \(error.localizedDescription)")
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
        
        // Request notification authorization after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            await NotificationService.shared.requestAuthorization()
        }
        
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
        // Only log error if not on simulator (simulator always fails, which is expected)
        #if !targetEnvironment(simulator)
        print("❌ Failed to register for remote notifications: \(error)")
        #else
        // Silently ignore on simulator - push notifications don't work there
        // This error is expected: "no valid aps-environment entitlement string found"
        #endif
    }
}
