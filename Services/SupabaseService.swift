//
//  SupabaseService.swift
//  Bucketlist
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
    
    private var cachedUserId: UUID?
    
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
        
        // Debug output
        if url.isEmpty || key.isEmpty {
            print("⚠️ Supabase credentials not found!")
            print("   Looking for SUPABASE_URL and SUPABASE_ANON_KEY")
            print("   Checked environment variables and .env file")
            print("   Current directory: \(FileManager.default.currentDirectoryPath)")
            fatalError("Supabase credentials not found. Please set SUPABASE_URL and SUPABASE_ANON_KEY in .env file (at /Users/joshuawang/mvp1/.env) or environment variables.")
        }
        
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
    func uploadGoalCoverImage(goalId: UUID, imageData: Data) async throws -> String {
        let fileName = "cover.jpg"
        let filePath = "\(goalId.uuidString)/\(fileName)"
        
        print("📤 Uploading image to: goal-covers/\(filePath)")
        
        do {
            // Upload to Supabase Storage
            let response = try await client.storage
                .from("goal-covers")
                .upload(
                    path: filePath,
                    file: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true // Allow replacing existing image
                    )
                )
            
            // Get public URL
            let publicURL = try client.storage
                .from("goal-covers")
                .getPublicURL(path: filePath)
            
            print("✅ Image uploaded successfully: \(publicURL)")
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
}

