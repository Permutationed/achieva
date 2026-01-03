//
//  FriendPickerView.swift
//  Achieva
//
//  Component for selecting friends for custom ACL (only shows accepted friends)
//

import SwiftUI

struct FriendPickerView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var selectedUsers: Set<UUID>
    @Binding var userRoles: [UUID: String]
    
    let friends: [UserWithFriendshipStatus]
    let isLoading: Bool
    
    @State private var searchText = ""
    
    private var filteredFriends: [UserWithFriendshipStatus] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { user in
            user.profile.fullName.localizedCaseInsensitiveContains(searchText) ||
            user.profile.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    Section {
                        ProgressView("Loading friends...")
                    }
                } else if friends.isEmpty {
                    Section {
                        Text("You don't have any friends yet. Add friends to share goals with them.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section {
                        Text("Select friends who can view this goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(filteredFriends) { user in
                        HStack {
                            AvatarView(name: user.profile.fullName, size: 40, avatarUrl: user.profile.avatarUrl)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.profile.fullName)
                                    .font(.headline)
                                Text("@\(user.profile.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedUsers.contains(user.profile.id) {
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
                            toggleUser(user.profile.id)
                        }
                        
                        // Role is always "viewer" - editor role not supported
                        if selectedUsers.contains(user.profile.id) {
                            Text("Viewer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search friends")
            .navigationTitle("Select Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
}

#Preview {
    FriendPickerView(
        selectedUsers: .constant(Set<UUID>()),
        userRoles: .constant([:]),
        friends: [],
        isLoading: false
    )
}









