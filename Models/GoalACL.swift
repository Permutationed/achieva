//
//  GoalACL.swift
//  Bucketlist
//
//  Goal ACL model matching backend schema
//

import Foundation

struct GoalACL: Identifiable, Codable {
    let id: UUID
    let goalId: UUID
    let userId: UUID
    let role: String // "viewer" or "editor"
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case userId = "user_id"
        case role
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        goalId = try container.decode(UUID.self, forKey: .goalId)
        userId = try container.decode(UUID.self, forKey: .userId)
        role = try container.decode(String.self, forKey: .role)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt),
           let date = dateFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            createdAt = Date()
        }
    }
    
    init(
        id: UUID = UUID(),
        goalId: UUID,
        userId: UUID,
        role: String = "viewer",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.goalId = goalId
        self.userId = userId
        self.role = role
        self.createdAt = createdAt
    }
}

