//
//  EditProfileView.swift
//  Bucketlist
//
//  Edit profile view — redesigned to match your newer UI (sticky header/footer, cards)
//  IMPORTANT: No new fields/components were added. Same variables + same inputs (TextFields, Toggle, DatePicker).
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
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Sticky Header
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Edit Profile")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Keep centered title
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.clear)
                        .disabled(true)
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

                // Scrollable Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Error message (same content, new styling)
                        if let errorMessage = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)

                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)

                                Spacer()

                                Button { self.errorMessage = nil } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                }
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        // Profile Information Card (same inputs)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile Information")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                TextField("Username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                TextField("Display Name", text: $displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            }

                            // Same Toggle component
                            Toggle("Set Date of Birth", isOn: $hasDateOfBirth)
                                .font(.system(size: 15, weight: .semibold))
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .padding(.top, 4)

                            // Same DatePicker component
                            if hasDateOfBirth {
                                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .font(.system(size: 15, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        Spacer().frame(height: 120)
                    }
                }

                // Sticky Footer (Save action)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1)

                    HStack(spacing: 12) {
                        Button {
                            saveProfile()
                        } label: {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isLoading ? "Saving..." : "Save")
                                    .font(.system(size: 16, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background((isLoading || username.isEmpty || displayName.isEmpty) ? Color.gray : Color.blue)
                            .cornerRadius(28)
                            .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || username.isEmpty || displayName.isEmpty)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .task {
            loadCurrentProfile()
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
