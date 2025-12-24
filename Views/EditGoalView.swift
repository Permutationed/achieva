//
//  EditGoalView.swift
//  Bucketlist
//
//  Edit existing goal view — redesigned to match CreateGoalView UI
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - UIImage Extension
private extension UIImage {
    func compressed(maxDimension: CGFloat = 1200, quality: CGFloat = 0.8) -> Data? {
        let actualHeight = size.height
        let actualWidth = size.width
        var maxHeight: CGFloat = maxDimension
        var maxWidth: CGFloat = maxDimension
        var imgRatio: CGFloat = actualWidth / actualHeight
        let maxRatio: CGFloat = maxWidth / maxHeight
        
        if actualHeight > maxHeight || actualWidth > maxWidth {
            if imgRatio < maxRatio {
                imgRatio = maxHeight / actualHeight
                maxWidth = imgRatio * actualWidth
            } else if imgRatio > maxRatio {
                imgRatio = maxWidth / actualWidth
                maxHeight = imgRatio * actualHeight
            } else {
                maxHeight = maxDimension
                maxWidth = maxDimension
            }
        }
        
        let rect = CGRect(x: 0.0, y: 0.0, width: maxWidth, height: maxHeight)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)
        draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage?.jpegData(compressionQuality: quality)
    }
}

// MARK: - Image Picker
private struct ImagePickerView: UIViewControllerRepresentable {
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
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Error loading image: \(error)")
                            return
                        }
                        self?.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

