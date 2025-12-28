//
//  FriendRequestsListView.swift
//  Achieva
//
//  View for displaying and managing all friend requests
//

import SwiftUI

struct FriendRequestsListView: View {
    let requests: [UserWithFriendshipStatus]
    let isLoading: Bool
    let onAccept: (UserWithFriendshipStatus) async -> Void
    let onReject: (UserWithFriendshipStatus) async -> Void
    let onRefresh: () async -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var loadingRequestIds: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading && requests.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if requests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No friend requests")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("You'll see friend requests here when people want to connect with you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(requests) { request in
                                FriendRequestRow(
                                    userWithStatus: request,
                                    isProcessing: loadingRequestIds.contains(request.friendshipId ?? UUID())
                                ) {
                                    Task {
                                        await handleAccept(request)
                                    }
                                } onDelete: {
                                    Task {
                                        await handleReject(request)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await onRefresh()
            }
        }
    }
    
    private func handleAccept(_ request: UserWithFriendshipStatus) async {
        guard let friendshipId = request.friendshipId else { return }
        
        await MainActor.run {
            loadingRequestIds.insert(friendshipId)
        }
        
        await onAccept(request)
        
        await MainActor.run {
            loadingRequestIds.remove(friendshipId)
        }
    }
    
    private func handleReject(_ request: UserWithFriendshipStatus) async {
        guard let friendshipId = request.friendshipId else { return }
        
        await MainActor.run {
            loadingRequestIds.insert(friendshipId)
        }
        
        await onReject(request)
        
        await MainActor.run {
            loadingRequestIds.remove(friendshipId)
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Friend Request Row

struct FriendRequestRow: View {
    let userWithStatus: UserWithFriendshipStatus
    let isProcessing: Bool
    let onConfirm: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                AvatarView(name: userWithStatus.profile.fullName, size: 56)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(userWithStatus.profile.fullName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("@\(userWithStatus.profile.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(timeAgoString(from: userWithStatus.profile.createdAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button {
                    onConfirm()
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Confirm")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(isProcessing ? Color.blue.opacity(0.6) : Color.blue)
                    .cornerRadius(24)
                    .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                
                Button {
                    onDelete()
                } label: {
                    Text("Delete")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color(.systemGray5))
                        .cornerRadius(24)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

