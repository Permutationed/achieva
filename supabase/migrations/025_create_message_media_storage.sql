-- Migration: Create message-media storage bucket and RLS policies
-- This creates the storage bucket for message media files

-- Note: Storage buckets are created via the Supabase Dashboard or Storage API
-- This migration creates the bucket policies after the bucket is created manually

-- Step 1: Create the bucket (run this in Supabase Dashboard → Storage → New Bucket)
-- Bucket name: message-media
-- Public bucket: Yes (so media URLs can be accessed)

-- Step 2: Set up storage policies (run these after bucket is created)
-- Note: Drop existing policies first to allow re-running this migration

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can upload to their own message media folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own message media files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own message media files" ON storage.objects;
DROP POLICY IF EXISTS "Users can read message media from their conversations" ON storage.objects;

-- Policy: Users can upload files to their own folder
CREATE POLICY "Users can upload to their own message media folder"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'message-media' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can update their own files
CREATE POLICY "Users can update their own message media files"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'message-media' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can delete their own files
CREATE POLICY "Users can delete their own message media files"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'message-media' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can read files from conversations they're part of
-- This checks if the user is a participant in the conversation
CREATE POLICY "Users can read message media from their conversations"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'message-media' AND
    (
        -- User can read files from their own folder (they uploaded)
        (storage.foldername(name))[1] = auth.uid()::text
        OR
        -- User can read files from conversations they're part of
        -- Extract conversation ID from path: {userId}/{conversationId}/{messageId}.ext
        (storage.foldername(name))[2]::uuid IN (
            SELECT conversation_id FROM conversation_participants
            WHERE user_id = auth.uid()
        )
    )
);

-- Alternative: Simple public bucket (uncomment if you want public access)
-- CREATE POLICY "Anyone can read message media files"
-- ON storage.objects FOR SELECT
-- USING (bucket_id = 'message-media');

-- Note: For stricter access control:
-- 1. Keep the conversation-based policy above (recommended)
-- 2. Or make bucket private and use signed URLs
-- 3. The conversation-based policy ensures only participants can view media

