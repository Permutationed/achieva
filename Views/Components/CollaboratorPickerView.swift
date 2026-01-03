//
//  CollaboratorPickerView.swift
//  Achieva
//
//  View for selecting friends as collaborators
//

import SwiftUI

struct CollaboratorPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCollaborators: [UUID]
    let friends: [UserWithFriendshipStatus]
    let isLoading: Bool
    
    @State private var searchText = ""
    
    private var filteredFriends: [UserWithFriendshipStatus] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { friend in
            friend.profile.fullName.localizedCaseInsensitiveContains(searchText) ||
            friend.profile.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No friends yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Add friends to invite them as collaborators")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    VStack(spacing: 0) {
                        // Search Bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 18))
                            
                            TextField("Search friends...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        
                        // Friends List
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredFriends) { friend in
                                    CollaboratorRow(
                                        friend: friend,
                                        isSelected: selectedCollaborators.contains(friend.profile.id),
                                        onToggle: {
                                            toggleSelection(friend.profile.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func toggleSelection(_ userId: UUID) {
        if selectedCollaborators.contains(userId) {
            selectedCollaborators.removeAll { $0 == userId }
        } else {
            selectedCollaborators.append(userId)
        }
    }
}

struct CollaboratorRow: View {
    let friend: UserWithFriendshipStatus
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                AvatarView(name: friend.profile.fullName, size: 48, avatarUrl: friend.profile.avatarUrl)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.profile.fullName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("@\(friend.profile.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .accessibilityLabel(friend.profile.fullName)
            .accessibilityIdentifier("CollaboratorRow_\(friend.profile.fullName)")
        }
        .buttonStyle(.plain)
        
        Divider()
            .padding(.leading, 76)
    }
}




