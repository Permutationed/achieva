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
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: key)
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
}

