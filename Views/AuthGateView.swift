//
//  AuthGateView.swift
//  Bucketlist
//
//  Root view that shows either auth UI or main app based on authentication state
//

import SwiftUI

struct AuthGateView: View {
    @StateObject private var authStore = AuthStore.shared
    @State private var showingOnboarding = false
    
    var body: some View {
        Group {
            if authStore.isAuthenticated {
                if authStore.profile != nil {
                    // User is authenticated and has profile - show main app
                    ContentView()
                } else {
                    // User is authenticated but profile incomplete - show onboarding
                    OnboardingProfileView()
                }
            } else {
                // User is not authenticated - show sign in
                SignInView()
            }
        }
        .task {
            // Ensure auth state is observed
            await authStore.observeAuthState()
        }
    }
}


