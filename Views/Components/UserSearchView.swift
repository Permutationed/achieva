//
//  UserSearchView.swift
//  Achieva
//
//  View for searching and discovering users
//

import SwiftUI

struct UserSearchView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var supabaseService = SupabaseService.shared
    @StateObject private var authStore = AuthStore.shared
    
    @State private var searchText = ""
    @State private var searchResults: [Profile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var friendshipStatuses: [UUID: FriendshipStatus] = [:]
    @State private var processingRequestIds: Set<UUID> = []
    
    let onFriendRequestSent: (() -> Void)?
    
    init(onFriendRequestSent: (() -> Void)? = nil) {
        self.onFriendRequestSent = onFriendRequestSent
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search by name or username", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onChange(of: searchText) { _, newValue in
                                Task {
                                    await performSearch(query: newValue)
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Results
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else if searchText.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Search for users")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Enter a name or username to find people to connect with")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if searchResults.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No users found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults) { profile in
                                    UserSearchResultRow(
                                        profile: profile,
                                        friendshipStatus: friendshipStatuses[profile.id],
                                        isProcessing: processingRequestIds.contains(profile.id),
                                        onAddFriend: {
                                            await sendFriendRequest(to: profile)
                                        },
                                        onViewProfile: {
                                            // Navigate to profile - handled by parent
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Search Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                // Load friendship statuses for current results if any
                if !searchResults.isEmpty {
                    await loadFriendshipStatuses()
                }
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                searchResults = []
                friendshipStatuses = [:]
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let results = try await supabaseService.searchUsers(query: query, limit: 50)
            
            await MainActor.run {
                searchResults = results
                isLoading = false
            }
            
            // Load friendship statuses for the results
            await loadFriendshipStatuses()
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to search users: \(error.localizedDescription)"
            }
            print("Error searching users: \(error)")
        }
    }
    
    private func loadFriendshipStatuses() async {
        guard let userId = authStore.userId, !searchResults.isEmpty else { return }
        
        do {
            // Load all friendships involving current user
            let friendships1: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("user_id_1", value: userId)
                .neq("status", value: "blocked")
                .execute()
                .value
            
            let friendships2: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("user_id_2", value: userId)
                .neq("status", value: "blocked")
                .execute()
                .value
            
            let allFriendships = friendships1 + friendships2
            
            var statusMap: [UUID: FriendshipStatus] = [:]
            for friendship in allFriendships {
                let otherUserId = friendship.userId1 == userId ? friendship.userId2 : friendship.userId1
                statusMap[otherUserId] = friendship.status
            }
            
            await MainActor.run {
                friendshipStatuses = statusMap
            }
        } catch {
            print("Error loading friendship statuses: \(error)")
        }
    }
    
    private func sendFriendRequest(to profile: Profile) async {
        guard let userId = authStore.userId else { return }
        guard !processingRequestIds.contains(profile.id) else { return }
        
        await MainActor.run {
            processingRequestIds.insert(profile.id)
        }
        
        do {
            struct FriendRequest: Encodable {
                let user_id_1: UUID
                let user_id_2: UUID
                let status: String
            }
            
            let request = FriendRequest(
                user_id_1: userId,
                user_id_2: profile.id,
                status: "pending"
            )
            
            try await supabaseService.client
                .from("friendships")
                .insert(request)
                .execute()
            
            await MainActor.run {
                processingRequestIds.remove(profile.id)
                friendshipStatuses[profile.id] = .pending
                onFriendRequestSent?()
            }
        } catch {
            await MainActor.run {
                processingRequestIds.remove(profile.id)
                errorMessage = "Failed to send request: \(error.localizedDescription)"
            }
            print("Error sending friend request: \(error)")
        }
    }
}

struct UserSearchResultRow: View {
    let profile: Profile
    let friendshipStatus: FriendshipStatus?
    let isProcessing: Bool
    let onAddFriend: () async -> Void
    let onViewProfile: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            AvatarView(name: profile.fullName, size: 48, avatarUrl: profile.avatarUrl)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.fullName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("@\(profile.username)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let status = friendshipStatus {
                if status == .pending {
                    Text("Pending")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                } else if status == .accepted {
                    Text("Friends")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            } else {
                Button {
                    Task {
                        await onAddFriend()
                    }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Add")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isProcessing ? Color.blue.opacity(0.6) : Color.blue)
                .cornerRadius(8)
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            onViewProfile()
        }
    }
}









