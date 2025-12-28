//
//  GoalComment.swift
//  Achieva
//
//  Goal comment model matching backend schema
//

import Foundation

struct GoalComment: Identifiable, Codable {
    let id: UUID
    let goalId: UUID
    let userId: UUID
    let content: String
    let createdAt: Date
    let updatedAt: Date
    
    // Optional: Author profile for joined queries
    var authorProfile: Profile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorProfile
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        goalId = try container.decode(UUID.self, forKey: .goalId)
        userId = try container.decode(UUID.self, forKey: .userId)
        content = try container.decode(String.self, forKey: .content)
        
        // Handle date decoding with ISO8601 format
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
        
        // Decode author profile if present (from joined queries)
        authorProfile = try? container.decodeIfPresent(Profile.self, forKey: .authorProfile)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(goalId, forKey: .goalId)
        try container.encode(userId, forKey: .userId)
        try container.encode(content, forKey: .content)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(dateFormatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(dateFormatter.string(from: updatedAt), forKey: .updatedAt)
        
        // Don't encode authorProfile - it's only for reading
    }
    
    init(
        id: UUID = UUID(),
        goalId: UUID,
        userId: UUID,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        authorProfile: Profile? = nil
    ) {
        self.id = id
        self.goalId = goalId
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorProfile = authorProfile
    }
}



