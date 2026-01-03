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
            // Clear cached user ID on any auth state change to ensure fresh data
            supabaseService.clearUserCache()
            
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
            
            // If profile doesn't exist, wait a bit and retry (for OAuth users, trigger might be delayed)
            if self.profile == nil {
                // Wait 500ms for database trigger to create profile
                try? await Task.sleep(nanoseconds: 500_000_000)
                await loadProfile(userId: userId)
            }
            
            // If profile still doesn't exist, create it manually (fallback if trigger fails)
            if self.profile == nil {
                print("⚠️ Profile not found for user \(userId), creating default profile...")
                await createDefaultProfile(userId: userId)
                await loadProfile(userId: userId)
            }
            
            // Check if this is a new user (profile has default values)
            if let profile = self.profile {
                // Determine if user needs onboarding:
                // - Default first name is "User"
                // - Default date of birth is 2000-01-01
                // - Last name is empty
                let hasDefaultValues = profile.firstName == "User" && 
                                     profile.lastName.isEmpty &&
                                     Calendar.current.dateComponents([.year], from: profile.dateOfBirth).year == 2000
                
                if hasDefaultValues {
                    // This is a new user who needs to complete onboarding
                    await MainActor.run {
                        self.isNewSignUp = true
                    }
                } else {
                    // Existing user with completed profile
                    await MainActor.run {
                        self.isNewSignUp = false
                    }
                }
            } else {
                // Profile still doesn't exist after all attempts - treat as new signup
                print("⚠️ Warning: Could not create profile for user \(userId), treating as new signup")
                await MainActor.run {
                    self.isNewSignUp = true
                }
            }
        } else {
            self.profile = nil
        }
    }
    
    // MARK: - Profile Management
    
    /// Creates a default profile for a user (fallback if database trigger fails)
    private func createDefaultProfile(userId: UUID) async {
        do {
            // Generate a unique username based on user ID
            let usernameBase = userId.uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(8)
            var username = String(usernameBase)
            var counter = 0
            
            // Ensure username is unique
            while true {
                let existing: [Profile] = try await supabaseService.client
                    .from("profiles")
                    .select("id")
                    .eq("username", value: username)
                    .execute()
                    .value
                
                if existing.isEmpty {
                    break
                }
                counter += 1
                username = String(usernameBase) + String(counter)
            }
            
            // Create profile with default values
            let newProfile = Profile(
                id: userId,
                username: username,
                firstName: "User",
                lastName: "",
                dateOfBirth: Date(timeIntervalSince1970: 946684800), // 2000-01-01
                createdAt: Date(),
                updatedAt: Date(),
                avatarUrl: nil
            )
            
            try await supabaseService.client
                .from("profiles")
                .insert(newProfile)
                .execute()
            
            print("✅ Created default profile for user \(userId) with username \(username)")
        } catch {
            print("❌ Failed to create default profile: \(error.localizedDescription)")
        }
    }
    
    func loadProfile(userId: UUID) async {
        do {
            let response: [Profile] = try await supabaseService.client
                .from("profiles")
                .select("id,username,first_name,last_name,date_of_birth,avatar_url,created_at,updated_at")
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
        
        // Use explicit update if profile already exists, otherwise insert
        // This is more reliable for RLS than upsert in some cases
        do {
            if self.profile != nil {
                // Update existing profile
                struct ProfileUpdate: Encodable {
                    let username: String
                    let first_name: String
                    let last_name: String
                    let date_of_birth: String
                    let avatar_url: String?
                    let updated_at: Date
                }
                
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withFullDate]
                let dobString = dateFormatter.string(from: dateOfBirth)
                
                let update = ProfileUpdate(
                    username: username,
                    first_name: firstName,
                    last_name: lastName,
                    date_of_birth: dobString,
                    avatar_url: avatarUrl,
                    updated_at: Date()
                )
                
                try await supabaseService.client
                    .from("profiles")
                    .update(update)
                    .eq("id", value: userId)
                    .execute()
            } else {
                // Insert new profile
                let newProfile = Profile(
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
                    .insert(newProfile)
                    .execute()
            }
        } catch {
            // Check if error is due to username uniqueness constraint
            if let postgrestError = error as? PostgrestError,
               let errorCode = postgrestError.code,
               errorCode == "23505" { // PostgreSQL unique violation
                throw AuthError.usernameTaken
            }
            
            // Re-throw other errors
            print("❌ Upsert failed: \(error)")
            throw error
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
            
            // Don't set isNewSignUp here - let updateSession determine it based on profile
            // This allows us to detect new OAuth users who need onboarding
            
            _ = try await supabaseService.client.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: redirectURL
            )
            
            // Session will be updated automatically via auth state observer
            // updateSession will check if profile has default values to determine if it's a new signup
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
            // Don't set isNewSignUp here - let updateSession determine it based on profile
            // This allows us to detect new OAuth users who need onboarding
            
            // Supabase Swift SDK handles OAuth flow internally
            // The session will be updated via auth state observer
            _ = try await supabaseService.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "io.achieva.app://auth-callback")!
            )
            
            // Session will be updated automatically via auth state observer
            // updateSession will check if profile has default values to determine if it's a new signup
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Supabase will send a password reset email
            // The redirectTo URL is where users will be sent after clicking the reset link
            try await supabaseService.client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "io.achieva.app://auth-callback?type=recovery")!
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Updates the user's password (used after clicking reset link)
    func updatePassword(newPassword: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            var attributes = Auth.UserAttributes()
            attributes.password = newPassword
            try await supabaseService.client.auth.update(user: attributes)
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
            // Clear cached user ID before signing out
            supabaseService.clearUserCache()
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

