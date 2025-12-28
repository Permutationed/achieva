//
//  MessagingService.swift
//  Achieva
//
//  Messaging service for conversations and messages
//

import Foundation
import Supabase

@MainActor
class MessagingService: ObservableObject {
    static let shared = MessagingService()
    
    private let supabaseService = SupabaseService.shared
    private var client: SupabaseClient {
        supabaseService.client
    }
    
    private init() {}
    
    // Debug logging helper
    private func writeDebugLog(_ data: [String: Any]) {
        let logPath = "/Users/joshuawang/mvp1/.cursor/debug.log"
        guard let logJson = try? JSONSerialization.data(withJSONObject: data),
              let logStr = String(data: logJson, encoding: .utf8) else { return }
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(atPath: "/Users/joshuawang/mvp1/.cursor", withIntermediateDirectories: true, attributes: nil)
        
        // Append to file
        if FileManager.default.fileExists(atPath: logPath),
           let fileHandle = FileHandle(forWritingAtPath: logPath) {
            fileHandle.seekToEndOfFile()
            fileHandle.write((logStr + "\n").data(using: .utf8)!)
            fileHandle.closeFile()
        } else {
            try? (logStr + "\n").write(toFile: logPath, atomically: false, encoding: .utf8)
        }
    }
    
    // MARK: - Helper Methods
    
    private func currentUserId() async throws -> UUID {
        let id = try await supabaseService.currentUserId()
        print("👤 MessagingService: Current user ID: \(id)")
        return id
    }
    
    /// Validates that two users are friends
    private func validateFriendship(userId1: UUID, userId2: UUID) async throws -> Bool {
        // Check if friendship exists with accepted status (either direction)
        // Check direction 1: userId1 -> userId2
        let friendships1: [Friendship] = try await client
            .from("friendships")
            .select()
            .eq("user_id_1", value: userId1)
            .eq("user_id_2", value: userId2)
            .eq("status", value: "accepted")
            .execute()
            .value
        
        if !friendships1.isEmpty {
            return true
        }
        
        // Check direction 2: userId2 -> userId1
        let friendships2: [Friendship] = try await client
            .from("friendships")
            .select()
            .eq("user_id_1", value: userId2)
            .eq("user_id_2", value: userId1)
            .eq("status", value: "accepted")
            .execute()
            .value
        
        return !friendships2.isEmpty
    }
    
    // MARK: - Conversations
    
