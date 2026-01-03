-- Migration: Create notifications table
-- Stores in-app notifications for messages, goal tags, and friend requests

-- Create notification type enum
CREATE TYPE notification_type AS ENUM ('message', 'goal_tag', 'friend_request');

-- Create notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    related_id UUID, -- message_id, goal_id, conversation_id, etc.
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read_at ON notifications(read_at) WHERE read_at IS NULL;
CREATE INDEX idx_notifications_created_at ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_type ON notifications(user_id, type, created_at DESC);

-- Enable Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- SELECT: Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
    ON notifications FOR SELECT
    USING (user_id = auth.uid());

-- INSERT: System can create notifications (handled by triggers)
-- Note: We'll use SECURITY DEFINER functions for inserts from triggers

-- UPDATE: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update their own notifications"
    ON notifications FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- DELETE: Users can delete their own notifications
CREATE POLICY "Users can delete their own notifications"
    ON notifications FOR DELETE
    USING (user_id = auth.uid());

-- Function to create a notification (used by triggers)
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id UUID,
    p_type notification_type,
    p_title TEXT,
    p_body TEXT DEFAULT NULL,
    p_related_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO notifications (user_id, type, title, body, related_id)
    VALUES (p_user_id, p_type, p_title, p_body, p_related_id)
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION create_notification(UUID, notification_type, TEXT, TEXT, UUID) TO authenticated;
