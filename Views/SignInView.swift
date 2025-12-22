//
//  SignInView.swift
//  Bucketlist
//
//  Sign in view with email/password and OAuth options
//

import SwiftUI

struct SignInView: View {
    @StateObject private var authStore = AuthStore.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
                
                Section {
                    Button(action: handleEmailAuth) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text(isSignUp ? "Sign Up" : "Sign In")
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    
                    if isSignUp {
                        Button("Already have an account? Sign In") {
                            isSignUp = false
                        }
                    } else {
                        Button("Don't have an account? Sign Up") {
                            isSignUp = true
                        }
                    }
                }
                
                Section {
                    Button(action: handleAppleSignIn) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                        }
                    }
                    .disabled(isLoading)
                    
                    Button(action: handleGoogleSignIn) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Sign in with Google")
                        }
                    }
                    .disabled(isLoading)
                }
                
                if let errorMessage = authStore.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Bucketlist")
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
    
    private func handleGoogleSignIn() {
        Task {
            isLoading = true
            do {
                try await authStore.signInWithGoogle()
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


