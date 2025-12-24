//
//  OnboardingProfileView.swift
//  Bucketlist
//
//  Onboarding view to collect profile information (display_name, username, date_of_birth)
//  — redesigned to match CreateGoalView / EditGoalView UI
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
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Sticky Header
                HStack {
                    // No cancel during onboarding (keeps flow simple) — spacer for symmetry
                    Text(" ")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.clear)

                    Spacer()

                    Text("Complete Profile")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Right-side placeholder to keep title centered
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

                // Scrollable Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Top intro card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Let’s set up your profile")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)

                            Text("This helps friends find you and keeps your account personalized.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        // Error Message
                        if let errorMessage = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)

                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)

                                Spacer()

                                Button {
                                    self.errorMessage = nil
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

                        // Profile Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile Information")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)

                            // Username
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                TextField("e.g. joshwang", text: $username)
                                    .textContentType(.username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            }

                            // Display Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                TextField("e.g. Joshua", text: $displayName)
                                    .textContentType(.name)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled(false)
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            }

                            // DOB Toggle Row
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    hasDateOfBirth.toggle()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: hasDateOfBirth ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(hasDateOfBirth ? .blue : .secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Add Date of Birth")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text("Optional — used for birthday features.")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.top, 4)
                            }
                            .buttonStyle(.plain)

                            // DOB Picker (shown only if toggled on)
                            if hasDateOfBirth {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date of Birth")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)

                                    DatePicker(
                                        "",
                                        selection: $dateOfBirth,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .padding(.horizontal, 16)

                        // Bottom spacing (for sticky footer)
                        Spacer().frame(height: 110)
                    }
                }

                // Sticky Footer
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1)

                    HStack(spacing: 12) {
                        Button(action: saveProfile) {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isLoading ? "Saving..." : "Complete Profile")
                                    .font(.system(size: 16, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                (username.isEmpty || displayName.isEmpty || isLoading) ? Color.gray : Color.blue
                            )
                            .cornerRadius(28)
                            .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(username.isEmpty || displayName.isEmpty || isLoading)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
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
