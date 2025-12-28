-- Migration: Cleanup legacy message types
-- This migration is optional - the Swift decoder handles legacy types gracefully
-- by mapping them to 'text'. This migration can be run to clean up old messages
-- if desired, but it's not required for the app to function.

-- Optional: Update legacy message types to 'text'
-- Uncomment the following if you want to clean up old messages:

-- UPDATE messages
-- SET message_type = 'text'
-- WHERE message_type IN ('goal_proposal', 'goal_event', 'goal_publish_proposal');

-- Note: The Swift decoder in Models/MessageType.swift already handles these
-- legacy types by mapping them to 'text' during decoding, so this migration
-- is optional and only needed if you want to clean up the database.