struct EditGoalView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared

    let goal: Goal

    @State private var title: String
    @State private var goalBody: String
    @State private var status: GoalStatus
    @State private var visibility: GoalVisibility
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var selectedACLUsers: Set<UUID> = []
    @State private var userRoles: [UUID: String] = [:]
    @State private var showingUserPicker = false
    @State private var originalVisibility: GoalVisibility
    @State private var showingDeleteConfirmation = false
    
    // Cover image
    @State private var selectedCoverImage: UIImage?
    @State private var showingImagePicker = false
    @State private var existingImageUrl: String?

    init(goal: Goal) {
        self.goal = goal
        _title = State(initialValue: goal.title)
        _goalBody = State(initialValue: goal.body ?? "")
        _status = State(initialValue: goal.status)
        _visibility = State(initialValue: goal.visibility)
        _originalVisibility = State(initialValue: goal.visibility)
        _existingImageUrl = State(initialValue: goal.coverImageUrl)
    }

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

                    Text("Edit Bucketlist")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Spacer to center title
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
                    VStack(spacing: 24) {
                        // Error Message Display
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
                            .padding(.top, 8)
                        }
                        
                        // Cover Image Section
                        VStack(spacing: 0) {
                            ZStack {
                                if let selectedImage = selectedCoverImage {
                                    // Show newly selected image
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                        )
                                } else if let existingUrl = existingImageUrl, !existingUrl.isEmpty {
                                    // Show existing image from URL
                                    AsyncImage(url: URL(string: existingUrl)) { phase in
                                        switch phase {
                                        case .empty:
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(.systemGray5))
                                                .frame(height: 200)
                                                .overlay(
                                                    ProgressView()
                                                )
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 200)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                                )
                                        case .failure:
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(.systemGray5))
                                                .frame(height: 200)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    // Placeholder
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 200)
                                }
                                
                                // Button overlay
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button {
                                            showingImagePicker = true
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: (selectedCoverImage == nil && existingImageUrl == nil) ? "photo.badge.plus" : "photo")
                                                    .font(.system(size: 18))
                                                Text((selectedCoverImage == nil && existingImageUrl == nil) ? "Add Cover" : "Change Cover")
                                                    .font(.system(size: 14, weight: .bold))
                                            }
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(20)
                                        }
                                        
                                        if selectedCoverImage != nil || existingImageUrl != nil {
                                            Button {
                                                selectedCoverImage = nil
                                                existingImageUrl = nil
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.red)
                                                    .padding(8)
                                                    .background(.ultraThinMaterial)
                                                    .clipShape(Circle())
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("List Title")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)

                            TextField("e.g. Summer 2024 Adventures", text: $title)
                                .font(.system(size: 18, weight: .semibold))
                                .padding(16)
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.clear, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 16)

                        // Description Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            TextEditor(text: $goalBody)
                                .font(.system(size: 16))
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.clear, lineWidth: 1)
                                )
                                .overlay(
                                    Group {
                                        if goalBody.isEmpty {
                                            Text("What inspires this list? Add some context...")
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 20)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        .padding(.horizontal, 16)

                        // Status Section (card)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Status")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)

                            VStack(spacing: 10) {
                                statusRow(title: "Active", icon: "bolt.fill", value: .active)
                                statusRow(title: "Completed", icon: "checkmark.circle.fill", value: .completed)
                                statusRow(title: "Archived", icon: "archivebox.fill", value: .archived)
                            }
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)

                        // Privacy Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Privacy")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)

                            // Segmented Control
                            HStack(spacing: 4) {
                                Button {
                                    handleVisibilityChange(from: visibility, to: .public)
                                    visibility = .public
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "globe")
                                            .font(.system(size: 18))
                                        Text("Public")
                                            .font(.system(size: 14, weight: visibility == .public ? .bold : .medium))
                                    }
                                    .foregroundColor(visibility == .public ? .blue : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(visibility == .public ? Color(.systemBackground) : Color.clear)
                                    .cornerRadius(24)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    handleVisibilityChange(from: visibility, to: .friends)
                                    visibility = .friends
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.2")
                                            .font(.system(size: 18))
                                        Text("Friends")
                                            .font(.system(size: 14, weight: visibility == .friends ? .bold : .medium))
                                    }
                                    .foregroundColor(visibility == .friends ? .blue : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(visibility == .friends ? Color(.systemBackground) : Color.clear)
                                    .cornerRadius(24)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    handleVisibilityChange(from: visibility, to: .custom)
                                    visibility = .custom
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock")
                                            .font(.system(size: 18))
                                        Text("Private")
                                            .font(.system(size: 14, weight: visibility == .custom ? .bold : .medium))
                                    }
                                    .foregroundColor(visibility == .custom ? .blue : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(visibility == .custom ? Color(.systemBackground) : Color.clear)
                                    .cornerRadius(24)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(24)
                            .padding(.horizontal, 16)

                            if visibility == .custom {
                                Button {
                                    showingUserPicker = true
                                } label: {
                                    HStack {
                                        Text("Select Users")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if !selectedACLUsers.isEmpty {
                                            Text("\(selectedACLUsers.count) selected")
                                                .foregroundColor(.secondary)
                                        }
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding(16)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)

                                if selectedACLUsers.isEmpty {
                                    Text("Please select at least one user for custom visibility")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                }
                            }

                            Text("Public lists can be seen by anyone in the Discovery feed.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)

                        // Delete Goal Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Danger Zone")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                            
                            Button {
                                showingDeleteConfirmation = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.red)
                                    
                                    Text("Delete Goal")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)
                        
                        Spacer().frame(height: 110)
                    }
                }

                // Sticky Footer
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1)

                    HStack(spacing: 12) {
                        Button {
                            updateGoal()
                        } label: {
                            HStack(spacing: 8) {
                                Text(isUpdating ? "Saving..." : "Save Changes")
                                    .font(.system(size: 16, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                (title.isEmpty || isUpdating || (visibility == .custom && selectedACLUsers.isEmpty))
                                ? Color.gray
                                : Color.blue
                            )
                            .cornerRadius(28)
                            .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty || isUpdating || (visibility == .custom && selectedACLUsers.isEmpty))
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .sheet(isPresented: $showingUserPicker) {
            UserPickerView(
                selectedUsers: $selectedACLUsers,
                userRoles: $userRoles
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $selectedCoverImage)
        }
        .task {
            if goal.visibility == .custom {
                await loadACL()
            }
        }
        .alert("Delete Goal", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("Are you sure you want to delete this goal? This action cannot be undone.")
        }
    }

    // MARK: - UI Helpers

    private func statusRow(title: String, icon: String, value: GoalStatus) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                status = value
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(status == value ? .blue : .secondary)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                if status == value {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.10))
                        .clipShape(Circle())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Existing Logic (unchanged)

    private func handleVisibilityChange(from oldValue: GoalVisibility, to newValue: GoalVisibility) {
        if oldValue == .custom && newValue != .custom {
            selectedACLUsers.removeAll()
            userRoles.removeAll()
        } else if oldValue != .custom && newValue == .custom {
            Task { await loadACL() }
        }
    }

    private func loadACL() async {
        do {
            let aclEntries: [GoalACL] = try await supabaseService.client
                .from("goal_acl")
                .select()
                .eq("goal_id", value: goal.id)
                .execute()
                .value

            await MainActor.run {
                selectedACLUsers = Set(aclEntries.map { $0.userId })
                userRoles = Dictionary(uniqueKeysWithValues: aclEntries.map { ($0.userId, $0.role) })
            }
        } catch {
            print("Error loading ACL: \(error.localizedDescription)")
        }
    }

    private func updateGoal() {
        guard !title.isEmpty else {
            errorMessage = "Title is required"
            return
        }

        if visibility == .custom && selectedACLUsers.isEmpty {
            errorMessage = "Please select at least one user for custom visibility"
            return
        }

        isUpdating = true
        errorMessage = nil

        Task {
            do {
                struct GoalUpdate: Encodable {
                    let title: String
                    let body: String?
                    let status: String
                    let visibility: String
                }

                let updateData = GoalUpdate(
                    title: title,
                    body: goalBody.isEmpty ? nil : goalBody,
                    status: status.rawValue,
                    visibility: visibility.rawValue
                )

                try await supabaseService.client
                    .from("goals")
                    .update(updateData)
                    .eq("id", value: goal.id)
                    .execute()

                if originalVisibility == .custom && visibility != .custom {
                    try await supabaseService.client
                        .from("goal_acl")
                        .delete()
                        .eq("goal_id", value: goal.id)
                        .execute()
                } else if visibility == .custom {
                    try await syncACL()
                }
                
                // Handle cover image upload/deletion
                if let newImage = selectedCoverImage,
                   let imageData = newImage.compressed(maxDimension: 1200, quality: 0.8) {
                    // Upload new image
                    print("📤 Uploading new cover image...")
                    do {
                        // Delete old image if exists
                        if let oldUrl = existingImageUrl {
                            try? await supabaseService.deleteGoalCoverImage(imageUrl: oldUrl)
                        }
                        
                        let imageUrl = try await supabaseService.uploadGoalCoverImage(
                            goalId: goal.id,
                            imageData: imageData
                        )
                        
                        try await supabaseService.updateGoalCoverImageUrl(
                            goalId: goal.id,
                            imageUrl: imageUrl
                        )
                        
                        print("✅ Cover image uploaded and linked")
                    } catch {
                        print("⚠️ Failed to upload cover image: \(error)")
                    }
                } else if selectedCoverImage == nil && existingImageUrl == nil && goal.coverImageUrl != nil {
                    // User removed the image
                    print("🗑️ Removing cover image...")
                    do {
                        if let oldUrl = goal.coverImageUrl {
                            try? await supabaseService.deleteGoalCoverImage(imageUrl: oldUrl)
                        }
                        
                        try await supabaseService.updateGoalCoverImageUrl(
                            goalId: goal.id,
                            imageUrl: nil
                        )
                        
                        print("✅ Cover image removed")
                    } catch {
                        print("⚠️ Failed to remove cover image: \(error)")
                    }
                }

                await MainActor.run {
                    isUpdating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = "Failed to update goal: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteGoal() {
        Task {
            do {
                // Delete the goal (cascade will handle goal_items, goal_acl, etc.)
                try await supabaseService.client
                    .from("goals")
                    .delete()
                    .eq("id", value: goal.id)
                    .execute()
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete goal: \(error.localizedDescription)"
                }
            }
        }
    }

    private func syncACL() async throws {
        do {
            let currentACL: [GoalACL] = try await supabaseService.client
                .from("goal_acl")
                .select()
                .eq("goal_id", value: goal.id)
                .execute()
                .value

            let currentUserIds = Set(currentACL.map { $0.userId })

            let usersToRemove = currentUserIds.subtracting(selectedACLUsers)
            for userId in usersToRemove {
                try await supabaseService.client
                    .from("goal_acl")
                    .delete()
                    .eq("goal_id", value: goal.id)
                    .eq("user_id", value: userId)
                    .execute()
            }

            for userId in selectedACLUsers {
                let role = userRoles[userId] ?? "viewer"

                if currentUserIds.contains(userId) {
                    if let existingEntry = currentACL.first(where: { $0.userId == userId }),
                       existingEntry.role != role {
                        struct ACLUpdate: Encodable { let role: String }

                        try await supabaseService.client
                            .from("goal_acl")
                            .update(ACLUpdate(role: role))
                            .eq("goal_id", value: goal.id)
                            .eq("user_id", value: userId)
                            .execute()
                    }
                } else {
                    let acl = GoalACL(goalId: goal.id, userId: userId, role: role)
                    try await supabaseService.client
                        .from("goal_acl")
                        .insert(acl)
                        .execute()
                }
            }
        } catch {
            print("Error syncing ACL: \(error.localizedDescription)")
            throw error
        }
    }
}

#Preview {
    EditGoalView(goal: Goal(
        ownerId: UUID(),
        title: "Sample Goal",
        body: "Sample description",
        status: .active,
        visibility: .public
    ))
}
