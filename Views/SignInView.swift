//
//  SignInView.swift
//  Achieva
//
//  Sign in view with email/password and OAuth options
//  — redesigned to match CreateGoalView / EditGoalView / OnboardingProfileView UI
//

import SwiftUI

struct SignInView: View {
    @StateObject private var authStore = AuthStore.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Sticky Header
                HStack {
                    // Left placeholder (keeps title centered)
                    Text(" ")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.clear)

                    Spacer()

                    Text("Achieva")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Right placeholder
                    Text(" ")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separator)),
                    alignment: .bottom
                )

                ScrollView {
                    VStack(spacing: 20) {
                        // Hero
                        VStack(alignment: .leading, spacing: 10) {
                            Text(isSignUp ? "Create your account" : "Welcome back")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)

                            Text(isSignUp ? "Sign up to start building achievas with friends." : "Sign in to keep going.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        // Error message (from AuthStore)
                        if let errorMessage = authStore.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)

                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)

                                Spacer()

                                Button {
                                    // Best-effort: clear by triggering store to nil if it’s @Published var
                                    // If your AuthStore uses a different API, remove this line.
                                    authStore.errorMessage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                }
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }

                        // Email/Password Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sign in with email")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                TextField("Enter your email", text: $email)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .keyboardType(.emailAddress)
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                SecureField(isSignUp ? "Create a password" : "Enter your password", text: $password)
                                    .textContentType(isSignUp ? .newPassword : .password)
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            }

                            Button {
                                isSignUp.toggle()
                            } label: {
                                Text(isSignUp ? "Already have an account? Sign In" : "Don’t have an account? Sign Up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .padding(.horizontal, 16)

                        // OAuth Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Or continue with")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)

                            Button(action: handleAppleSignIn) {
                                HStack(spacing: 10) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Sign in with Apple")
                                        .font(.system(size: 16, weight: .bold))
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 14)
                                .background(Color.black)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 120)
                    }
                }

                // Sticky Footer (primary action)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1)

                    HStack(spacing: 12) {
                        Button(action: handleEmailAuth) {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 16, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background((email.isEmpty || password.isEmpty || isLoading) ? Color.gray : Color.blue)
                            .cornerRadius(28)
                            .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(email.isEmpty || password.isEmpty || isLoading)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    private func handleEmailAuth() {
        Task {
            isLoading = true
            do {
                if isSignUp {
                    try await authStore.signUp(email: email, password: password)
                } else {
                    try await authStore.signIn(email: email, password: password)
                }
            } catch {
                // Error is handled by AuthStore
            }
            isLoading = false
        }
    }

    private func handleAppleSignIn() {
        Task {
            isLoading = true
            do {
                try await authStore.signInWithApple()
            } catch {
                // Error is handled by AuthStore
            }
            isLoading = false
        }
    }

}

#Preview {
    SignInView()
}
