//
//  MessageType.swift
//  Achieva
//
//  Message type enum matching backend schema
//

import Foundation

enum MessageType: String, Codable {
    case text = "text"
    case image = "image"
    case video = "video"
    case audio = "audio"
    case file = "file"
    
    // Legacy message types from collaborative goals system (removed)
    // These are mapped to 'text' for backward compatibility
    static let legacyTypes: [String: MessageType] = [
        "goal_proposal": .text,
        "goal_event": .text,
        "goal_publish_proposal": .text
    ]
    
    // Handle legacy message types from old collaborative goals system
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // Check if it's a legacy type and map it
        if let legacyType = MessageType.legacyTypes[rawValue] {
            self = legacyType
        } else if let messageType = MessageType(rawValue: rawValue) {
            self = messageType
        } else {
            // Unknown type - default to text for backward compatibility
            print("⚠️ Unknown message type '\(rawValue)', defaulting to 'text'")
            self = .text
        }
    }
}

