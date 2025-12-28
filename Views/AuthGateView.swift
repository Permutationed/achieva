//
//  AuthGateView.swift
//  Achieva
//
//  Root view that shows either auth UI or main app based on authentication state
//

import SwiftUI

struct AuthGateView: View {
    @StateObject private var authStore = AuthStore.shared
    @State private var showingOnboarding = false
    
    var body: some View {
        Group {
            // Show loading indicator during initial auth check to prevent flash
            if !authStore.isInitialLoadComplete {
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.2)
                }
            } else if authStore.isAuthenticated {
                // Only show onboarding for new signups without a profile
                // Existing users signing in should go straight to app
                if authStore.profile != nil {
                    // User is authenticated and has profile - show main app
                    ContentView()
                } else if authStore.isNewSignUp {
                    // New user just signed up - show onboarding
                    OnboardingProfileView()
                } else {
                    // Existing user signed in but profile missing - show app anyway
                    // (This shouldn't normally happen, but we handle it gracefully)
                    ContentView()
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


