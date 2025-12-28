//
//  AuthStore.swift
//  Achieva
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
    @Published var isInitialLoadComplete = false // Track if initial session load is complete
    @Published var isNewSignUp = false // Track if user just signed up (not signed in)
    
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
        // Mock Mode Support
        if ProcessInfo.processInfo.arguments.contains("-useMockData") {
            await MainActor.run {
                isLoading = true
                isInitialLoadComplete = false
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // Simulate generic load
            
            await MainActor.run {
                self.isAuthenticated = true
                self.userId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")
                self.profile = Profile(
                    id: self.userId!,
                    username: "mockuser",
                    firstName: "Mock",
                    lastName: "User",
                    dateOfBirth: Date(),
                    createdAt: Date(),
                    updatedAt: Date()
                )
                self.isLoading = false
                self.isInitialLoadComplete = true
            }
            return
        }
        
        // Set loading state to prevent auth flash
        await MainActor.run {
            isLoading = true
            isInitialLoadComplete = false
            // When loading initial session, assume not a new signup (existing user returning)
            self.isNewSignUp = false
        }
        
        // Get initial session
        do {
            let session = try await supabaseService.client.auth.session
            await updateSession(session)
        } catch {
            print("No initial session: \(error.localizedDescription)")
            await updateSession(nil)
        }
        
        // Mark initial load as complete
        await MainActor.run {
            isLoading = false
            isInitialLoadComplete = true
        }
    }
    
    private func startAuthStateObserver() async {
        // Mock Mode Support
        if ProcessInfo.processInfo.arguments.contains("-useMockData") {
            return
        }
        
        // Listen for auth state changes
        for await (event, session) in supabaseService.client.auth.authStateChanges {
            switch event {
            case .initialSession:
                await updateSession(session)
            case .signedIn:
                await updateSession(session)
            case .signedOut:
                await updateSession(session)
            case .tokenRefreshed:
                await updateSession(session)
            case .userUpdated:
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
        
        // If signing out, reset new signup flag
        if session == nil {
            await MainActor.run {
                self.isNewSignUp = false
            }
        }
        
        // Load profile if authenticated (blocking to ensure onboarding decision is correct)
        if let userId = userId {
            await loadProfile(userId: userId)
            
            // If profile exists after loading, user is not new (clear the flag)
            if self.profile != nil {
                await MainActor.run {
                    self.isNewSignUp = false
                }
            }
        } else {
            self.profile = nil
        }
    }
    
    // MARK: - Profile Management
    
    func loadProfile(userId: UUID) async {
        do {
            let response: [Profile] = try await supabaseService.client
                .from("profiles")
                .select("id,username,first_name,last_name,date_of_birth,created_at,updated_at")
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
    
    func createOrUpdateProfile(username: String, firstName: String, lastName: String, dateOfBirth: Date, avatarUrl: String? = nil) async throws {
        guard let userId = userId else {
            throw AuthError.notAuthenticated
        }
        
        // Check if username is already taken by another user
        do {
            let existingProfiles: [Profile] = try await supabaseService.client
                .from("profiles")
                .select("id,username")
                .eq("username", value: username)
                .execute()
                .value
            
            // If username exists and belongs to a different user, throw error
            if let existingProfile = existingProfiles.first, existingProfile.id != userId {
                throw AuthError.usernameTaken
            }
        } catch let error as AuthError {
            // Re-throw AuthError as-is
            throw error
        } catch {
            // If query fails for other reasons, log but continue (database constraint will catch it)
            print("Warning: Could not check username availability: \(error.localizedDescription)")
        }
        
        // Create update payload
        struct UpdateProfilePayload: Encodable {
            let username: String
            let first_name: String
            let last_name: String
            let date_of_birth: String
            let avatar_url: String?
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateOfBirthString = dateFormatter.string(from: dateOfBirth)
        
        let payload = UpdateProfilePayload(
            username: username,
            first_name: firstName,
            last_name: lastName,
            date_of_birth: dateOfBirthString,
            avatar_url: avatarUrl
        )
        
        // Try to insert, if conflict (already exists), update instead
        do {
            // For insert, we need the full profile structure
            let profile = Profile(
                id: userId,
                username: username,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth,
                createdAt: Date(),
                updatedAt: Date(),
                avatarUrl: avatarUrl
            )
            try await supabaseService.client
                .from("profiles")
                .insert(profile)
                .execute()
        } catch {
            // Check if error is due to username uniqueness constraint
            if let postgrestError = error as? PostgrestError,
               let errorCode = postgrestError.code,
               errorCode == "23505" { // PostgreSQL unique violation
                throw AuthError.usernameTaken
            }
            
            // If profile exists (different error), try to update it
            do {
                try await supabaseService.client
                    .from("profiles")
                    .update(payload)
                    .eq("id", value: userId)
                    .execute()
            } catch let updateError {
                // Check if update error is also a username uniqueness constraint
                if let postgrestError = updateError as? PostgrestError,
                   let errorCode = postgrestError.code,
                   errorCode == "23505" {
                    throw AuthError.usernameTaken
                }
                // Re-throw the update error
                throw updateError
            }
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
            
            // Mark as new signup so onboarding will be shown
            await MainActor.run {
                self.isNewSignUp = true
            }
            
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
            
            // Mark as existing user (not new signup) so onboarding won't be shown
            await MainActor.run {
                self.isNewSignUp = false
            }
            
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
            // Use custom URL scheme for native iOS app
            // IMPORTANT: Make sure this exact URL is added in:
            // Supabase Dashboard → Authentication → URL Configuration → Redirect URLs
            // If you see localhost redirects, verify the URL is saved in Supabase dashboard
            let redirectURL = URL(string: "io.achieva.app://auth-callback")!
            
            // OAuth sign in is treated as existing user sign in (not new signup)
            await MainActor.run {
                self.isNewSignUp = false
            }
            
            _ = try await supabaseService.client.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: redirectURL
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
            // OAuth sign in is treated as existing user sign in (not new signup)
            await MainActor.run {
                self.isNewSignUp = false
            }
            
            // Supabase Swift SDK handles OAuth flow internally
            // The session will be updated via auth state observer
            _ = try await supabaseService.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "io.achieva.app://auth-callback")!
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
    let firstName: String
    let lastName: String
    let dateOfBirth: Date
    let createdAt: Date
    let updatedAt: Date
    let avatarUrl: String?
    
    // Computed property for full name display
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "date_of_birth"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case avatarUrl = "avatar_url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        
        // Handle date_of_birth (now required, but decode safely)
        if let dateString = try? container.decode(String.self, forKey: .dateOfBirth) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            if let date = formatter.date(from: dateString) {
                dateOfBirth = date
            } else {
                // Fallback to default date if parsing fails
                dateOfBirth = Date()
            }
        } else {
            // Fallback to current date if missing (shouldn't happen after migration)
            dateOfBirth = Date()
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
        
        // Handle avatar_url (optional)
        avatarUrl = try? container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }
    
    init(id: UUID, username: String, firstName: String, lastName: String, dateOfBirth: Date, createdAt: Date, updatedAt: Date, avatarUrl: String? = nil) {
        self.id = id
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.avatarUrl = avatarUrl
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case profileNotFound
    case usernameTaken
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidCredentials:
            return "Invalid email or password"
        case .profileNotFound:
            return "Profile not found"
        case .usernameTaken:
            return "This username is already taken. Please choose another."
        }
    }
}

