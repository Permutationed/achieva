//
//  Friendship.swift
//  Achieva
//
//  Friendship model matching backend schema
//

import Foundation

enum FriendshipStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case blocked = "blocked"
}

struct Friendship: Identifiable, Codable {
    let id: UUID
    let userId1: UUID
    let userId2: UUID
    let status: FriendshipStatus
    let establishedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId1 = "user_id_1"
        case userId2 = "user_id_2"
        case status
        case establishedAt = "established_at"
        case createdAt = "created_at"
    }
    
    init(id: UUID, userId1: UUID, userId2: UUID, status: FriendshipStatus, establishedAt: Date?, createdAt: Date) {
        self.id = id
        self.userId1 = userId1
        self.userId2 = userId2
        self.status = status
        self.establishedAt = establishedAt
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId1 = try container.decode(UUID.self, forKey: .userId1)
        userId2 = try container.decode(UUID.self, forKey: .userId2)
        status = try container.decode(FriendshipStatus.self, forKey: .status)
        
        // Handle optional established_at
        if let establishedAtString = try? container.decode(String.self, forKey: .establishedAt) {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            establishedAt = dateFormatter.date(from: establishedAtString)
        } else {
            establishedAt = nil
        }
        
        // Handle createdAt
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt),
           let date = dateFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            createdAt = Date()
        }
    }
}

// Helper struct to combine profile with friendship status
struct UserWithFriendshipStatus: Identifiable {
    let profile: Profile
    let friendshipStatus: FriendshipStatus?
    let friendshipId: UUID?
    let isIncomingRequest: Bool // true if this user sent the request to current user
    
    var id: UUID { profile.id }
}


