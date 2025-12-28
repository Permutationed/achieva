//
//  Message.swift
//  Achieva
//
//  Message model matching backend schema
//

import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let conversationId: UUID
    let userId: UUID
    let text: String?
    let messageType: MessageType
    let mediaUrl: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    
    // Computed properties for UI
    var senderProfile: Profile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case text
        case messageType = "message_type"
        case mediaUrl = "media_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
    
    init(id: UUID, conversationId: UUID, userId: UUID, text: String?, messageType: MessageType, mediaUrl: String?, createdAt: Date, updatedAt: Date, deletedAt: Date?) {
        self.id = id
        self.conversationId = conversationId
        self.userId = userId
        self.text = text
        self.messageType = messageType
        self.mediaUrl = mediaUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.senderProfile = nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        conversationId = try container.decode(UUID.self, forKey: .conversationId)
        userId = try container.decode(UUID.self, forKey: .userId)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        messageType = try container.decode(MessageType.self, forKey: .messageType)
        mediaUrl = try container.decodeIfPresent(String.self, forKey: .mediaUrl)
        
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
        
        if let deletedAtString = try? container.decodeIfPresent(String.self, forKey: .deletedAt),
           let date = dateFormatter.date(from: deletedAtString) {
            deletedAt = date
        } else {
            deletedAt = nil
        }
        
        senderProfile = nil
    }
}

