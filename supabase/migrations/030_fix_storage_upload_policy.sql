-- Migration: Fix storage upload RLS policy for message-media bucket
-- This ensures authenticated users can upload media files to their own folder

-- Drop the existing upload policy
DROP POLICY IF EXISTS "Users can upload to their own message media folder" ON storage.objects;

-- Create the INSERT policy with explicit TO authenticated clause
-- Users can upload files to the message-media bucket if:
-- 1. They are authenticated (TO authenticated)
-- 2. The file is in the message-media bucket
-- 3. The first folder in the path matches their user ID (format: {userId}/{conversationId}/{fileName})
CREATE POLICY "Users can upload to their own message media folder"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'message-media' AND
        auth.uid() IS NOT NULL AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Verification query to confirm the policy was created
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage'
        AND tablename = 'objects'
        AND policyname = 'Users can upload to their own message media folder'
        AND cmd = 'INSERT'
    ) THEN
        RAISE NOTICE '✅ Storage upload policy "Users can upload to their own message media folder" created successfully';
    ELSE
        RAISE EXCEPTION '❌ Storage upload policy was not created';
    END IF;
END $$;

