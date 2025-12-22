//
//  ProfileView.swift
//  Bucketlist
//
//  Simple profile view
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var authStore = AuthStore.shared
    @State private var showingEditProfile = false
    @State private var showingSignOut = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if let profile = authStore.profile {
                        Text(profile.displayName)
                            .font(.title2)
                        Text("@\(profile.username)")
                            .foregroundColor(.secondary)
                        if let dob = profile.dateOfBirth {
                            Text("Born: \(formatDate(dob))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Loading profile...")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button {
                        showingEditProfile = true
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                    }
                }
                
                Section {
                    Button(role: .destructive, action: {
                        showingSignOut = true
                    }) {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .alert("Sign Out", isPresented: $showingSignOut) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authStore.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    ProfileView()
}
