//
//  ConversationParticipant.swift
//  Achieva
//
//  Conversation participant model matching backend schema
//

import Foundation

struct ConversationParticipant: Identifiable, Codable {
    let id: UUID
    let conversationId: UUID
    let userId: UUID
    let joinedAt: Date
    let lastReadAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case lastReadAt = "last_read_at"
    }
    
    init(id: UUID, conversationId: UUID, userId: UUID, joinedAt: Date, lastReadAt: Date?) {
        self.id = id
        self.conversationId = conversationId
        self.userId = userId
        self.joinedAt = joinedAt
        self.lastReadAt = lastReadAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        conversationId = try container.decode(UUID.self, forKey: .conversationId)
        userId = try container.decode(UUID.self, forKey: .userId)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let joinedAtString = try? container.decode(String.self, forKey: .joinedAt),
           let date = dateFormatter.date(from: joinedAtString) {
            joinedAt = date
        } else {
            joinedAt = Date()
        }
        
        if let lastReadAtString = try? container.decode(String.self, forKey: .lastReadAt),
           let date = dateFormatter.date(from: lastReadAtString) {
            lastReadAt = date
        } else {
            lastReadAt = nil
        }
    }
}








