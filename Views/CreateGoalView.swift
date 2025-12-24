//
//  CreateGoalView.swift
//  Bucketlist
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
    @State private var selectedACLUsers: Set<UUID> = []
    @State private var userRoles: [UUID: String] = [:]
    @State private var showingUserPicker = false
    
    // Goal items (list items)
    @State private var items: [GoalItemDraft] = []
    @State private var newItemTitle = ""
    @State private var isAddingItem = false
    
    // Cover image
    @State private var selectedCoverImage: UIImage?
    @State private var showingImagePicker = false
    
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
                    
                    Text("New Bucketlist")
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
                                .onChange(of: title) { _ in
                                    // Focus border would go here
                                }
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
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isAddingItem = true
                                    }
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
                    
                    HStack(spacing: 12) {
                        Button {
                            createGoal()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Create Bucketlist")
                                    .font(.system(size: 16, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                (title.isEmpty || isCreating || (visibility == .custom && selectedACLUsers.isEmpty))
                                    ? Color.gray
                                    : Color.blue
                            )
                            .cornerRadius(28)
                            .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty || isCreating || (visibility == .custom && selectedACLUsers.isEmpty))
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
    }
    
    private func deleteItem(at index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            items.remove(at: index)
        }
    }
    
    private func addNewItem() {
        guard !newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            items.append(GoalItemDraft(title: newItemTitle))
            newItemTitle = ""
            isAddingItem = false
        }
    }
    
    private func cancelAddItem() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            newItemTitle = ""
            isAddingItem = false
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
            guard let userId = authStore.userId else {
                await MainActor.run {
                    errorMessage = "User not authenticated"
                    isCreating = false
                }
                return
            }
            
            do {
                // Validate custom visibility
                if visibility == .custom && selectedACLUsers.isEmpty {
                    await MainActor.run {
                        errorMessage = "Please select at least one user for custom visibility"
                        isCreating = false
                    }
                    return
                }
                
                // Get session and ensure it's valid
                var session = try await supabaseService.client.auth.session
                let authenticatedUserId = session.user.id
                
                // === COMPREHENSIVE SESSION DEBUGGING ===
                print("🔐 === AUTH DEBUGGING ===")
                print("   Session User ID: \(session.user.id)")
                print("   Session User Email: \(session.user.email ?? "none")")
                print("   Session Expired: \(session.isExpired)")
                print("   Session Expires At: \(session.expiresAt)")
                print("   Access Token Length: \(session.accessToken.count)")
                print("   Access Token (first 50): \(String(session.accessToken.prefix(50)))...")
                print("   Auth Store User ID: \(String(describing: authStore.userId))")
                print("   Provided userId matches: \(userId == authenticatedUserId)")
                print("   Current timestamp: \(Date())")
                
                // Ensure the userId matches the authenticated user
                guard userId == authenticatedUserId else {
                    await MainActor.run {
                        errorMessage = "User ID mismatch. Please sign in again."
                        isCreating = false
                    }
                    return
                }
                
                // Check if session is expired and refresh if needed
                if session.isExpired {
                    print("⚠️ Session expired, refreshing...")
                    session = try await supabaseService.client.auth.refreshSession()
                    print("✅ Session refreshed")
                }
                
                // === TEST AUTH.UID() RESOLUTION ===
                print("🧪 Testing auth.uid() resolution with profiles table...")
                do {
                    let testProfile: [Profile] = try await supabaseService.client
                        .from("profiles")
                        .select()
                        .eq("id", value: authenticatedUserId)
                        .execute()
                        .value
                    
                    print("✅ Auth test PASSED: Found \(testProfile.count) profile(s)")
                    print("   This means auth.uid() IS working for SELECT queries")
                } catch {
                    print("❌ Auth test FAILED: \(error)")
                    print("   This means auth.uid() is NOT being resolved properly")
                    await MainActor.run {
                        errorMessage = "Authentication error. Please sign out and sign in again."
                        isCreating = false
                    }
                    throw error
                }
                
                // Insert goal using the Supabase client directly (it handles auth automatically)
                struct GoalInsert: Encodable {
                    let owner_id: UUID
                    let title: String
                    let body: String?
                    let status: String
                    let visibility: String
                }
                
                let insertData = GoalInsert(
                    owner_id: authenticatedUserId,
                    title: title,
                    body: goalBody.isEmpty ? nil : goalBody,
                    status: GoalStatus.active.rawValue,
                    visibility: visibility.rawValue
                )
                
                print("📝 Creating goal with data: \(insertData)")
                print("   Owner ID: \(authenticatedUserId)")
                print("   Title: \(title)")
                print("   Visibility: \(visibility.rawValue)")
                print("   Using RPC function call (workaround for auth.uid() NULL issue)")
                
                // WORKAROUND: Use RPC function instead of direct INSERT
                // This bypasses the auth.uid() NULL issue with Supabase Swift SDK INSERT operations
                struct InsertGoalParams: Encodable {
                    let p_title: String
                    let p_body: String?
                    let p_status: String
                    let p_visibility: String
                    let p_owner_id: UUID
                }
                
                let params = InsertGoalParams(
                    p_title: title,
                    p_body: goalBody.isEmpty ? nil : goalBody,
                    p_status: GoalStatus.active.rawValue,
                    p_visibility: visibility.rawValue,
                    p_owner_id: authenticatedUserId
                )
                
                // Call the insert_goal function via RPC
                let newGoalId: UUID = try await supabaseService.client
                    .rpc("insert_goal", params: params)
                    .execute()
                    .value
                
                print("✅ Goal created via RPC with ID: \(newGoalId)")
                
                // Fetch the created goal to get full details
                let response: [Goal] = try await supabaseService.client
                    .from("goals")
                    .select()
                    .eq("id", value: newGoalId)
                    .execute()
                    .value
                
                print("✅ Goal created successfully: \(response.first?.id.uuidString ?? "unknown")")
                
                guard let createdGoal = response.first else {
                    throw NSError(domain: "GoalCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve created goal"])
                }
                
                // Create ACL entries if custom visibility
                if visibility == .custom {
                    print("📋 Creating ACL entries for \(selectedACLUsers.count) users...")
                    for userId in selectedACLUsers {
                        let role = userRoles[userId] ?? "viewer"
                        let acl = GoalACL(
                            goalId: createdGoal.id,
                            userId: userId,
                            role: role
                        )
                        
                        _ = try await supabaseService.client
                            .from("goal_acl")
                            .insert(acl, returning: .minimal)
                            .execute()
                    }
                    print("✅ ACL entries created")
                }
                
                // Create goal items
                if !items.isEmpty {
                    print("📋 Creating \(items.count) goal items...")
                    struct GoalItemInsert: Encodable {
                        let goal_id: UUID
                        let title: String
                        let completed: Bool
                    }
                    
                    for item in items {
                        let itemInsert = GoalItemInsert(
                            goal_id: createdGoal.id,
                            title: item.title,
                            completed: false
                        )
                        
                        _ = try await supabaseService.client
                            .from("goal_items")
                            .insert(itemInsert, returning: .minimal)
                            .execute()
                    }
                    print("✅ Goal items created")
                }
                
                // Upload cover image if one was selected
                if let selectedImage = selectedCoverImage,
                   let imageData = selectedImage.compressed(maxDimension: 1200, quality: 0.8) {
                    print("📤 Uploading cover image...")
                    do {
                        let imageUrl = try await supabaseService.uploadGoalCoverImage(
                            goalId: createdGoal.id,
                            imageData: imageData
                        )
                        
                        // Update goal with image URL
                        try await supabaseService.updateGoalCoverImageUrl(
                            goalId: createdGoal.id,
                            imageUrl: imageUrl
                        )
                        
                        print("✅ Cover image uploaded and linked to goal")
                    } catch {
                        print("⚠️ Failed to upload cover image: \(error)")
                        // Don't fail the entire goal creation if image upload fails
                    }
                }
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                print("❌ Error creating goal: \(error)")
                print("   Error type: \(type(of: error))")
                print("   Error description: \(String(describing: error))")
                
                // Check if it's an RLS error
                let errorString = String(describing: error)
                if errorString.contains("42501") || errorString.contains("row-level security") {
                    print("⚠️ RLS POLICY ERROR DETECTED")
                    print("   This means auth.uid() is not matching owner_id in the INSERT policy")
                    print("   Possible causes:")
                    print("   1. Migration 005 hasn't been run in Supabase dashboard")
                    print("   2. JWT token isn't being sent correctly")
                    print("   3. RLS policy configuration issue")
                    
                    await MainActor.run {
                        isCreating = false
                        errorMessage = "Permission denied. Please ensure:\n1. You're signed in\n2. Database migration 005 is applied\n3. Try signing out and back in"
                    }
                } else {
                    await MainActor.run {
                        isCreating = false
                        let errorDesc = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
                        errorMessage = "Failed to create goal: \(errorDesc)"
                    }
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
