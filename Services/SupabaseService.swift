//
//  SupabaseService.swift
//  Achieva
//
//  Supabase client service
//

import Foundation
import Supabase

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    private let supabaseURL: URL
    private let anonKey: String
    

    // Mock Mode Support
    private var useMocks: Bool {
        ProcessInfo.processInfo.arguments.contains("-useMockData")
    }
    
    private var cachedUserId: UUID?
    
    // In-memory mock storage
    private var mockGoals: [Goal] = []
    
    // Caching layer for performance optimization
    private let dataCache = DataCache.shared
    
    // Debug logging helper - only in debug builds
    #if DEBUG
    private func writeDebugLog(_ data: [String: Any]) {
        // Only log in debug mode, not in production
        guard let logJson = try? JSONSerialization.data(withJSONObject: data),
              let logStr = String(data: logJson, encoding: .utf8) else { return }
        print("🔍 Debug: \(logStr)")
    }
    #else
    private func writeDebugLog(_ data: [String: Any]) {
        // No-op in release builds
    }
    #endif
    
    private init() {
        // Load credentials from environment or .env file
        var url = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
        var key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        
        // If not in environment, try to read from .env file
        if url.isEmpty || key.isEmpty {
            let fileManager = FileManager.default
            
            // Try multiple possible locations for .env file
            let possiblePaths = [
                // Absolute path to project root (most reliable for Xcode)
                "/Users/joshuawang/mvp1/.env",
                // Bundle resource (if .env is added to project)
                Bundle.main.path(forResource: ".env", ofType: nil) ?? "",
                // Current working directory (may vary in Xcode)
                fileManager.currentDirectoryPath + "/.env",
                // Parent directory
                (fileManager.currentDirectoryPath as NSString).deletingLastPathComponent + "/.env"
            ]
            
            for envPath in possiblePaths {
                if !envPath.isEmpty && fileManager.fileExists(atPath: envPath) {
                    if let envContent = try? String(contentsOfFile: envPath) {
                        print("📄 Reading .env from: \(envPath)")
                        for line in envContent.components(separatedBy: "\n") {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            // Skip comments and empty lines
                            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                                continue
                            }
                            if trimmed.hasPrefix("SUPABASE_URL=") {
                                url = String(trimmed.dropFirst("SUPABASE_URL=".count))
                                    .trimmingCharacters(in: .whitespaces)
                                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                            } else if trimmed.hasPrefix("SUPABASE_ANON_KEY=") {
                                key = String(trimmed.dropFirst("SUPABASE_ANON_KEY=".count))
                                    .trimmingCharacters(in: .whitespaces)
                                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                            }
                        }
                        if !url.isEmpty && !key.isEmpty {
                            break
                        }
                    }
                }
            }
        }
        
        // If still not found, try reading from Info.plist (for production/device builds)
        if url.isEmpty || key.isEmpty {
            print("📋 Checking Info.plist for Supabase credentials...")
            if let infoPlist = Bundle.main.infoDictionary {
                if let plistUrl = infoPlist["SupabaseURL"] as? String {
                    url = plistUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("   ✅ Found SupabaseURL in Info.plist (length: \(url.count))")
                } else {
                    print("   ❌ SupabaseURL not found in Info.plist")
                }
                
                if let plistKey = infoPlist["SupabaseAnonKey"] as? String {
                    key = plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("   ✅ Found SupabaseAnonKey in Info.plist (length: \(key.count))")
                } else {
                    print("   ❌ SupabaseAnonKey not found in Info.plist")
                }
            } else {
                print("   ❌ Could not read Info.plist")
            }
        }
        
        // Final cleaning and validation
        url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Debug output
        if url.isEmpty || key.isEmpty {
            print("⚠️ Supabase credentials not found!")
            print("   Current details recorded:")
            print("   - URL length: \(url.count)")
            print("   - Key length: \(key.count)")
            print("   - Checked environment variables, .env file, and Info.plist")
            print("   - Current directory: \(FileManager.default.currentDirectoryPath)")
            print("   - Bundle path: \(Bundle.main.bundlePath)")
            fatalError("Supabase credentials not found. Please set SUPABASE_URL and SUPABASE_ANON_KEY in Info.plist, .env file, or environment variables.")
        }
        
        print("🚀 Initializing Supabase with URL: \(url)")
        
        guard let supabaseURL = URL(string: url) else {
            fatalError("Invalid Supabase URL: \(url)")
        }
        
        print("✅ Supabase client initialized with URL: \(supabaseURL.host ?? "unknown")")

        // Create Supabase client with the basic initializer.
        // Note: The SDK may log an informational message about initial session emission.
        // It does not affect app functionality and can be ignored.
        self.supabaseURL = supabaseURL
        self.anonKey = key
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    /// PostgREST client that sends an explicit Bearer access token (so `auth.uid()` is always set server-side).
    /// This is a workaround for cases where database requests end up using the anon key for Authorization.
    func postgrestAuthed(accessToken: String) -> PostgrestClient {
        PostgrestClient(
            url: supabaseURL.appendingPathComponent("/rest/v1"),
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "apikey": anonKey,
                "Content-Type": "application/json",
                "Prefer": "return=representation",
            ],
            logger: nil,
            fetch: { try await URLSession.shared.data(for: $0) }
        )
    }
    
    /// Returns an authenticated user id. This app uses anonymous auth for now so RLS policies using `auth.uid()` work.
    /// If anonymous auth is disabled in your Supabase project, this will throw.
    func currentUserId() async throws -> UUID {
        if let cachedUserId = cachedUserId {
            return cachedUserId
        }
        
        // Try to read the current session; if missing/invalid, sign in anonymously.
        do {
            // supabase-swift v2 exposes auth session via getSession()
            let session = try await client.auth.session
            let id = session.user.id
            cachedUserId = id
            return id
        } catch {
            // Fall back to anonymous sign-in
            let session = try await client.auth.signInAnonymously()
            let id = session.user.id
            cachedUserId = id
            return id
        }
    }
    
    /// Clears the cached user ID - call this when signing out or switching accounts
    func clearUserCache() {
        cachedUserId = nil
    }
    
    func isPolicyRecursionError(_ error: Error) -> Bool {
        let s = String(describing: error).lowercased()
        return s.contains("infinite recursion") && s.contains("policy") && s.contains("goals")
    }
    
    func isLikelyNetworkError(_ error: Error) -> Bool {
        if error is URLError { return true }
        let s = String(describing: error).lowercased()
        return s.contains("network") || s.contains("offline") || s.contains("timed out") || s.contains("nw_")
    }
    
    /// Syncs goal status based on items completion.
    /// If all items are completed but goal status is active, updates to completed.
    /// If not all items are completed but goal status is completed, updates to active.
    /// Returns the updated goal if status was changed, otherwise returns the original goal.
    func syncGoalStatusIfNeeded(goal: Goal) async throws -> Goal {
        // If goal has no items, return as-is
        guard let items = goal.items, !items.isEmpty else {
            return goal
        }
        
        // Check if all items are completed
        let allCompleted = items.allSatisfy { $0.completed }
        
        // Determine what the status should be
        let shouldBeCompleted = allCompleted
        let currentStatus = goal.status
        
        // If status matches expected state, no update needed
        if (shouldBeCompleted && currentStatus == .completed) || (!shouldBeCompleted && currentStatus != .completed) {
            return goal
        }
        
        // Status needs to be updated
        let newStatus: GoalStatus = shouldBeCompleted ? .completed : .active
        
        do {
            struct GoalStatusUpdate: Encodable {
                let status: String
            }
            
            let updated: [Goal] = try await client
                .from("goals")
                .update(GoalStatusUpdate(status: newStatus.rawValue))
                .eq("id", value: goal.id)
                .execute()
                .value
            
            if let updatedGoal = updated.first {
                print("✅ Goal status synced: \(goal.id) -> \(newStatus.rawValue)")
                // Return updated goal with new status but keep original items
                return Goal(
                    id: updatedGoal.id,
                    ownerId: updatedGoal.ownerId,
                    title: updatedGoal.title,
                    body: updatedGoal.body,
                    status: newStatus,
                    visibility: updatedGoal.visibility,
                    createdAt: updatedGoal.createdAt,
                    updatedAt: updatedGoal.updatedAt,
                    items: goal.items // Keep original items array
                )
            }
        } catch {
            print("❌ Error syncing goal status: \(error)")
            // Return original goal if update fails
        }
        
        return goal
    }
    
    // MARK: - Image Upload Functions
    
    /// Uploads a goal cover image to Supabase Storage
    /// - Parameters:
    ///   - goalId: The UUID of the goal
    ///   - imageData: The image data (preferably compressed)
    /// - Returns: The public URL of the uploaded image
    func uploadProfileImage(userId: UUID, imageData: Data) async throws -> String {
        let fileName = "avatar.jpg"
        // IMPORTANT: Use lowercased UUID to match PostgreSQL's auth.uid()::text format
        let filePath = "\(userId.uuidString.lowercased())/\(fileName)"
        
        print("📤 Uploading profile image to: profile-pictures/\(filePath)")
        
        do {
            // Upload to Supabase Storage
            _ = try await client.storage
                .from("profile-pictures")
                .upload(
                    filePath,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true // Allow replacing existing image
                    )
                )
            
            // Always use public URL (bucket should be public)
            let publicUrl = try client.storage
                .from("profile-pictures")
                .getPublicURL(path: filePath)
            
            return publicUrl.absoluteString
        } catch {
            print("❌ Error uploading profile image: \(error)")
            throw error
        }
    }
    
    func uploadGoalCoverImage(goalId: UUID, imageData: Data) async throws -> String {
        let fileName = "cover.jpg"
        let filePath = "\(goalId.uuidString)/\(fileName)"
        
        print("📤 Uploading image to: goal-covers/\(filePath)")
        
        do {
            // Upload to Supabase Storage
            _ = try await client.storage
                .from("goal-covers")
                .upload(
                    filePath,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true // Allow replacing existing image
                    )
                )
            
            // Always use public URL (bucket should be public)
            // Format: https://{project}.supabase.co/storage/v1/object/public/goal-covers/{path}
            let publicURL = try client.storage
                .from("goal-covers")
                .getPublicURL(path: filePath)
            
            print("✅ Image uploaded successfully")
            print("   File path: goal-covers/\(filePath)")
            print("   Public URL: \(publicURL.absoluteString)")
            print("   URL accessible: \(publicURL.absoluteString)")
            
            // Verify URL is valid
            guard publicURL.scheme == "https" else {
                throw NSError(domain: "ImageUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL scheme"])
            }
            
            return publicURL.absoluteString
            
        } catch {
            print("❌ Error uploading image: \(error)")
            throw error
        }
    }
    
    /// Deletes a goal cover image from Supabase Storage
    /// - Parameter imageUrl: The full URL or path to the image
    func deleteGoalCoverImage(imageUrl: String) async throws {
        // Extract the path from the full URL
        // URL format: https://{project}.supabase.co/storage/v1/object/public/goal-covers/{goalId}/cover.jpg
        guard let url = URL(string: imageUrl),
              let pathComponents = url.pathComponents.split(separator: "goal-covers").last else {
            print("⚠️ Could not extract path from URL: \(imageUrl)")
            return
        }
        
        let filePath = pathComponents.joined(separator: "/")
        
        print("🗑️ Deleting image: goal-covers/\(filePath)")
        
        do {
            try await client.storage
                .from("goal-covers")
                .remove(paths: [filePath])
            
            print("✅ Image deleted successfully")
        } catch {
            print("❌ Error deleting image: \(error)")
            throw error
        }
    }
    
    /// Updates a goal's cover_image_url in the database
    /// - Parameters:
    ///   - goalId: The UUID of the goal
    ///   - imageUrl: The new cover image URL (or nil to remove)
    func updateGoalCoverImageUrl(goalId: UUID, imageUrl: String?) async throws {
        struct CoverImageUpdate: Encodable {
            let cover_image_url: String?
        }
        
        print("💾 Updating goal \(goalId) cover_image_url to: \(imageUrl ?? "nil")")
        
        do {
            let _: [Goal] = try await client
                .from("goals")
                .update(CoverImageUpdate(cover_image_url: imageUrl))
                .eq("id", value: goalId)
                .execute()
                .value
            
            print("✅ Goal cover_image_url updated successfully")
        } catch {
            print("❌ Error updating goal cover_image_url: \(error)")
            throw error
        }
    }
    
    // MARK: - Collaboration Functions
    
    /// Creates collaboration requests for selected friends
    /// - Parameters:
    ///   - goalId: The UUID of the goal
    ///   - collaboratorIds: Array of friend user IDs to invite
    // MARK: - Profiles
    
    func searchUsers(query: String, limit: Int = 50) async throws -> [Profile] {
        guard !query.isEmpty else { return [] }
        
        if useMocks {
            print("🧪 [Mock] Searching users with query: \(query)")
            return []
        }
        
        let currentUserId = try await currentUserId()
        
        print("🔍 Searching users with query: \(query)")
        
        // Search across username, first_name, and last_name using ilike (case-insensitive)
        // Use OR conditions to match any of these fields
        let searchPattern = "%\(query)%"
        
        // Build OR query: username.ilike.%query% OR first_name.ilike.%query% OR last_name.ilike.%query%
        let profiles: [Profile] = try await client
            .from("profiles")
            .select("id,username,first_name,last_name,date_of_birth,avatar_url,created_at,updated_at")
            .neq("id", value: currentUserId) // Exclude current user
            .or("username.ilike.\(searchPattern),first_name.ilike.\(searchPattern),last_name.ilike.\(searchPattern)")
            .limit(limit)
            .execute()
            .value
        
        print("✅ Found \(profiles.count) users matching '\(query)'")
        return profiles
    }
    
    func getProfiles(userIds: [UUID]) async throws -> [Profile] {
        guard !userIds.isEmpty else { return [] }
        
        if useMocks {
            print("🧪 [Mock] Getting profiles for \(userIds.count) users")
            // Simulate network delay
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            // Return mock profiles
            return userIds.map { id in
                Profile(
                    id: id,
                    username: "user_\(id.uuidString.prefix(4))",
                    firstName: "Mock",
                    lastName: "Friend \(id.uuidString.prefix(4))",
                    dateOfBirth: Date(),
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        }
        
        // Check cache first
        var cachedProfiles: [Profile] = []
        var uncachedIds: [UUID] = []
        
        await MainActor.run {
            for userId in userIds {
                if let cached = dataCache.getCachedProfile(userId) {
                    cachedProfiles.append(cached)
                } else {
                    uncachedIds.append(userId)
                }
            }
        }
        
        // If all profiles are cached, return them
        if uncachedIds.isEmpty {
            print("✅ Got \(cachedProfiles.count) profiles from cache")
            return cachedProfiles
        }
        
        print("📥 Getting \(uncachedIds.count) profiles from API (\(cachedProfiles.count) from cache)")
        
        // Fetch uncached profiles
        let values: [any PostgrestFilterValue] = uncachedIds.map { $0.uuidString }
        let fetchedProfiles: [Profile] = try await client
            .from("profiles")
            .select("id,username,first_name,last_name,date_of_birth,avatar_url,created_at,updated_at")
            .in("id", values: values)
            .execute()
            .value
        
        // Cache the fetched profiles
        await MainActor.run {
            dataCache.cacheProfiles(fetchedProfiles)
        }
        
        print("✅ Got \(fetchedProfiles.count) profiles from API")
        
        // Combine cached and fetched profiles
        return cachedProfiles + fetchedProfiles
    }
    
    // MARK: - Friends
    
    func getFriends(forUserId userId: UUID) async throws -> [Friendship] {
        if useMocks {
            print("🧪 [Mock] Getting friends for user \(userId)")
            // Simulate network delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Return mock friends
            return [
                Friendship(
                    id: UUID(),
                    userId1: userId,
                    userId2: UUID(), // Friend
                    status: .accepted,
                    establishedAt: Date(),
                    createdAt: Date()
                ),
                Friendship(
                    id: UUID(),
                    userId1: userId,
                    userId2: UUID(), // Friend 2
                    status: .accepted,
                    establishedAt: Date(),
                    createdAt: Date()
                )
            ]
        }
        
        // Fetch friendships where user is user_id_1
        let friends1: [Friendship] = try await client
            .from("friendships")
            .select()
            .eq("user_id_1", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value
            
        // Fetch friendships where user is user_id_2
        let friends2: [Friendship] = try await client
            .from("friendships")
            .select()
            .eq("user_id_2", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value
            
        return friends1 + friends2
    }

    // MARK: - Goal Tagging
    
    /// Gets users tagged in a goal
    /// - Parameter goalId: The UUID of the goal
    func getTaggedUsers(goalId: UUID) async throws -> [GoalTag] {
        do {
            let tags: [GoalTag] = try await client
                .from("goal_tags")
                .select()
                .eq("goal_id", value: goalId)
                .execute()
                .value
            
            return tags
        } catch {
            print("❌ Error getting tagged users: \(error)")
            throw error
        }
    }
    
    /// Gets goals where a user is tagged
    /// - Parameter userId: The user ID (defaults to current user)
    func getGoalsTaggedForUser(userId: UUID? = nil) async throws -> [Goal] {
        let targetUserId: UUID
        if let userId = userId {
            targetUserId = userId
        } else {
            targetUserId = try await currentUserId()
        }
        
        do {
            // Get goal IDs where user is tagged
            let tags: [GoalTag] = try await client
                .from("goal_tags")
                .select()
                .eq("user_id", value: targetUserId)
                .execute()
                .value
            
            let goalIds = tags.map { $0.goalId }
            
            guard !goalIds.isEmpty else { return [] }
            
            // Fetch the goals
            let goals: [Goal] = try await client
                .from("goals")
                .select()
                .in("id", values: goalIds)
                .execute()
                .value
            
            return goals
        } catch {
            print("❌ Error getting goals tagged for user: \(error)")
            throw error
        }
    }
    
    /// Batch fetch tagged users for multiple goals
    /// Returns dictionary: goalId -> Set of tagged user IDs
    func getTaggedUsersForGoals(goalIds: [UUID]) async throws -> [UUID: Set<UUID>] {
        guard !goalIds.isEmpty else { return [:] }
        
        do {
            // Batch requests if too many goals (PostgreSQL has limits on IN clause size)
            let batchSize = 100
            var allTags: [GoalTag] = []
            
            for i in stride(from: 0, to: goalIds.count, by: batchSize) {
                let batch = Array(goalIds[i..<min(i + batchSize, goalIds.count)])
                let values: [any PostgrestFilterValue] = batch.map { $0.uuidString }
                let batchTags: [GoalTag] = try await client
                    .from("goal_tags")
                    .select("id,goal_id,user_id,conversation_id,created_at")
                    .in("goal_id", values: values)
                    .execute()
                    .value
                allTags.append(contentsOf: batchTags)
            }
            
            let tags = allTags
            
            var result: [UUID: Set<UUID>] = [:]
            for tag in tags {
                if result[tag.goalId] == nil {
                    result[tag.goalId] = Set<UUID>()
                }
                result[tag.goalId]?.insert(tag.userId)
            }
            
            return result
        } catch {
            print("❌ Error getting tagged users for goals: \(error)")
            throw error
        }
    }
    
    /// Get goal counts per conversation
    /// Returns dictionary: conversationId -> count of distinct goals
    func getGoalCountsForConversations(conversationIds: [UUID]) async throws -> [UUID: Int] {
        guard !conversationIds.isEmpty else { return [:] }
        
        do {
            // Fetch all tags for the conversations and count distinct goals
            let tags: [GoalTag] = try await client
                .from("goal_tags")
                .select()
                .in("conversation_id", values: conversationIds)
                .not("conversation_id", operator: .is, value: "null")
                .execute()
                .value
            
            // Group by conversation_id and count distinct goal_ids
            var counts: [UUID: Set<UUID>] = [:]
            for tag in tags {
                if let conversationId = tag.conversationId {
                    if counts[conversationId] == nil {
                        counts[conversationId] = Set<UUID>()
                    }
                    counts[conversationId]?.insert(tag.goalId)
                }
            }
            
            // Convert to [UUID: Int]
            var result: [UUID: Int] = [:]
            for (conversationId, goalIds) in counts {
                result[conversationId] = goalIds.count
            }
            
            // Ensure all conversation IDs are in result (even if 0)
            for conversationId in conversationIds {
                if result[conversationId] == nil {
                    result[conversationId] = 0
                }
            }
            
            return result
        } catch let error as URLError where error.code == .cancelled {
            // Request was cancelled (e.g., view disappeared) - return empty result
            print("⚠️ Goal counts request cancelled")
            return [:]
        } catch {
            print("❌ Error getting goal counts for conversations: \(error)")
            // Return empty result instead of throwing to prevent UI errors
            return [:]
        }
    }
    
    struct CreateGoalParams {
        let title: String
        let body: String?
        let visibility: GoalVisibility
        let isDraft: Bool
        let items: [String]
        let acl: [UUID: String] // UserId: Role
        let coverImage: Data?
    }
    
    func createGoal(_ params: CreateGoalParams) async throws -> Goal {
        // #region agent log
        writeDebugLog(["function": "createGoal", "title": params.title, "visibility": params.visibility.rawValue, "isDraft": params.isDraft, "itemsCount": params.items.count, "hasCoverImage": params.coverImage != nil, "timestamp": Date().timeIntervalSince1970])
        // #endregion
        let currentUserId = try await currentUserId()
        
        if useMocks {
            print("🧪 [Mock] Creating goal: \(params.title)")
            let goalId = UUID()
            let newGoal = Goal(
                id: goalId,
                ownerId: currentUserId,
                title: params.title,
                body: params.body,
                status: .active,
                visibility: params.visibility,
                coverImageUrl: params.coverImage != nil ? "https://mock.url/cover.jpg" : nil,
                createdAt: Date(),
                updatedAt: Date(),
                isDraft: params.isDraft,
                items: params.items.map { GoalItem(id: UUID(), goalId: goalId, title: $0, completed: false, createdAt: Date()) }
            )
            mockGoals.insert(newGoal, at: 0)
            
            return newGoal
        }
        
        // Real implementation
        // 1. Insert Goal (using RPC workaround)
        // Parameter order must match: p_title, p_body, p_status, p_visibility, p_owner_id, p_is_draft
        struct InsertGoalParams: Encodable {
            let p_title: String
            let p_body: String  // Non-optional, use empty string for nil
            let p_status: String
            let p_visibility: String
            let p_owner_id: UUID
            let p_is_draft: Bool
        }
        
        let rpcParams = InsertGoalParams(
            p_title: params.title,
            p_body: params.body ?? "",  // Use empty string instead of nil for optional body
            p_status: GoalStatus.active.rawValue,
            p_visibility: params.visibility.rawValue,
            p_owner_id: currentUserId,
            p_is_draft: params.isDraft
        )
        
        // #region agent log
        writeDebugLog(["function": "createGoal", "step": "before_rpc", "params": ["title": params.title, "body": params.body ?? "", "status": GoalStatus.active.rawValue, "visibility": params.visibility.rawValue], "timestamp": Date().timeIntervalSince1970])
        // #endregion
        let newGoalId: UUID = try await client
            .rpc("insert_goal", params: rpcParams)
            .execute()
            .value
        
        // #region agent log
        writeDebugLog(["function": "createGoal", "step": "after_rpc", "goalId": newGoalId.uuidString, "timestamp": Date().timeIntervalSince1970])
        // #endregion
        // 2. Fetch created goal
        let response: [Goal] = try await client
            .from("goals")
            .select("id,owner_id,title,body,status,visibility,cover_image_url,is_draft,created_at,updated_at")
            .eq("id", value: newGoalId)
            .execute()
            .value
            
        guard var createdGoal = response.first else {
            // #region agent log
            writeDebugLog(["function": "createGoal", "step": "error", "error": "Failed to retrieve created goal", "responseCount": response.count, "timestamp": Date().timeIntervalSince1970])
            // #endregion
            throw NSError(domain: "GoalCreation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve created goal"])
        }
        
        // 3. Create items
        if !params.items.isEmpty {
            struct GoalItemInsert: Encodable {
                let goal_id: UUID
                let title: String
                let completed: Bool
            }
            
            let itemInserts = params.items.map { title in
                GoalItemInsert(goal_id: newGoalId, title: title, completed: false)
            }
            
            let createdItems: [GoalItem] = try await client
                .from("goal_items")
                .insert(itemInserts)
                .select()
                .execute()
                .value
                
            createdGoal.items = createdItems
        }
        
        // 4. Create ACLs
        if params.visibility == .custom {
            for (userId, role) in params.acl {
                let acl = GoalACL(goalId: newGoalId, userId: userId, role: role)
                _ = try await client.from("goal_acl").insert(acl).execute()
            }
        }
        
        // 5. Upload Image
        if let imageData = params.coverImage {
            let imageUrl = try await uploadGoalCoverImage(goalId: newGoalId, imageData: imageData)
             try await updateGoalCoverImageUrl(goalId: newGoalId, imageUrl: imageUrl)
             createdGoal = Goal(
                 id: createdGoal.id,
                 ownerId: createdGoal.ownerId,
                 title: createdGoal.title,
                 body: createdGoal.body,
                 status: createdGoal.status,
                 visibility: createdGoal.visibility,
                 coverImageUrl: imageUrl,
                 createdAt: createdGoal.createdAt,
                 updatedAt: createdGoal.updatedAt,
                isDraft: createdGoal.isDraft,
                items: createdGoal.items
             )
        }
        
        // Cache the new goal
        await MainActor.run {
            dataCache.cacheGoal(createdGoal)
        }
        
        // #region agent log
        writeDebugLog(["function": "createGoal", "step": "success", "goalId": createdGoal.id.uuidString, "timestamp": Date().timeIntervalSince1970])
        // #endregion
        return createdGoal
    }

    /// Fetches goals and their items separately to avoid RLS join context ambiguity
    /// - Parameters:
    ///   - filterOwnerId: Optional owner_id to filter goals. If nil, fetches all visible goals.
    ///   - limit: Maximum number of goals to fetch (default: 20)
    ///   - offset: Number of goals to skip for pagination (default: 0)
    /// - Returns: Array of goals with their items attached
    func fetchGoalsWithItems(filterOwnerId: UUID? = nil, limit: Int = 20, offset: Int = 0) async throws -> [Goal] {
        if useMocks {
            return mockGoals.filter { !$0.isDraft }
        }
        
        let currentUserId = try await currentUserId()
        
        // Step 1: Fetch goals (explicitly select all columns including owner_id and is_draft)
        // Include goals where user is owner OR where user is tagged
        // Exclude drafts from feed queries (only show published goals)
        var goalsQuery = client.from("goals")
            .select("id,owner_id,title,body,status,visibility,cover_image_url,is_draft,created_at,updated_at")
            .eq("is_draft", value: false) // Only fetch published goals
        if let ownerId = filterOwnerId {
            goalsQuery = goalsQuery.eq("owner_id", value: ownerId)
            print("🔍 Fetching goals with owner filter: \(ownerId.uuidString)")
        } else {
            print("🔍 Fetching all visible goals (no owner filter)")
        }
        
        let goals: [Goal] = try await goalsQuery
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        print("✅ Fetched \(goals.count) goals from database")
        if !goals.isEmpty {
            let visibilityCounts = Dictionary(grouping: goals, by: { $0.visibility })
            print("   Visibility breakdown: \(visibilityCounts.map { "\($0.key.rawValue): \($0.value.count)" }.joined(separator: ", "))")
        }
        
        // If no goals, return empty array
        guard !goals.isEmpty else {
            print("⚠️ No goals found - returning empty array")
            return []
        }
        
        // Step 2: Fetch all items for these goals using RPC function
        // This bypasses RLS policy evaluation and avoids ambiguous column errors
        // Batch if too many goals to avoid RPC parameter limits
        let goalIds = goals.map { $0.id }
        let items: [GoalItem]
        do {
            // Batch RPC calls if needed (PostgreSQL has limits on array parameters)
            let batchSize = 100
            var allItems: [GoalItem] = []
            
            for i in stride(from: 0, to: goalIds.count, by: batchSize) {
                let batch = Array(goalIds[i..<min(i + batchSize, goalIds.count)])
                let batchItems: [GoalItem] = try await client
                    .rpc("get_visible_goal_items", params: ["goal_ids": batch])
                    .execute()
                    .value
                allItems.append(contentsOf: batchItems)
            }
            
            items = allItems
            print("✅ Fetched \(items.count) items for \(goalIds.count) goals")
        } catch {
            print("❌ Error fetching goal items via RPC: \(error)")
            // If RPC fails, try fetching items directly (may be slower but more reliable)
            print("   Falling back to direct item fetch...")
            // Batch direct queries too
            let batchSize = 100
            var allItems: [GoalItem] = []
            
            for i in stride(from: 0, to: goalIds.count, by: batchSize) {
                let batch = Array(goalIds[i..<min(i + batchSize, goalIds.count)])
                let values: [any PostgrestFilterValue] = batch.map { $0.uuidString }
                let batchItems: [GoalItem] = try await client
                    .from("goal_items")
                    .select()
                    .in("goal_id", values: values)
                    .execute()
                    .value
                allItems.append(contentsOf: batchItems)
            }
            
            items = allItems
            print("✅ Fetched \(items.count) items via direct query")
        }
        
        // Step 3: Group items by goal_id
        let itemsByGoalId = Dictionary(grouping: items, by: { $0.goalId })
        
        // Step 4: Attach items to goals
        var goalsWithItems: [Goal] = []
        for goal in goals {
            var updatedGoal = goal
            updatedGoal.items = itemsByGoalId[goal.id] ?? []
            goalsWithItems.append(updatedGoal)
        }
        
        // Cache the goals
        await MainActor.run {
            dataCache.cacheGoals(goalsWithItems)
        }
        
        // Step 5: Return goals with items
        // Note: RLS policies automatically include goals where user is tagged
        return goalsWithItems
    }
    
    // MARK: - Draft Functions
    
    /// Fetches draft goals for the current user
    /// - Parameter userId: The user ID to fetch drafts for (defaults to current user)
    /// - Returns: Array of draft goals with their items
    func fetchDraftGoals(forUserId userId: UUID? = nil) async throws -> [Goal] {
        let targetUserId: UUID
        if let userId = userId {
            targetUserId = userId
        } else {
            targetUserId = try await currentUserId()
        }
        
        // Mock Mode
        if useMocks {
            print("🧪 [Mock] Fetching draft goals for user \(targetUserId)")
            return mockGoals.filter { $0.isDraft && $0.ownerId == targetUserId }
        }
        
        print("📝 Fetching draft goals for user \(targetUserId)")
        
        // Fetch draft goals owned by the user
        // Explicitly select all required fields to ensure proper decoding
        let ownedDrafts: [Goal]
        do {
            ownedDrafts = try await client
                .from("goals")
                .select("id,owner_id,title,body,status,visibility,cover_image_url,is_draft,created_at,updated_at")
                .eq("owner_id", value: targetUserId)
                .eq("is_draft", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(ownedDrafts.count) owned draft goals")
        } catch {
            // Handle cancellations gracefully
            if let urlError = error as? URLError, urlError.code == .cancelled {
                print("⚠️ Draft fetch cancelled (likely due to navigation)")
                return []
            }
            if error is CancellationError {
                print("⚠️ Draft fetch cancelled (SwiftUI task cancellation)")
                return []
            }
            print("❌ Error fetching owned drafts: \(error)")
            // Only throw actual errors, not cancellations
            throw error
        }
        
        print("✅ Fetched \(ownedDrafts.count) draft goals")
        
        // Attach items to drafts
        return try await attachItemsToDrafts(ownedDrafts)
    }
    
    /// Helper function to attach items to draft goals
    private func attachItemsToDrafts(_ drafts: [Goal]) async throws -> [Goal] {
        guard !drafts.isEmpty else {
            return []
        }
        
        // Fetch items for draft goals
        var itemsByGoalId: [UUID: [GoalItem]] = [:]
        let goalIds = drafts.map { $0.id }
        do {
            let items: [GoalItem] = try await client
                .rpc("get_visible_goal_items", params: ["goal_ids": goalIds])
                .execute()
                .value
            
            itemsByGoalId = Dictionary(grouping: items, by: { $0.goalId })
            print("✅ Loaded items for \(itemsByGoalId.count) draft goals")
        } catch {
            print("⚠️ Warning: Failed to load items for draft goals: \(error)")
            // Continue without items rather than failing completely
        }
        
        // Return goals with items attached
        return drafts.map { goal in
            var updatedGoal = goal
            updatedGoal.items = itemsByGoalId[goal.id] ?? []
            return updatedGoal
        }
    }
    
    /// Approves a collaborative draft as a collaborator
    /// - Parameter goalId: The UUID of the draft goal
    func approveDraft(goalId: UUID) async throws {
        // This method is no longer needed with the removal of collaborative goals
        // Drafts can be published directly by the owner
        throw NSError(domain: "Draft", code: -1, userInfo: [NSLocalizedDescriptionKey: "approveDraft is deprecated. Use publishDraft instead."])
    }
    
    /// Publishes a draft goal
    /// - Parameters:
    ///   - goalId: The UUID of the draft goal
    ///   - removeUnapprovedCollaborators: If true, removes collaborators who haven't approved
    func publishDraft(goalId: UUID) async throws {
        let currentUserId = try await currentUserId()
        
        if useMocks {
            print("🧪 [Mock] Publishing draft \(goalId)")
            if let index = mockGoals.firstIndex(where: { $0.id == goalId }) {
                var goal = mockGoals[index]
                
                // Mocks permissions check
                 guard goal.ownerId == currentUserId else {
                    throw NSError(domain: "Draft", code: -1, userInfo: [NSLocalizedDescriptionKey: "Only the owner can publish drafts"])
                }
                
                // Update to published
                goal = Goal(
                    id: goal.id,
                    ownerId: goal.ownerId,
                    title: goal.title,
                    body: goal.body,
                    status: goal.status,
                    visibility: goal.visibility,
                    coverImageUrl: goal.coverImageUrl,
                    createdAt: goal.createdAt,
                    updatedAt: goal.updatedAt,
                    isDraft: false, // PUBLISHED
                    items: goal.items
                )
                mockGoals[index] = goal
            }
            return
        }
        
        print("📢 Publishing draft \(goalId)")
        
        // Get the goal to check ownership
        let goals: [Goal] = try await client
            .from("goals")
            .select()
            .eq("id", value: goalId)
            .execute()
            .value
        
        guard let draftGoal = goals.first else {
            throw NSError(domain: "Draft", code: -1, userInfo: [NSLocalizedDescriptionKey: "Goal not found"])
        }
        
        guard draftGoal.ownerId == currentUserId else {
            throw NSError(domain: "Draft", code: -1, userInfo: [NSLocalizedDescriptionKey: "Only the owner can publish drafts"])
        }
        
        // Update goal to published (is_draft = false)
        struct DraftPublishUpdate: Encodable {
            let is_draft: Bool
            let updated_at: String
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let update = DraftPublishUpdate(
            is_draft: false,
            updated_at: dateFormatter.string(from: Date())
        )
        
        let _: [Goal] = try await client
            .from("goals")
            .update(update)
            .eq("id", value: goalId)
            .execute()
            .value
        
        print("✅ Draft published successfully")
    }
    
    /// Updates a goal's draft status
    /// - Parameters:
    ///   - goalId: The UUID of the goal
    ///   - isDraft: The new draft status
    func updateGoalDraftStatus(goalId: UUID, isDraft: Bool) async throws {
        struct DraftStatusUpdate: Encodable {
            let is_draft: Bool
            let updated_at: String
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let update = DraftStatusUpdate(
            is_draft: isDraft,
            updated_at: dateFormatter.string(from: Date())
        )
        
        print("💾 Updating goal \(goalId) draft status to: \(isDraft)")
        
        let _: [Goal] = try await client
            .from("goals")
            .update(update)
            .eq("id", value: goalId)
            .execute()
            .value
        
        print("✅ Goal draft status updated")
    }
    
    // MARK: - Likes Functions
    
    /// Likes a goal for the current user
    /// - Parameter goalId: The UUID of the goal to like
    func likeGoal(goalId: UUID) async throws {
        let currentUserId = try await currentUserId()
        
        if useMocks {
            print("🧪 [Mock] Liking goal \(goalId)")
            return
        }
        
        print("❤️ Liking goal \(goalId)")
        
        struct LikeInsert: Encodable {
            let goal_id: UUID
            let user_id: UUID
        }
        
        do {
            // Insert like - don't decode response, just check for success
            try await client
                .from("goal_likes")
                .insert(LikeInsert(goal_id: goalId, user_id: currentUserId), returning: .representation)
                .execute()
            
            print("✅ Goal liked successfully")
        } catch {
            // Handle duplicate like error gracefully (unique constraint violation)
            if let postgrestError = error as? PostgrestError,
               let errorCode = postgrestError.code,
               errorCode == "23505" { // PostgreSQL unique violation
                print("⚠️ Goal already liked by user")
                // Don't throw - just return silently
                return
            }
            print("❌ Error liking goal: \(error)")
            throw error
        }
    }
    
    /// Unlikes a goal for the current user
    /// - Parameter goalId: The UUID of the goal to unlike
    func unlikeGoal(goalId: UUID) async throws {
        let currentUserId = try await currentUserId()
        
        if useMocks {
            print("🧪 [Mock] Unliking goal \(goalId)")
            return
        }
        
        print("💔 Unliking goal \(goalId)")
        
        // Delete doesn't need to return data, just execute
        try await client
            .from("goal_likes")
            .delete()
            .eq("goal_id", value: goalId)
            .eq("user_id", value: currentUserId)
            .execute()
        
        print("✅ Goal unliked successfully")
    }
    
    /// Gets the likes count for a goal
    /// - Parameter goalId: The UUID of the goal
    /// - Returns: The number of likes
    func getLikesCount(goalId: UUID) async throws -> Int {
        if useMocks {
            return Int.random(in: 0...50)
        }
        
        // Count likes directly from table - use lightweight struct for counting
        struct LikeId: Codable {
            let id: UUID
        }
        let likes: [LikeId] = try await client
            .from("goal_likes")
            .select("id")
            .eq("goal_id", value: goalId)
            .execute()
            .value
        
        return likes.count
    }
    
    /// Checks if the current user has liked a goal
    /// - Parameter goalId: The UUID of the goal
    /// - Returns: True if the current user has liked the goal
    func isLikedByCurrentUser(goalId: UUID) async throws -> Bool {
        let currentUserId = try await currentUserId()
        
        if useMocks {
            return Bool.random()
        }
        
        // Check if like exists - use lightweight struct
        struct LikeId: Codable {
            let id: UUID
        }
        let likes: [LikeId] = try await client
            .from("goal_likes")
            .select("id")
            .eq("goal_id", value: goalId)
            .eq("user_id", value: currentUserId)
            .limit(1)
            .execute()
            .value
        
        return !likes.isEmpty
    }
    
    /// Gets likes data for multiple goals (batch fetch)
    /// - Parameter goalIds: Array of goal UUIDs
    /// - Returns: Dictionary mapping goal IDs to (count: Int, isLiked: Bool)
    func getLikesForGoals(goalIds: [UUID]) async throws -> [UUID: (count: Int, isLiked: Bool)] {
        guard !goalIds.isEmpty else { return [:] }
        
        let currentUserId = try await currentUserId()
        
        if useMocks {
            var result: [UUID: (count: Int, isLiked: Bool)] = [:]
            for goalId in goalIds {
                result[goalId] = (count: Int.random(in: 0...50), isLiked: Bool.random())
            }
            return result
        }
        
        // Fetch all likes for these goals - use lightweight struct
        struct LikeRecord: Codable {
            let goal_id: UUID
            let user_id: UUID
            
            enum CodingKeys: String, CodingKey {
                case goal_id
                case user_id
            }
        }
        // Batch requests if too many goals (PostgreSQL has limits on IN clause size)
        let batchSize = 100
        var allLikes: [LikeRecord] = []
        
        for i in stride(from: 0, to: goalIds.count, by: batchSize) {
            let batch = Array(goalIds[i..<min(i + batchSize, goalIds.count)])
            let values: [any PostgrestFilterValue] = batch.map { $0.uuidString }
            let batchLikes: [LikeRecord] = try await client
                .from("goal_likes")
                .select("goal_id,user_id")
                .in("goal_id", values: values)
                .execute()
                .value
            allLikes.append(contentsOf: batchLikes)
        }
        
        let likes = allLikes
        
        // Count likes per goal
        let likesByGoalId = Dictionary(grouping: likes, by: { $0.goal_id })
        
        // Build result dictionary
        var result: [UUID: (count: Int, isLiked: Bool)] = [:]
        for goalId in goalIds {
            let goalLikes = likesByGoalId[goalId] ?? []
            let count = goalLikes.count
            let isLiked = goalLikes.contains { $0.user_id == currentUserId }
            result[goalId] = (count: count, isLiked: isLiked)
        }
        
        return result
    }
    
    // MARK: - Comments Functions
    
    /// Fetches comments for a goal with author profiles
    /// - Parameter goalId: The UUID of the goal
    /// - Returns: Array of comments with author profiles
    func getComments(goalId: UUID) async throws -> [GoalComment] {
        if useMocks {
            print("🧪 [Mock] Getting comments for goal \(goalId)")
            return []
        }
        
        print("💬 Fetching comments for goal \(goalId)")
        
        // Fetch comments with author profiles using a join
        // Note: Supabase PostgREST doesn't support automatic joins, so we'll fetch separately
        let comments: [GoalComment] = try await client
            .from("goal_comments")
            .select()
            .eq("goal_id", value: goalId)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        // Fetch author profiles
        let userIds = Array(Set(comments.map { $0.userId }))
        guard !userIds.isEmpty else { return comments }
        
        let profiles = try await getProfiles(userIds: userIds)
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        
        // Attach profiles to comments
        return comments.map { comment in
            var updatedComment = comment
            updatedComment.authorProfile = profileMap[comment.userId]
            return updatedComment
        }
    }
    
    /// Gets comment counts for multiple goals
    /// - Parameter goalIds: Array of goal UUIDs
    /// - Returns: Dictionary mapping goal IDs to their comment counts
    func getCommentCountsForGoals(goalIds: [UUID]) async throws -> [UUID: Int] {
        guard !goalIds.isEmpty else { return [:] }
        
        if useMocks {
            print("🧪 [Mock] Getting comment counts for \(goalIds.count) goals")
            return Dictionary(uniqueKeysWithValues: goalIds.map { ($0, Int.random(in: 0...10)) })
        }
        
        print("💬 Fetching comment counts for \(goalIds.count) goals")
        
        // Use a simpler struct that only needs goal_id for counting
        struct CommentGoalId: Codable {
            let goal_id: UUID
            
            enum CodingKeys: String, CodingKey {
                case goal_id
            }
        }
        
        // Batch requests if too many goals (PostgreSQL has limits on IN clause size)
        let batchSize = 100
        var allCommentIds: [CommentGoalId] = []
        
        for i in stride(from: 0, to: goalIds.count, by: batchSize) {
            let batch = Array(goalIds[i..<min(i + batchSize, goalIds.count)])
            let values: [any PostgrestFilterValue] = batch.map { $0.uuidString }
            let batchComments: [CommentGoalId] = try await client
                .from("goal_comments")
                .select("goal_id")
                .in("goal_id", values: values)
                .execute()
                .value
            allCommentIds.append(contentsOf: batchComments)
        }
        
        let commentIds = allCommentIds
        
        // Count comments per goal
        var counts: [UUID: Int] = [:]
        for goalId in goalIds {
            counts[goalId] = commentIds.filter { $0.goal_id == goalId }.count
        }
        
        return counts
    }
    
    /// Creates a new comment on a goal
    /// - Parameters:
    ///   - goalId: The UUID of the goal
    ///   - content: The comment content
    /// - Returns: The created comment
    func createComment(goalId: UUID, content: String) async throws -> GoalComment {
        let currentUserId = try await currentUserId()
        
        if useMocks {
            print("🧪 [Mock] Creating comment on goal \(goalId)")
            let comment = GoalComment(
                goalId: goalId,
                userId: currentUserId,
                content: content
            )
            return comment
        }
        
        print("💬 Creating comment on goal \(goalId)")
        
        struct CommentInsert: Encodable {
            let goal_id: UUID
            let user_id: UUID
            let content: String
        }
        
        let insert = CommentInsert(goal_id: goalId, user_id: currentUserId, content: content)
        
        let created: [GoalComment] = try await client
            .from("goal_comments")
            .insert(insert)
            .select()
            .execute()
            .value
        
        guard let comment = created.first else {
            throw NSError(domain: "Comment", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create comment"])
        }
        
        // Load author profile
        let profiles = try await getProfiles(userIds: [currentUserId])
        var commentWithProfile = comment
        commentWithProfile.authorProfile = profiles.first
        return commentWithProfile
    }
    
    /// Updates a comment
    /// - Parameters:
    ///   - commentId: The UUID of the comment
    ///   - content: The new comment content
    /// - Returns: The updated comment
    func updateComment(commentId: UUID, content: String) async throws -> GoalComment {
        if useMocks {
            print("🧪 [Mock] Updating comment \(commentId)")
            return GoalComment(goalId: UUID(), userId: UUID(), content: content)
        }
        
        print("💬 Updating comment \(commentId)")
        
        struct CommentUpdate: Encodable {
            let content: String
            let updated_at: String
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let update = CommentUpdate(
            content: content,
            updated_at: dateFormatter.string(from: Date())
        )
        
        let updated: [GoalComment] = try await client
            .from("goal_comments")
            .update(update)
            .eq("id", value: commentId)
            .select()
            .execute()
            .value
        
        guard let comment = updated.first else {
            throw NSError(domain: "Comment", code: -1, userInfo: [NSLocalizedDescriptionKey: "Comment not found"])
        }
        
        return comment
    }
    
    /// Deletes a comment
    /// - Parameter commentId: The UUID of the comment
    func deleteComment(commentId: UUID) async throws {
        if useMocks {
            print("🧪 [Mock] Deleting comment \(commentId)")
            return
        }
        
        print("🗑️ Deleting comment \(commentId)")
        
        let _: [GoalComment] = try await client
            .from("goal_comments")
            .delete()
            .eq("id", value: commentId)
            .execute()
            .value
    }
    
    /// Subscribes to real-time comment updates for a goal
    /// Note: Realtime must be enabled for goal_comments table in Supabase Dashboard.
    /// This is a simplified polling-based implementation until Realtime is properly configured.
    /// - Parameters:
    ///   - goalId: The UUID of the goal
    ///   - onNewComment: Callback when a new comment is added
    ///   - onUpdatedComment: Callback when a comment is updated
    ///   - onDeletedComment: Callback when a comment is deleted
    /// - Returns: A Task that can be cancelled to stop polling
    func subscribeToComments(
        goalId: UUID,
        onNewComment: @escaping (GoalComment) -> Void,
        onUpdatedComment: @escaping (GoalComment) -> Void,
        onDeletedComment: @escaping (UUID) -> Void
    ) async throws -> Task<Void, Never> {
        print("📡 Setting up comment polling for goal \(goalId)")
        
        // For now, use polling. Once Realtime is enabled, this can be replaced with proper channel subscriptions.
        // Poll every 3 seconds for new comments
        return Task {
            var lastCommentIds: Set<UUID> = []
            
            while !Task.isCancelled {
                do {
                    let comments = try await getComments(goalId: goalId)
                    let currentCommentIds = Set(comments.map { $0.id })
                    
                    // Detect new comments
                    let newCommentIds = currentCommentIds.subtracting(lastCommentIds)
                    for commentId in newCommentIds {
                        if let comment = comments.first(where: { $0.id == commentId }) {
                            onNewComment(comment)
                        }
                    }
                    
                    // Detect deleted comments
                    let deletedCommentIds = lastCommentIds.subtracting(currentCommentIds)
                    for commentId in deletedCommentIds {
                        onDeletedComment(commentId)
                    }
                    
                    // Note: Update detection would require tracking comment content/updated_at
                    // For simplicity, we'll reload all comments on updates
                    
                    lastCommentIds = currentCommentIds
                    
                    // Poll every 3 seconds
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                } catch {
                    print("Error polling comments: \(error)")
                    // Continue polling even on error
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
    }
    
    /// Archives a goal (sets status to archived)
    /// - Parameter goalId: The UUID of the goal to archive
    func archiveGoal(goalId: UUID) async throws {
        if useMocks {
            print("🧪 [Mock] Archiving goal \(goalId)")
            return
        }
        
        print("📦 Archiving goal \(goalId)")
        
        struct StatusUpdate: Encodable {
            let status: String
        }
        
        let _: [Goal] = try await client
            .from("goals")
            .update(StatusUpdate(status: "archived"))
            .eq("id", value: goalId)
            .execute()
            .value
        
        print("✅ Goal archived successfully")
    }
    
    /// Unarchives a goal (sets status back to active or completed based on items)
    /// - Parameter goalId: The UUID of the goal to unarchive
    func unarchiveGoal(goalId: UUID) async throws {
        if useMocks {
            print("🧪 [Mock] Unarchiving goal \(goalId)")
            return
        }
        
        print("📤 Unarchiving goal \(goalId)")
        
        // First, check if goal has items and if they're all completed
        let items: [GoalItem] = try await client
            .from("goal_items")
            .select()
            .eq("goal_id", value: goalId)
            .execute()
            .value
        
        // Determine new status: completed if all items are done, otherwise active
        let newStatus = (!items.isEmpty && items.allSatisfy { $0.completed }) ? "completed" : "active"
        
        struct StatusUpdate: Encodable {
            let status: String
        }
        
        let _: [Goal] = try await client
            .from("goals")
            .update(StatusUpdate(status: newStatus))
            .eq("id", value: goalId)
            .execute()
            .value
        
        print("✅ Goal unarchived successfully (status: \(newStatus))")
    }
    
    // MARK: - Notifications
    
    /// Fetches notifications for the current user
    /// - Parameters:
    ///   - userId: The user ID to fetch notifications for
    ///   - limit: Maximum number of notifications to fetch (default: 50)
    ///   - offset: Number of notifications to skip for pagination (default: 0)
    /// - Returns: Array of notifications ordered by created_at DESC
    func getNotifications(userId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [AppNotification] {
        if useMocks {
            print("🧪 [Mock] Getting notifications for user \(userId)")
            return []
        }
        
        print("📬 Fetching notifications for user \(userId)")
        
        let notifications: [AppNotification] = try await client
            .from("notifications")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        print("✅ Fetched \(notifications.count) notifications")
        return notifications
    }
    
    /// Marks a notification as read
    /// - Parameter notificationId: The UUID of the notification to mark as read
    func markNotificationAsRead(notificationId: UUID) async throws {
        if useMocks {
            print("🧪 [Mock] Marking notification \(notificationId) as read")
            return
        }
        
        print("✅ Marking notification \(notificationId) as read")
        
        struct NotificationUpdate: Encodable {
            let read_at: String
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let update = NotificationUpdate(read_at: dateFormatter.string(from: Date()))
        
        try await client
            .from("notifications")
            .update(update)
            .eq("id", value: notificationId)
            .execute()
        
        print("✅ Notification marked as read")
    }
    
    /// Marks all notifications as read for a user
    /// - Parameter userId: The UUID of the user
    func markAllNotificationsAsRead(userId: UUID) async throws {
        if useMocks {
            print("🧪 [Mock] Marking all notifications as read for user \(userId)")
            return
        }
        
        print("✅ Marking all notifications as read for user \(userId)")
        
        struct NotificationUpdate: Encodable {
            let read_at: String
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let update = NotificationUpdate(read_at: dateFormatter.string(from: Date()))
        
        try await client
            .from("notifications")
            .update(update)
            .eq("user_id", value: userId)
            .is("read_at", value: nil)
            .execute()
        
        print("✅ All notifications marked as read")
    }
    
    /// Gets the count of unread notifications for a user
    /// - Parameter userId: The UUID of the user
    /// - Returns: The count of unread notifications
    func getUnreadNotificationCount(userId: UUID) async throws -> Int {
        if useMocks {
            print("🧪 [Mock] Getting unread notification count for user \(userId)")
            return 0
        }
        
        struct NotificationId: Codable {
            let id: UUID
        }
        
        // Count unread notifications
        let notifications: [NotificationId] = try await client
            .from("notifications")
            .select("id")
            .eq("user_id", value: userId)
            .is("read_at", value: nil)
            .execute()
            .value
        
        // Count pending friend requests (incoming)
        struct FriendshipId: Codable {
            let id: UUID
        }
        
        let friendRequests: [FriendshipId] = try await client
            .from("friendships")
            .select("id")
            .eq("user_id_2", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        
        return notifications.count + friendRequests.count
    }
}

// MARK: - Data Cache

/// In-memory cache for frequently accessed data to reduce API calls and improve performance
@MainActor
class DataCache {
    static let shared = DataCache()
    
    private var profileCache: [UUID: (profile: Profile, timestamp: Date)] = [:]
    private var goalCache: [UUID: (goal: Goal, timestamp: Date)] = [:]
    
    private let profileTTL: TimeInterval = 300 // 5 minutes
    private let goalTTL: TimeInterval = 120 // 2 minutes
    
    private init() {}
    
    // MARK: - Profile Caching
    
    func getCachedProfile(_ id: UUID) -> Profile? {
        guard let cached = profileCache[id] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) > profileTTL {
            profileCache.removeValue(forKey: id)
            return nil
        }
        
        return cached.profile
    }
    
    func cacheProfile(_ profile: Profile) {
        profileCache[profile.id] = (profile, Date())
    }
    
    func cacheProfiles(_ profiles: [Profile]) {
        let now = Date()
        for profile in profiles {
            profileCache[profile.id] = (profile, now)
        }
        // Enforce size limits after caching
        enforceSizeLimits()
    }
    
    func invalidateProfile(_ id: UUID) {
        profileCache.removeValue(forKey: id)
    }
    
    // MARK: - Goal Caching
    
    func getCachedGoal(_ id: UUID) -> Goal? {
        guard let cached = goalCache[id] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) > goalTTL {
            goalCache.removeValue(forKey: id)
            return nil
        }
        
        return cached.goal
    }
    
    func cacheGoal(_ goal: Goal) {
        goalCache[goal.id] = (goal, Date())
    }
    
    func cacheGoals(_ goals: [Goal]) {
        let now = Date()
        for goal in goals {
            goalCache[goal.id] = (goal, now)
        }
        // Enforce size limits after caching
        enforceSizeLimits()
    }
    
    func invalidateGoal(_ id: UUID) {
        goalCache.removeValue(forKey: id)
    }
    
    func invalidateAllGoals() {
        goalCache.removeAll()
    }
    
    // MARK: - Cache Management
    
    func clearExpiredEntries() {
        let now = Date()
        
        // Remove expired profiles
        profileCache = profileCache.filter { _, value in
            now.timeIntervalSince(value.timestamp) <= profileTTL
        }
        
        // Remove expired goals
        goalCache = goalCache.filter { _, value in
            now.timeIntervalSince(value.timestamp) <= goalTTL
        }
    }
    
    // Clear oldest entries if cache exceeds size limits
    func enforceSizeLimits() {
        let maxProfiles = 500 // Limit to 500 cached profiles
        let maxGoals = 1000 // Limit to 1000 cached goals
        
        if profileCache.count > maxProfiles {
            // Sort by timestamp and remove oldest
            let sorted = profileCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(profileCache.count - maxProfiles)
            for (key, _) in toRemove {
                profileCache.removeValue(forKey: key)
            }
        }
        
        if goalCache.count > maxGoals {
            // Sort by timestamp and remove oldest
            let sorted = goalCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(goalCache.count - maxGoals)
            for (key, _) in toRemove {
                goalCache.removeValue(forKey: key)
            }
        }
    }
    
    func clearAll() {
        profileCache.removeAll()
        goalCache.removeAll()
    }
}

