//
//  UserPickerView.swift
//  Achieva
//
//  Component for selecting users for custom ACL
//

import SwiftUI

struct UserPickerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authStore = AuthStore.shared
    @ObservedObject var supabaseService = SupabaseService.shared
    
    @Binding var selectedUsers: Set<UUID>
    @Binding var userRoles: [UUID: String]
    
    @State private var allProfiles: [Profile] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var filteredProfiles: [Profile] {
        if searchText.isEmpty {
            return allProfiles
        }
        return allProfiles.filter { profile in
            profile.fullName.localizedCaseInsensitiveContains(searchText) ||
            profile.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                if isLoading {
                    Section {
                        ProgressView("Loading users...")
                    }
                } else {
                    Section {
                        Text("Select users who can view this goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(filteredProfiles) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.fullName)
                                    .font(.headline)
                                Text("@\(profile.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedUsers.contains(profile.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleUser(profile.id)
                        }
                        
                        // Role is always "viewer" - editor role not supported
                        if selectedUsers.contains(profile.id) {
                            Text("Viewer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search users")
            .navigationTitle("Select Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    private func toggleUser(_ userId: UUID) {
        if selectedUsers.contains(userId) {
            selectedUsers.remove(userId)
            userRoles.removeValue(forKey: userId)
        } else {
            selectedUsers.insert(userId)
            userRoles[userId] = "viewer" // Always viewer, editor not supported
        }
    }
    
    private func loadUsers() async {
        guard let userId = authStore.userId else {
            await MainActor.run {
                errorMessage = "User not authenticated"
                isLoading = false
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let profiles: [Profile] = try await supabaseService.client
                .from("profiles")
                .select()
                .neq("id", value: userId)
                .order("first_name", ascending: true)
                .execute()
                .value
            
            await MainActor.run {
                self.allProfiles = profiles
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.allProfiles = []
                self.errorMessage = "Failed to load users: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

#Preview {
    UserPickerView(
        selectedUsers: .constant(Set<UUID>()),
        userRoles: .constant([:])
    )
}

