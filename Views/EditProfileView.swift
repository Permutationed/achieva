//
//  EditProfileView.swift
//  Bucketlist
//
//  Edit profile view
//

import SwiftUI

struct EditProfileView: View {
    @StateObject private var authStore = AuthStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var hasDateOfBirth: Bool = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Profile Information") {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Display Name", text: $displayName)
                    
                    Toggle("Set Date of Birth", isOn: $hasDateOfBirth)
                    
                    if hasDateOfBirth {
                        DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isLoading || username.isEmpty || displayName.isEmpty)
                }
            }
            .task {
                loadCurrentProfile()
            }
        }
    }
    
    private func loadCurrentProfile() {
        if let profile = authStore.profile {
            username = profile.username
            displayName = profile.displayName
            if let dob = profile.dateOfBirth {
                dateOfBirth = dob
                hasDateOfBirth = true
            } else {
                hasDateOfBirth = false
            }
        }
    }
    
    private func saveProfile() {
        guard !username.isEmpty, !displayName.isEmpty else {
            errorMessage = "Username and display name are required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let dob = hasDateOfBirth ? dateOfBirth : nil
                try await authStore.createOrUpdateProfile(
                    username: username,
                    displayName: displayName,
                    dateOfBirth: dob
                )
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to update profile: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    EditProfileView()
}

