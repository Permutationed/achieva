-- Migration: Fix infinite recursion in conversation_participants RLS policies
-- The SELECT policy was causing recursion by checking the same table it protects

-- Create a SECURITY DEFINER function to check participation without RLS recursion
CREATE OR REPLACE FUNCTION is_conversation_participant(check_conversation_id UUID, check_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM conversation_participants
        WHERE conversation_id = check_conversation_id
        AND user_id = check_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the problematic policies
DROP POLICY IF EXISTS "Users can view conversation participants" ON conversation_participants;
DROP POLICY IF EXISTS "Users can add conversation participants" ON conversation_participants;

-- Create a new SELECT policy that avoids recursion using the function
CREATE POLICY "Users can view conversation participants"
    ON conversation_participants FOR SELECT
    USING (
        -- User can see their own participant record
        user_id = auth.uid()
        OR
        -- User can see other participants if they're a participant in the same conversation
        -- Using SECURITY DEFINER function to avoid RLS recursion
        is_conversation_participant(conversation_id, auth.uid())
    );

-- Users can insert participants if:
-- 1. They're adding themselves (user_id = auth.uid())
-- 2. They created the conversation (created_by = auth.uid())
CREATE POLICY "Users can add conversation participants"
    ON conversation_participants FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        OR
        EXISTS (
            SELECT 1 FROM conversations
            WHERE conversations.id = conversation_participants.conversation_id
            AND conversations.created_by = auth.uid()
        )
    );

