-- Migration: Fix Messaging RLS - Recursion-Safe Comprehensive Fix
-- 1. Helper functions (SECURITY DEFINER) to break recursion
-- 2. Fix conversations policies
-- 3. Fix conversation_participants policies
-- 4. Fix messages policies
-- 5. Diagnostic function

-- ==========================================
-- 1. HELPER FUNCTIONS
-- ==========================================

-- Function to check membership without triggering RLS recursively
CREATE OR REPLACE FUNCTION check_conversation_membership(conv_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM conversation_participants
        WHERE conversation_id = conv_id
        AND conversation_participants.user_id = check_conversation_membership.user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- 2. CONVERSATIONS
-- ==========================================

-- Drop existing policies for conversations
DROP POLICY IF EXISTS "Users can view their conversations" ON conversations;
DROP POLICY IF EXISTS "Users can create conversations" ON conversations;
DROP POLICY IF EXISTS "Users can update their conversations" ON conversations;

-- SELECT policy: Users can see conversations they are part of OR conversations they created
CREATE POLICY "Users can view their conversations"
    ON conversations FOR SELECT
    TO authenticated
    USING (
        created_by = auth.uid()
        OR check_conversation_membership(id, auth.uid())
    );

-- INSERT policy: Simple and explicit
CREATE POLICY "Users can create conversations"
    ON conversations FOR INSERT
    TO authenticated
    WITH CHECK (created_by = auth.uid());

-- UPDATE policy: Only creator can update
CREATE POLICY "Users can update their conversations"
    ON conversations FOR UPDATE
    TO authenticated
    USING (created_by = auth.uid())
    WITH CHECK (created_by = auth.uid());

-- ==========================================
-- 3. CONVERSATION_PARTICIPANTS
-- ==========================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view conversation participants" ON conversation_participants;
DROP POLICY IF EXISTS "Users can add conversation participants" ON conversation_participants;
DROP POLICY IF EXISTS "Users can update their participation" ON conversation_participants;

-- SELECT policy: Users can see participants in conversations they are part of
-- Note: Always allow users to see their own participation record
CREATE POLICY "Users can view conversation participants"
    ON conversation_participants FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR check_conversation_membership(conversation_id, auth.uid())
        OR conversation_id IN (
            SELECT id FROM conversations WHERE created_by = auth.uid()
        )
    );

-- INSERT policy: Allow adding participants if you created the conversation
CREATE POLICY "Users can add conversation participants"
    ON conversation_participants FOR INSERT
    TO authenticated
    WITH CHECK (
        conversation_id IN (
            SELECT id FROM conversations WHERE created_by = auth.uid()
        )
    );

-- UPDATE policy: Only update your own record (last_read_at)
CREATE POLICY "Users can update their participation"
    ON conversation_participants FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ==========================================
-- 4. MESSAGES
-- ==========================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view messages" ON messages;
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON messages;
DROP POLICY IF EXISTS "Users can send messages" ON messages;
DROP POLICY IF EXISTS "Users can update their messages" ON messages;
DROP POLICY IF EXISTS "Users can delete their messages" ON messages;

-- SELECT policy: Users can see messages in conversations they are part of
CREATE POLICY "Users can view messages"
    ON messages FOR SELECT
    TO authenticated
    USING (
        check_conversation_membership(conversation_id, auth.uid())
    );

-- INSERT policy: Users can send messages to conversations they are part of
CREATE POLICY "Users can send messages"
    ON messages FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND check_conversation_membership(conversation_id, auth.uid())
    );

-- ==========================================
-- 5. STORAGE POLICIES (message-media)
-- ==========================================
-- Fixes case-sensitivity issue with UUIDs by casting to UUID type

-- Drop existing storage policies
DROP POLICY IF EXISTS "Users can upload to their own message media folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own message media files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own message media files" ON storage.objects;
DROP POLICY IF EXISTS "Users can read message media from their conversations" ON storage.objects;

-- Policy: Users can upload files to their own folder
-- Path format: {userId}/{conversationId}/{messageId}.ext
CREATE POLICY "Users can upload to their own message media folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'message-media' AND
    (storage.foldername(name))[1]::uuid = auth.uid()
);

-- Policy: Users can update their own files
CREATE POLICY "Users can update their own message media files"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'message-media' AND
    (storage.foldername(name))[1]::uuid = auth.uid()
);

-- Policy: Users can delete their own files
CREATE POLICY "Users can delete their own message media files"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'message-media' AND
    (storage.foldername(name))[1]::uuid = auth.uid()
);

-- Policy: Users can read files from conversations they're part of
CREATE POLICY "Users can read message media from their conversations"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'message-media' AND
    (
        -- User can read files from their own folder
        (storage.foldername(name))[1]::uuid = auth.uid()
        OR
        -- User can read files from conversations they're part of
        -- Path format: {userId}/{conversationId}/{messageId}.ext
        check_conversation_membership((storage.foldername(name))[2]::uuid, auth.uid())
    )
);

-- ==========================================
-- 6. DIAGNOSTIC FUNCTION
-- ==========================================

CREATE OR REPLACE FUNCTION check_chat_auth()
RETURNS TABLE (
    current_uid UUID,
    auth_role TEXT,
    is_authenticated BOOLEAN,
    jwt_email TEXT
) AS $$
BEGIN
    RETURN QUERY SELECT 
        auth.uid(),
        auth.role(),
        auth.role() = 'authenticated',
        (auth.jwt() ->> 'email')::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
