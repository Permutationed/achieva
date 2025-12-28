//
//  Conversation.swift
//  Achieva
//
//  Conversation model matching backend schema
//

import Foundation

struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    let type: ConversationType
    let name: String?
    let createdBy: UUID
    let createdAt: Date
    let updatedAt: Date
    let lastMessageAt: Date?
    
    // Computed properties for UI
    var participants: [ConversationParticipant]?
    var lastMessage: Message?
    var unreadCount: Int?
    var otherParticipantProfile: Profile? // For direct conversations
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessageAt = "last_message_at"
    }
    
    init(id: UUID, type: ConversationType, name: String?, createdBy: UUID, createdAt: Date, updatedAt: Date, lastMessageAt: Date?) {
        self.id = id
        self.type = type
        self.name = name
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessageAt = lastMessageAt
        self.participants = nil
        self.lastMessage = nil
        self.unreadCount = nil
        self.otherParticipantProfile = nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ConversationType.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        createdBy = try container.decode(UUID.self, forKey: .createdBy)
        
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
        
        if let lastMessageAtString = try? container.decodeIfPresent(String.self, forKey: .lastMessageAt),
           let date = dateFormatter.date(from: lastMessageAtString) {
            lastMessageAt = date
        } else {
            lastMessageAt = nil
        }
        
        participants = nil
        lastMessage = nil
        unreadCount = nil
        otherParticipantProfile = nil
    }
    
    // Helper to get display name for conversation
    func displayName(currentUserId: UUID) -> String {
        if let conversationName = name, !conversationName.isEmpty {
            return conversationName
        }
        
        // For direct conversations, use other participant's name
        if type == .direct, let otherProfile = otherParticipantProfile {
            return otherProfile.fullName
        }
        
        return "Conversation"
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }
}

