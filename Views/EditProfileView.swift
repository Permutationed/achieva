//
//  EditProfileView.swift
//  Achieva
//
//  Edit profile view — redesigned to match your newer UI (sticky header/footer, cards)
//  IMPORTANT: No new fields/components were added. Same variables + same inputs (TextFields, Toggle, DatePicker).
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @StateObject private var authStore = AuthStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSignOut = false
    
    // Profile picture
    @State private var selectedProfileImage: UIImage?
    @State private var showingImagePicker = false
    @ObservedObject var supabaseService = SupabaseService.shared

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
                                Text("First Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                TextField("First Name", text: $firstName)
                                    .textContentType(.givenName)
                                    .textInputAutocapitalization(.words)
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                TextField("Last Name", text: $lastName)
                                    .textContentType(.familyName)
                                    .textInputAutocapitalization(.words)
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            }

                            // Date of Birth (always required)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date of Birth")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)

                                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .font(.system(size: 15, weight: .semibold))
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        // Sign Out Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Account")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Button {
                                showingSignOut = true
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.red)
                                    
                                    Text("Sign Out")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(14)
                                .background(Color(.systemBackground))
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .padding(.horizontal, 16)
                        
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
                            .background((isLoading || username.isEmpty || firstName.isEmpty || lastName.isEmpty) ? Color.gray : Color.blue)
                            .cornerRadius(28)
                            .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || username.isEmpty || firstName.isEmpty || lastName.isEmpty)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .task {
            loadCurrentProfile()
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
        .sheet(isPresented: $showingImagePicker) {
            ProfileImagePickerView(selectedImage: $selectedProfileImage)
        }
    }
    
    // MARK: - Image Picker
    private struct ProfileImagePickerView: UIViewControllerRepresentable {
        @Binding var selectedImage: UIImage?
        @Environment(\.dismiss) var dismiss
        
        func makeUIViewController(context: Context) -> PHPickerViewController {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            configuration.preferredAssetRepresentationMode = .current
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            return picker
        }
        
        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let parent: ProfileImagePickerView
            
            init(_ parent: ProfileImagePickerView) {
                self.parent = parent
            }
            
            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                picker.dismiss(animated: true)
                
                guard let provider = results.first?.itemProvider,
                      provider.canLoadObject(ofClass: UIImage.self) else {
                    return
                }
                
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    DispatchQueue.main.async {
                        self?.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }

    private func loadCurrentProfile() {
        if let profile = authStore.profile {
            username = profile.username
            firstName = profile.firstName
            lastName = profile.lastName
            dateOfBirth = profile.dateOfBirth
        }
    }

    private func saveProfile() {
        guard !username.isEmpty, !firstName.isEmpty, !lastName.isEmpty else {
            errorMessage = "Username, first name, and last name are required"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                var avatarUrl: String? = authStore.profile?.avatarUrl
                
                // Upload profile picture if selected
                if let image = selectedProfileImage,
                   let imageData = image.jpegData(compressionQuality: 0.8),
                   let userId = authStore.userId {
                    avatarUrl = try await supabaseService.uploadProfileImage(userId: userId, imageData: imageData)
                }
                
                try await authStore.createOrUpdateProfile(
                    username: username,
                    firstName: firstName,
                    lastName: lastName,
                    dateOfBirth: dateOfBirth,
                    avatarUrl: avatarUrl
                )

                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch let error as AuthError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
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
