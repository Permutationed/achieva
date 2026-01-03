//
//  CreateGoalView.swift
//  Achieva
//
//  Create new goal view - redesigned to match HTML design
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

struct CreateGoalView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    
    @State private var title = ""
    @State private var goalBody = ""
    @State private var visibility: GoalVisibility = .public
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    // Goal items (list items)
    @State private var items: [GoalItemDraft] = []
    @State private var newItemTitle = ""
    @State private var isAddingItem = false
    
    // Cover image
    @State private var selectedCoverImage: UIImage?
    @State private var showingImagePicker = false
    
    // Draft
    @State private var saveAsDraft = false
    
    // Tagging
    @State private var taggedUsers: Set<UUID> = []
    @State private var friends: [UserWithFriendshipStatus] = []
    @State private var isLoadingFriends = false
    @State private var showingFriendPicker = false
    @StateObject private var messagingService = MessagingService.shared
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Sticky Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("New Achieva")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Spacer to center title
                    Button("Cancel") {
                        dismiss()
                    }
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
                                    // Show selected image
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
                                                Image(systemName: selectedCoverImage == nil ? "photo.badge.plus" : "photo")
                                                    .font(.system(size: 18))
                                                Text(selectedCoverImage == nil ? "Add Cover" : "Change Cover")
                                                    .font(.system(size: 14, weight: .bold))
                                            }
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(20)
                                        }
                                        
                                        if selectedCoverImage != nil {
                                            Button {
                                                selectedCoverImage = nil
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
                        
                        .padding(.top, 8)
                        
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
                        
                        // List Items Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("List Items")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(items.count) items")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            
                            // Existing Items
                            VStack(spacing: 12) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    HStack(spacing: 12) {
                                        Image(systemName: "line.3.horizontal")
                                            .font(.system(size: 18))
                                            .foregroundColor(.secondary)
                                            .padding(4)
                                        
                                        Text(item.title)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button {
                                            deleteItem(at: index)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 18))
                                                .foregroundColor(.red)
                                                .padding(8)
                                                .background(Color.red.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(12)
                                    .padding(.trailing, 4)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            // Inline Add Item Input
                            if isAddingItem {
                                HStack(spacing: 12) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary)
                                        .padding(4)
                                    
                                    TextField("Enter item title...", text: $newItemTitle, onCommit: {
                                        addNewItem()
                                    })
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    
                                    // Checkmark to confirm
                                    Button {
                                        addNewItem()
                                    } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(newItemTitle.isEmpty ? .gray : .green)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(newItemTitle.isEmpty)
                                    
                                    // X to cancel
                                    Button {
                                        cancelAddItem()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .padding(.trailing, 4)
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                .padding(.horizontal, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            // Add Item Button
                            if !isAddingItem {
                                Button {
                                    isAddingItem = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18))
                                        Text("Add Item")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                            .foregroundColor(.blue.opacity(0.3))
                                    )
                                    .background(Color.blue.opacity(0.05))
                                    .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
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
                                    visibility = .private
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 18))
                                        Text("Private")
                                            .font(.system(size: 14, weight: visibility == .private ? .bold : .medium))
                                    }
                                    .foregroundColor(visibility == .private ? .blue : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(visibility == .private ? Color(.systemBackground) : Color.clear)
                                    .cornerRadius(24)
                                }
                                .buttonStyle(.plain)
                                
                            }
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(24)
                            .padding(.horizontal, 16)
                            
                            // Privacy description based on selected visibility
                            if visibility == .public {
                                Text("Public lists can be seen by anyone in the Discovery feed.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 4)
                            } else if visibility == .friends {
                                Text("Your friends can see your goal under the friends tab")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 4)
                            } else if visibility == .private {
                                Text("Only you can see this goal")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.top, 8)
                        
                        // Draft Toggle Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Toggle(isOn: $saveAsDraft) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Save as Draft")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.primary)
                                        Text("Save this list as a draft to publish later")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                            }
                            .padding(16)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            
                        }
                        .padding(.top, 8)
                        
                        // Tag Friends Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tag Friends")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                            
                            Button {
                                showingFriendPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                    
                                    if taggedUsers.isEmpty {
                                        Text("Tag friends in this goal")
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("\(taggedUsers.count) friend\(taggedUsers.count == 1 ? "" : "s") tagged")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding(16)
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            
                            if !taggedUsers.isEmpty {
                                Text("Tagged friends will see this goal in their feed and in pinned goals")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 8)
                        
                        // Bottom spacing
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                // Sticky Footer
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1)
                    
                        Button {
                            createGoal()
                        } label: {
                            HStack(spacing: 8) {
                                Text(shouldBeDraft ? "Save Draft" : "Publish")
                                    .font(.system(size: 16, weight: .bold))
                                Image(systemName: shouldBeDraft ? "square.and.arrow.down" : "arrow.right")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                (title.isEmpty || isCreating)
                                    ? Color.gray
                                    : Color.blue
                            )
                            .cornerRadius(28)
                            .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty || isCreating)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $selectedCoverImage)
            }
            .sheet(isPresented: $showingFriendPicker) {
                FriendPickerView(
                    selectedUsers: $taggedUsers,
                    userRoles: .constant([:]),
                    friends: friends,
                    isLoading: isLoadingFriends
                )
            }
            .task {
                await loadFriends()
            }
        }
    
    
    
    private func deleteItem(at index: Int) {
        items.remove(at: index)
    }
    
    private func addNewItem() {
        guard !newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        items.append(GoalItemDraft(title: newItemTitle))
        newItemTitle = ""
        isAddingItem = false
    }
    
    private func cancelAddItem() {
        newItemTitle = ""
        isAddingItem = false
    }
    
    // Computed property to determine if goal should be a draft
    private var shouldBeDraft: Bool {
        return saveAsDraft
    }
    
    private func loadFriends() async {
        guard let userId = authStore.userId else { return }
        
        await MainActor.run {
            isLoadingFriends = true
        }
        
        do {
            let allFriendships: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .or("user_id_1.eq.\(userId.uuidString),user_id_2.eq.\(userId.uuidString)")
                .eq("status", value: "accepted")
                .execute()
                .value
            
            var friendIds: Set<UUID> = []
            for friendship in allFriendships {
                if friendship.userId1 == userId {
                    friendIds.insert(friendship.userId2)
                } else {
                    friendIds.insert(friendship.userId1)
                }
            }
            
            guard !friendIds.isEmpty else {
                await MainActor.run {
                    friends = []
                    isLoadingFriends = false
                }
                return
            }
            
            let profiles = try await supabaseService.getProfiles(userIds: Array(friendIds))
            
            var friendsWithStatus: [UserWithFriendshipStatus] = []
            for profile in profiles {
                friendsWithStatus.append(UserWithFriendshipStatus(
                    profile: profile,
                    friendshipStatus: .accepted,
                    friendshipId: nil,
                    isIncomingRequest: false
                ))
            }
            
            await MainActor.run {
                friends = friendsWithStatus
                isLoadingFriends = false
            }
        } catch {
            print("Error loading friends: \(error)")
            await MainActor.run {
                isLoadingFriends = false
            }
        }
    }
    
    private func createGoal() {
        guard !title.isEmpty else {
            errorMessage = "Title is required"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            guard authStore.userId != nil else {
                await MainActor.run {
                    errorMessage = "User not authenticated"
                    isCreating = false
                }
                return
            }
            
            do {
                // Determine if this should be a draft
                let isDraft = shouldBeDraft
                
                // ACL logic removed for now to simplify
                let aclUsers: [UUID: String] = [:]
                
                let params = SupabaseService.CreateGoalParams(
                    title: title,
                    body: goalBody.isEmpty ? nil : goalBody,
                    visibility: visibility,
                    isDraft: isDraft,
                    items: items.map { $0.title },
                    acl: aclUsers,
                    coverImage: selectedCoverImage?.compressed(maxDimension: 1200, quality: 0.8)
                )
                
                let createdGoal = try await supabaseService.createGoal(params)
                
                // Tag users if any were selected
                if !taggedUsers.isEmpty {
                    try await messagingService.tagUsersInGoal(
                        goalId: createdGoal.id,
                        userIds: Array(taggedUsers)
                    )
                }
                
                // Haptic feedback for successful goal creation
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
                
                // Post notification if it's a draft or published
                await MainActor.run {
                    if createdGoal.isDraft {
                        NotificationCenter.default.post(
                            name: .draftCreatedNotification,
                            object: nil,
                            userInfo: ["goal": createdGoal]
                        )
                        print("📢 Posted draftCreatedNotification for goal \(createdGoal.id)")
                    } else {
                         NotificationCenter.default.post(
                            name: .goalPublishedNotification, // Use the notification defined in extensions
                            object: nil,
                            userInfo: ["goal": createdGoal]
                        )
                    }
                    
                    isCreating = false
                    dismiss()
                }
            } catch {
                // #region agent log
                let logPath = "/Users/joshuawang/mvp1/.cursor/debug.log"
                let logData: [String: Any] = ["function": "CreateGoalView.createGoal", "step": "error", "error": error.localizedDescription, "errorType": String(describing: type(of: error)), "errorDetails": String(describing: error), "timestamp": Date().timeIntervalSince1970]
                if let logJson = try? JSONSerialization.data(withJSONObject: logData), let logStr = String(data: logJson, encoding: .utf8) {
                    try? FileManager.default.createDirectory(atPath: "/Users/joshuawang/mvp1/.cursor", withIntermediateDirectories: true, attributes: nil)
                    if FileManager.default.fileExists(atPath: logPath), let fileHandle = FileHandle(forWritingAtPath: logPath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write((logStr + "\n").data(using: .utf8)!)
                        fileHandle.closeFile()
                    } else {
                        try? (logStr + "\n").write(toFile: logPath, atomically: false, encoding: .utf8)
                    }
                }
                // #endregion
                print("❌ Error creating goal: \(error)")
                await MainActor.run {
                    isCreating = false
                    let errorDesc = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
                    errorMessage = "Failed to create goal: \(errorDesc)"
                }
            }
        }
    }
}

// Draft model for goal items during creation
struct GoalItemDraft: Identifiable {
    let id = UUID()
    var title: String
    
    init(title: String) {
        self.title = title
    }
}

// Editor for goal item drafts
struct GoalItemDraftEditor: View {
    @Environment(\.dismiss) var dismiss
    
    let existingItem: GoalItemDraft?
    let onSave: (String) -> Void
    
    @State private var title: String
    
    init(item: GoalItemDraft?, onSave: @escaping (String) -> Void) {
        self.existingItem = item
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Title") {
                    TextField("Enter item title", text: $title)
                }
            }
            .navigationTitle(existingItem == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard !title.isEmpty else { return }
                        onSave(title)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CreateGoalView()
}
