//
//  GoalTag.swift
//  Achieva
//
//  Goal tag model for tagging friends in goals
//

import Foundation

struct GoalTag: Identifiable, Codable {
    let id: UUID
    let goalId: UUID
    let userId: UUID
    let conversationId: UUID?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case userId = "user_id"
        case conversationId = "conversation_id"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        goalId = try container.decode(UUID.self, forKey: .goalId)
        userId = try container.decode(UUID.self, forKey: .userId)
        conversationId = try container.decodeIfPresent(UUID.self, forKey: .conversationId)
        
        // Handle date decoding with ISO8601 format
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
        conversationId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.goalId = goalId
        self.userId = userId
        self.conversationId = conversationId
        self.createdAt = createdAt
    }
}

// MARK: - Notification Model

enum NotificationType: String, Codable {
    case message = "message"
    case goalTag = "goal_tag"
    case friendRequest = "friend_request"
}

struct AppNotification: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let type: NotificationType
    let title: String
    let body: String?
    let relatedId: UUID?
    let readAt: Date?
    let createdAt: Date
    
    // Computed properties
    var isRead: Bool {
        readAt != nil
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case body
        case relatedId = "related_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        type = try container.decode(NotificationType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        relatedId = try container.decodeIfPresent(UUID.self, forKey: .relatedId)
        
        // Handle date decoding
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let readAtString = try? container.decodeIfPresent(String.self, forKey: .readAt),
           let date = readAtString.isEmpty ? nil : dateFormatter.date(from: readAtString) {
            readAt = date
        } else {
            readAt = nil
        }
        
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt),
           let date = dateFormatter.date(from: createdAtString) {
            createdAt = date
        } else {
            createdAt = Date()
        }
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        type: NotificationType,
        title: String,
        body: String? = nil,
        relatedId: UUID? = nil,
        readAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.body = body
        self.relatedId = relatedId
        self.readAt = readAt
        self.createdAt = createdAt
    }
}