    /// Creates a direct conversation with a friend, or returns existing one
    func createDirectConversation(with userId: UUID) async throws -> Conversation {
        let currentUserId = try await currentUserId()
        
        // Validate friendship
        guard try await validateFriendship(userId1: currentUserId, userId2: userId) else {
            throw NSError(domain: "Messaging", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only message friends"])
        }
        
        // Check if conversation already exists
        let existingParticipants: [ConversationParticipant] = try await client
            .from("conversation_participants")
            .select("id,conversation_id,user_id,joined_at,last_read_at")
            .eq("user_id", value: currentUserId)
            .execute()
            .value
        
        // Get conversation IDs for current user
        let conversationIds = Set(existingParticipants.map { $0.conversationId })
        
        if !conversationIds.isEmpty {
            // Check if any of these conversations is a direct conversation with the target user
            let values: [any PostgrestFilterValue] = Array(conversationIds).map { $0.uuidString }
            let conversations: [Conversation] = try await client
                .from("conversations")
                .select()
                .in("id", values: values)
                .eq("type", value: "direct")
                .execute()
                .value
            
            for conversation in conversations {
                // Check if this conversation has the target user as participant
                let participants: [ConversationParticipant] = try await client
                    .from("conversation_participants")
                    .select("id,conversation_id,user_id,joined_at,last_read_at")
                    .eq("conversation_id", value: conversation.id)
                    .eq("user_id", value: userId)
                    .execute()
                    .value
                
                if !participants.isEmpty {
                    // Found existing conversation
                    var existingConversation = conversation
                    existingConversation.participants = try await getParticipants(for: conversation.id)
                    return existingConversation
                }
            }
        }
        
        // Create new conversation
        struct ConversationInsert: Encodable {
            let type: String
            let created_by: UUID
        }
        
        let insert = ConversationInsert(type: "direct", created_by: currentUserId)
        
        // Verify we have a valid session and log auth state
        let session = try await client.auth.session
        print("🔐 MessagingService: Auth Debugging")
        print("   - User ID: \(session.user.id)")
        print("   - Token present: \(!session.accessToken.isEmpty)")
        print("   - Target friend: \(userId)")
        
        print("📝 Creating new conversation...")
        let newConversations: [Conversation] = try await client
            .from("conversations")
            .insert(insert)
            .select()
            .execute()
            .value
        
        if let newConv = newConversations.first {
            print("✅ Conversation created successfully: \(newConv.id)")
        } else {
            print("⚠️ Conversation insert returned empty results")
        }
        
        guard let newConversation = newConversations.first else {
            throw NSError(domain: "Messaging", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create conversation"])
        }
        
        // Add participants
        struct ParticipantInsert: Encodable {
            let conversation_id: UUID
            let user_id: UUID
        }
        
        let participantInserts = [
            ParticipantInsert(conversation_id: newConversation.id, user_id: currentUserId),
            ParticipantInsert(conversation_id: newConversation.id, user_id: userId)
        ]
        
        print("👥 Adding participants...")
        _ = try await client
            .from("conversation_participants")
            .insert(participantInserts)
            .execute()
        print("✅ Participants added successfully")
        
        // Fetch participants
        var result = newConversation
        result.participants = try await getParticipants(for: newConversation.id)
        
        return result
    }
    
    /// Creates a group conversation
    func createGroupConversation(name: String, participantIds: [UUID]) async throws -> Conversation {
        let currentUserId = try await currentUserId()
        
        // Validate all participants are friends
        for participantId in participantIds {
            guard try await validateFriendship(userId1: currentUserId, userId2: participantId) else {
                throw NSError(domain: "Messaging", code: 403, userInfo: [NSLocalizedDescriptionKey: "All participants must be friends"])
            }
        }
        
        // Create conversation
        struct ConversationInsert: Encodable {
            let type: String
            let name: String
            let created_by: UUID
        }
        
        let insert = ConversationInsert(type: "group", name: name, created_by: currentUserId)
        let newConversations: [Conversation] = try await client
            .from("conversations")
            .insert(insert)
            .select()
            .execute()
            .value
        
        guard let newConversation = newConversations.first else {
            throw NSError(domain: "Messaging", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create conversation"])
        }
        
        // Add participants (including current user)
        struct ParticipantInsert: Encodable {
            let conversation_id: UUID
            let user_id: UUID
        }
        
        var participantInserts = [ParticipantInsert(conversation_id: newConversation.id, user_id: currentUserId)]
        participantInserts.append(contentsOf: participantIds.map { ParticipantInsert(conversation_id: newConversation.id, user_id: $0) })
        
        print("👥 Adding group participants...")
        _ = try await client
            .from("conversation_participants")
            .insert(participantInserts)
            .execute()
        print("✅ Group participants added successfully")
        
        // Fetch participants
        var result = newConversation
        result.participants = try await getParticipants(for: newConversation.id)
        
        return result
    }
    
    // MARK: - Real-time Subscriptions
    
    private var pollingTasks: [UUID: Task<Void, Never>] = [:]
    private var lastMessageTimestamps: [UUID: Date] = [:]
    
    /// Subscribes to new messages in a conversation using polling
    /// Note: Using polling approach as realtime API is complex. Polls every 2 seconds.
    func subscribeToMessages(
        conversationId: UUID,
        onMessage: @escaping () async -> Void
    ) async throws {
        // Stop existing polling if any
        await unsubscribeFromMessages(conversationId: conversationId)
        
        // Store initial timestamp
        lastMessageTimestamps[conversationId] = Date()
        
        // Start polling task
        let task = Task {
            while !Task.isCancelled {
                do {
                    // Check for new messages since last check
                    let messages: [Message] = try await client
                        .from("messages")
                        .select()
                        .eq("conversation_id", value: conversationId)
                        .order("created_at", ascending: false)
                        .limit(1)
                        .execute()
                        .value
                    
                    if let latestMessage = messages.first,
                       let lastTimestamp = lastMessageTimestamps[conversationId],
                       latestMessage.createdAt > lastTimestamp {
                        // New message found
                        lastMessageTimestamps[conversationId] = latestMessage.createdAt
                        await onMessage()
                    }
                } catch {
                    // Silently handle errors - polling will retry
                    print("⚠️ Error polling messages: \(error)")
                }
                
                // Wait 2 seconds before next poll
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        
        pollingTasks[conversationId] = task
        print("✅ Started polling messages for conversation \(conversationId.uuidString)")
    }
    
    /// Unsubscribes from messages in a conversation
    func unsubscribeFromMessages(conversationId: UUID) async {
        if let task = pollingTasks[conversationId] {
            task.cancel()
            pollingTasks.removeValue(forKey: conversationId)
            lastMessageTimestamps.removeValue(forKey: conversationId)
            print("🔕 Stopped polling messages for conversation \(conversationId.uuidString)")
        }
    }
    
    // MARK: - Conversations
    
    /// Gets all conversations for the current user
    func getConversations() async throws -> [Conversation] {
        let currentUserId = try await currentUserId()
        print("🔍 MessagingService.getConversations: Fetching conversations for user \(currentUserId)")
        
        // Get conversation IDs where user is participant
        let participants: [ConversationParticipant] = try await client
            .from("conversation_participants")
            .select("id,conversation_id,user_id,joined_at,last_read_at")
            .eq("user_id", value: currentUserId)
            .execute()
            .value
        
        print("🔍 MessagingService.getConversations: Found \(participants.count) participants")
        let conversationIds = participants.map { $0.conversationId }
        guard !conversationIds.isEmpty else {
            print("🔍 MessagingService.getConversations: No conversations found")
            return []
        }
        
        print("🔍 MessagingService.getConversations: Fetching \(conversationIds.count) conversations")
        
        // Fetch conversations
        let values: [any PostgrestFilterValue] = conversationIds.map { $0.uuidString }
        var conversations: [Conversation] = try await client
            .from("conversations")
            .select("id,type,name,created_by,created_at,updated_at,last_message_at")
            .in("id", values: values)
            .order("last_message_at", ascending: false)
            .execute()
            .value
        
        print("🔍 MessagingService.getConversations: Fetched \(conversations.count) conversations")
        
        // Fetch last message for each conversation
        for index in conversations.indices {
            let conversationId = conversations[index].id
            
            // Get last message
            do {
                let messages: [Message] = try await client
                    .from("messages")
                    .select("id,conversation_id,user_id,text,message_type,media_url,created_at,updated_at,deleted_at")
                    .eq("conversation_id", value: conversationId)
                    .is("deleted_at", value: nil)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                
                conversations[index].lastMessage = messages.first
            } catch {
                print("⚠️ Warning: Failed to load last message for conversation \(conversationId): \(error)")
                // Continue even if message loading fails
            }
            
            // Get participants
            do {
                conversations[index].participants = try await getParticipants(for: conversationId)
            } catch {
                print("⚠️ Warning: Failed to load participants for conversation \(conversationId): \(error)")
                // Continue even if participant loading fails
            }
            
            // Calculate unread count
            do {
                let participant = participants.first { $0.conversationId == conversationId }
                if let lastReadAt = participant?.lastReadAt {
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let lastReadAtString = dateFormatter.string(from: lastReadAt)
                    
                    let unreadMessages: [Message] = try await client
                        .from("messages")
                        .select("id")
                        .eq("conversation_id", value: conversationId)
                        .neq("user_id", value: currentUserId)
                        .gt("created_at", value: lastReadAtString)
                        .is("deleted_at", value: nil)
                        .execute()
                        .value
                    conversations[index].unreadCount = unreadMessages.count
                } else {
                    // If never read, count all messages not from current user
                    let allMessages: [Message] = try await client
                        .from("messages")
                        .select("id")
                        .eq("conversation_id", value: conversationId)
                        .neq("user_id", value: currentUserId)
                        .is("deleted_at", value: nil)
                        .execute()
                        .value
                    conversations[index].unreadCount = allMessages.count
                }
            } catch {
                print("⚠️ Warning: Failed to calculate unread count for conversation \(conversationId): \(error)")
                conversations[index].unreadCount = 0
            }
            
            // For direct conversations, get other participant's profile
            if conversations[index].type == .direct {
                if let otherParticipant = conversations[index].participants?.first(where: { $0.userId != currentUserId }) {
                    do {
                        let profiles = try await supabaseService.getProfiles(userIds: [otherParticipant.userId])
                        conversations[index].otherParticipantProfile = profiles.first
                    } catch {
                        print("⚠️ Warning: Failed to load profile for participant \(otherParticipant.userId): \(error)")
                        // Continue even if profile loading fails
                    }
                }
            }
        }
        
        print("✅ MessagingService.getConversations: Returning \(conversations.count) conversations")
        return conversations
    }
    
    /// Gets participants for a conversation
    private func getParticipants(for conversationId: UUID) async throws -> [ConversationParticipant] {
        let participants: [ConversationParticipant] = try await client
            .from("conversation_participants")
            .select("id,conversation_id,user_id,joined_at,last_read_at")
            .eq("conversation_id", value: conversationId)
            .execute()
            .value
        
        return participants
    }
    
    // MARK: - Messages
    
    /// Sends a message to a conversation
    func sendMessage(conversationId: UUID, text: String?, mediaData: Data?, messageType: MessageType) async throws -> Message {
        // #region agent log
        writeDebugLog(["function": "sendMessage", "conversationId": conversationId.uuidString, "hasText": text != nil, "hasMedia": mediaData != nil, "messageType": messageType.rawValue, "timestamp": Date().timeIntervalSince1970])
        // #endregion
        let currentUserId = try await currentUserId()
        
        // Validate user is participant
        let participants: [ConversationParticipant] = try await client
            .from("conversation_participants")
            .select("id,conversation_id,user_id,joined_at,last_read_at")
            .eq("conversation_id", value: conversationId)
            .eq("user_id", value: currentUserId)
            .execute()
            .value
        
        guard !participants.isEmpty else {
            // #region agent log
            writeDebugLog(["function": "sendMessage", "step": "error", "error": "You are not a participant in this conversation", "timestamp": Date().timeIntervalSince1970])
            // #endregion
            throw NSError(domain: "Messaging", code: 403, userInfo: [NSLocalizedDescriptionKey: "You are not a participant in this conversation"])
        }
        
        var mediaUrl: String? = nil
        
        // Upload media if provided
        if let mediaData = mediaData {
            mediaUrl = try await uploadMedia(data: mediaData, type: messageType, conversationId: conversationId)
        }
        
        return try await sendMessage(conversationId: conversationId, text: text, messageType: messageType, mediaUrl: mediaUrl)
    }
    
    /// Internal helper to send message with direct media URL
    private func sendMessage(conversationId: UUID, text: String?, messageType: MessageType, mediaUrl: String?) async throws -> Message {
        let currentUserId = try await currentUserId()
        
        // Create message
        struct MessageInsert: Encodable {
            let conversation_id: UUID
            let user_id: UUID
            let text: String?
            let message_type: String
            let media_url: String?
        }
        
        let insert = MessageInsert(
            conversation_id: conversationId,
            user_id: currentUserId,
            text: text,
            message_type: messageType.rawValue,
            media_url: mediaUrl
        )
        
        // #region agent log
        writeDebugLog(["function": "sendMessage", "step": "before_insert", "insert": ["conversation_id": conversationId.uuidString, "user_id": currentUserId.uuidString, "hasText": text != nil, "message_type": messageType.rawValue, "hasMediaUrl": mediaUrl != nil], "timestamp": Date().timeIntervalSince1970])
        // #endregion
        
        print("✉️ Sending message to conversation: \(conversationId)")
        do {
            let newMessages: [Message] = try await client
                .from("messages")
                .insert(insert)
                .select()
                .execute()
                .value
            
            guard let newMessage = newMessages.first else {
                // #region agent log
                writeDebugLog(["function": "sendMessage", "step": "error", "error": "Failed to send message", "responseCount": newMessages.count, "timestamp": Date().timeIntervalSince1970])
                // #endregion
                throw NSError(domain: "Messaging", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to send message"])
            }
            
            // #region agent log
            writeDebugLog(["function": "sendMessage", "step": "success", "messageId": newMessage.id.uuidString, "timestamp": Date().timeIntervalSince1970])
            // #endregion
            
            print("✅ Message sent successfully: \(newMessage.id)")
            return newMessage
        } catch {
            // #region agent log
            writeDebugLog(["function": "sendMessage", "step": "error", "error": error.localizedDescription, "errorType": String(describing: type(of: error)), "timestamp": Date().timeIntervalSince1970])
            // #endregion
            throw error
        }
    }
    
    /// Gets messages for a conversation with pagination
    func getMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil) async throws -> [Message] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var query = client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId)
            .is("deleted_at", value: nil)
        
        if let before = before {
            let beforeString = dateFormatter.string(from: before)
            query = query.lt("created_at", value: beforeString)
        }
        
        var messages: [Message] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        // Reverse to get chronological order
        messages.reverse()
        
        // Load sender profiles
        let userIds = Array(Set(messages.map { $0.userId }))
        let profiles = try await supabaseService.getProfiles(userIds: userIds)
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        
        for index in messages.indices {
            messages[index].senderProfile = profileMap[messages[index].userId]
        }
        
        return messages
    }
    
    /// Marks a conversation as read
    func markAsRead(conversationId: UUID) async throws {
        let currentUserId = try await currentUserId()
        
        struct ParticipantUpdate: Encodable {
            let last_read_at: String
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let update = ParticipantUpdate(last_read_at: dateFormatter.string(from: Date()))
        
        _ = try await client
            .from("conversation_participants")
            .update(update)
            .eq("conversation_id", value: conversationId)
            .eq("user_id", value: currentUserId)
            .execute()
    }
    
    /// Uploads media to Supabase Storage
    func uploadMedia(data: Data, type: MessageType, conversationId: UUID) async throws -> String {
        let currentUserId = try await currentUserId()
        let messageId = UUID()
        
        // Determine file extension based on message type
        let fileExtension: String
        switch type {
        case .image:
            fileExtension = "jpg"
        case .video:
            fileExtension = "mp4"
        case .audio:
            fileExtension = "m4a"
        case .file:
            fileExtension = "dat"
        case .text:
            throw NSError(domain: "Messaging", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot upload media for text messages"])
        }
        
        let fileName = "\(messageId.uuidString).\(fileExtension)"
        let filePath = "\(currentUserId.uuidString)/\(conversationId.uuidString)/\(fileName)"
        
        print("📤 Uploading message media to: message-media/\(filePath)")
        
        do {
            // Upload to Supabase Storage
            _ = try await client.storage
                .from("message-media")
                .upload(
                    filePath,
                    data: data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: type == .image ? "image/jpeg" : "application/octet-stream",
                        upsert: true
                    )
                )
            
            // Get public URL
            let publicUrl = try client.storage
                .from("message-media")
                .getPublicURL(path: filePath)
            
            return publicUrl.absoluteString
        } catch {
            print("❌ Error uploading message media: \(error)")
            throw error
        }
    }
    
    // MARK: - Goal Tagging
    
    /// Tags users in a goal and creates/finds conversations for each tagged user
    func tagUsersInGoal(goalId: UUID, userIds: [UUID]) async throws {
        // #region agent log
        writeDebugLog(["function": "tagUsersInGoal", "goalId": goalId.uuidString, "userIds": userIds.map { $0.uuidString }, "timestamp": Date().timeIntervalSince1970])
        // #endregion
        let currentUserId = try await currentUserId()
        
        // Verify user owns the goal
        let goals: [Goal] = try await client
            .from("goals")
            .select()
            .eq("id", value: goalId)
            .execute()
            .value
        
        guard let goal = goals.first, goal.ownerId == currentUserId else {
            // #region agent log
            writeDebugLog(["function": "tagUsersInGoal", "step": "error", "error": "Only goal owners can tag users", "goalOwnerId": goals.first?.ownerId.uuidString ?? "nil", "currentUserId": currentUserId.uuidString, "timestamp": Date().timeIntervalSince1970])
            // #endregion
            throw NSError(domain: "MessagingService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only goal owners can tag users"])
        }
        
        // For each tagged user, create or find a direct conversation and create a tag
        for taggedUserId in userIds {
            // Skip if trying to tag self
            guard taggedUserId != currentUserId else { continue }
            
            // #region agent log
            writeDebugLog(["function": "tagUsersInGoal", "step": "tagging_user", "taggedUserId": taggedUserId.uuidString, "timestamp": Date().timeIntervalSince1970])
            // #endregion
            
            // Find or create a direct conversation between goal owner and tagged user
            let conversation = try await createDirectConversation(with: taggedUserId)
            
            // Create goal tag entry
            let tag = GoalTag(
                goalId: goalId,
                userId: taggedUserId,
                conversationId: conversation.id
            )
            
            struct GoalTagInsert: Encodable {
                let goal_id: UUID
                let user_id: UUID
                let conversation_id: UUID?
            }
            
            let tagInsert = GoalTagInsert(
                goal_id: tag.goalId,
                user_id: tag.userId,
                conversation_id: tag.conversationId
            )
            
            // #region agent log
            writeDebugLog(["function": "tagUsersInGoal", "step": "before_insert", "tagInsert": ["goal_id": tag.goalId.uuidString, "user_id": tag.userId.uuidString, "conversation_id": tag.conversationId?.uuidString ?? "nil"], "timestamp": Date().timeIntervalSince1970])
            // #endregion
            
            do {
                try await client
                    .from("goal_tags")
                    .insert(tagInsert)
                    .execute()
                
                // #region agent log
                writeDebugLog(["function": "tagUsersInGoal", "step": "tag_inserted", "taggedUserId": taggedUserId.uuidString, "timestamp": Date().timeIntervalSince1970])
                // #endregion
            } catch {
                // #region agent log
                writeDebugLog(["function": "tagUsersInGoal", "step": "error", "error": error.localizedDescription, "errorType": String(describing: type(of: error)), "taggedUserId": taggedUserId.uuidString, "timestamp": Date().timeIntervalSince1970])
                // #endregion
                throw error
            }
        }
        
        // #region agent log
        writeDebugLog(["function": "tagUsersInGoal", "step": "success", "taggedCount": userIds.count, "timestamp": Date().timeIntervalSince1970])
        // #endregion
    }
}

