//
//  Goal.swift
//  Bucketlist
//
//  Goal model matching backend schema
//

import Foundation

enum GoalStatus: String, Codable {
    case active = "active"
    case completed = "completed"
    case archived = "archived"
}

enum GoalVisibility: String, Codable {
    case `public` = "public"
    case friends = "friends"
    case custom = "custom"
}

struct Goal: Identifiable, Codable {
    let id: UUID
    let ownerId: UUID
    let title: String
    let body: String?
    let status: GoalStatus
    let visibility: GoalVisibility
    let coverImageUrl: String?
    let createdAt: Date
    let updatedAt: Date
    var items: [GoalItem]? // Optional items array for joined queries
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case body
        case status
        case visibility
        case coverImageUrl = "cover_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case items
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encode(status, forKey: .status)
        try container.encode(visibility, forKey: .visibility)
        try container.encodeIfPresent(coverImageUrl, forKey: .coverImageUrl)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(dateFormatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(dateFormatter.string(from: updatedAt), forKey: .updatedAt)
        
        // Don't encode items - they're in a separate table
        // Only include if explicitly needed for joined queries
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerId = try container.decode(UUID.self, forKey: .ownerId)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        status = try container.decode(GoalStatus.self, forKey: .status)
        visibility = try container.decode(GoalVisibility.self, forKey: .visibility)
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        items = try container.decodeIfPresent([GoalItem].self, forKey: .items)
        
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
    }
    
    // Convenience initializer for creating new goals
    init(
        id: UUID = UUID(),
        ownerId: UUID,
        title: String,
        body: String? = nil,
        status: GoalStatus = .active,
        visibility: GoalVisibility = .public,
        coverImageUrl: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        items: [GoalItem]? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.body = body
        self.status = status
        self.visibility = visibility
        self.coverImageUrl = coverImageUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
    }
}
