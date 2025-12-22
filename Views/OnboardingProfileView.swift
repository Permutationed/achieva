//
//  OnboardingProfileView.swift
//  Bucketlist
//
//  Onboarding view to collect profile information (display_name, username, date_of_birth)
//

import SwiftUI

struct OnboardingProfileView: View {
    @StateObject private var authStore = AuthStore.shared
    @State private var username = ""
    @State private var displayName = ""
    @State private var dateOfBirth = Date()
    @State private var hasDateOfBirth = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                    
                    Toggle("Add Date of Birth", isOn: $hasDateOfBirth)
                    
                    if hasDateOfBirth {
                        DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }
                
                Section {
                    Button(action: saveProfile) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text("Complete Profile")
                        }
                    }
                    .disabled(username.isEmpty || displayName.isEmpty || isLoading)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Complete Your Profile")
        }
    }
    
    private func saveProfile() {
        guard !username.isEmpty, !displayName.isEmpty else {
            errorMessage = "Username and display name are required"
            return
        }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let dob = hasDateOfBirth ? dateOfBirth : nil
                try await authStore.createOrUpdateProfile(
                    username: username,
                    displayName: displayName,
                    dateOfBirth: dob
                )
            } catch {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
}

#Preview {
    OnboardingProfileView()
}


