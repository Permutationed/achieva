//
//  AuthStore.swift
//  Bucketlist
//
//  Authentication state management using Supabase Auth
//

import Foundation
import Supabase
import SwiftUI
import AuthenticationServices

@MainActor
class AuthStore: ObservableObject {
    static let shared = AuthStore()
    
    @Published var session: Session?
    @Published var userId: UUID?
    @Published var isAuthenticated: Bool = false
    @Published var profile: Profile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    
    private init() {
        // Load initial session
        Task {
            await loadInitialSession()
            await startAuthStateObserver()
        }
    }
    
    // MARK: - Auth State Observation
    
    func observeAuthState() async {
        await loadInitialSession()
    }
    
    private func loadInitialSession() async {
        // Get initial session
        do {
            let session = try await supabaseService.client.auth.session
            await updateSession(session)
        } catch {
            print("No initial session: \(error.localizedDescription)")
            await updateSession(nil)
        }
    }
    
    private func startAuthStateObserver() async {
        // Listen for auth state changes
        for await (event, session) in await supabaseService.client.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .signedOut, .tokenRefreshed, .userUpdated:
                await updateSession(session)
            case .passwordRecovery:
                // Handle password recovery if needed
                break
            @unknown default:
                // Handle any future event types
                await updateSession(session)
            }
        }
    }
    
    private func updateSession(_ session: Session?) async {
        self.session = session
        self.userId = session?.user.id
        self.isAuthenticated = session != nil
        
        // Load profile if authenticated
        if let userId = userId {
            await loadProfile(userId: userId)
        } else {
            self.profile = nil
        }
    }
    
    // MARK: - Profile Management
    
    func loadProfile(userId: UUID) async {
        do {
            let response: [Profile] = try await supabaseService.client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = response.first {
                self.profile = profile
            } else {
                self.profile = nil
            }
        } catch {
            print("Error loading profile: \(error.localizedDescription)")
            self.profile = nil
        }
    }
    
    func createOrUpdateProfile(username: String, displayName: String, dateOfBirth: Date?) async throws {
        guard let userId = userId else {
            throw AuthError.notAuthenticated
        }
        
        // Create update payload with only the fields we want to update
        struct UpdateProfilePayload: Encodable {
            let username: String
            let display_name: String
            let date_of_birth: String?
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateOfBirthString = dateOfBirth.map { dateFormatter.string(from: $0) }
        
        let payload = UpdateProfilePayload(
            username: username,
            display_name: displayName,
            date_of_birth: dateOfBirthString
        )
        
        // Try to insert, if conflict (already exists), update instead
        do {
            // For insert, we need the full profile structure
            let profile = Profile(
                id: userId,
                username: username,
                displayName: displayName,
                dateOfBirth: dateOfBirth,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await supabaseService.client
                .from("profiles")
                .insert(profile)
                .execute()
        } catch {
            // If profile exists, update it with only the fields we want to change
            try await supabaseService.client
                .from("profiles")
                .update(payload)
                .eq("id", value: userId)
                .execute()
        }
        
        await loadProfile(userId: userId)
    }
    
    // MARK: - Email/Password Auth
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let response = try await supabaseService.client.auth.signUp(
                email: email,
                password: password
            )
            
            await updateSession(response.session)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let session = try await supabaseService.client.auth.signIn(
                email: email,
                password: password
            )
            
            await updateSession(session)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - OAuth Auth
    
    func signInWithApple() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Supabase Swift SDK handles OAuth flow internally
            // The session will be updated via auth state observer
            _ = try await supabaseService.client.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: URL(string: "com.bucketlist.app://auth-callback")!
            )
            
            // Session will be updated automatically via auth state observer
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Supabase Swift SDK handles OAuth flow internally
            // The session will be updated via auth state observer
            _ = try await supabaseService.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "com.bucketlist.app://auth-callback")!
            )
            
            // Session will be updated automatically via auth state observer
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await supabaseService.client.auth.signOut()
            await updateSession(nil)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// MARK: - Profile Model

struct Profile: Identifiable, Codable {
    let id: UUID
    let username: String
    let displayName: String
    let dateOfBirth: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case dateOfBirth = "date_of_birth"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        
        // Handle optional date_of_birth
        if let dateString = try? container.decode(String.self, forKey: .dateOfBirth) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            dateOfBirth = formatter.date(from: dateString)
        } else {
            dateOfBirth = nil
        }
        
        // Handle timestamps
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt),
           let date = dateFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            createdAt = Date()
        }
        
        if let updatedAtString = try? container.decode(String.self, forKey: .updatedAt),
           let date = dateFormatter.date(from: updatedAtString) {
            updatedAt = date
        } else {
            updatedAt = Date()
        }
    }
    
    init(id: UUID, username: String, displayName: String, dateOfBirth: Date?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.dateOfBirth = dateOfBirth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case profileNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidCredentials:
            return "Invalid email or password"
        case .profileNotFound:
            return "Profile not found"
        }
    }
}

