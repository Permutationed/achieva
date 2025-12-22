//
//  BucketlistApp.swift
//  Bucketlist
//
//  Main app entry point
//

import SwiftUI

@main
struct BucketlistApp: App {
    init() {
        // Initialize Supabase service
        _ = SupabaseService.shared
        // Initialize AuthStore
        _ = AuthStore.shared
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
