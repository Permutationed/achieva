-- Migration: Add avatar_url column to profiles table
-- This column stores the URL to the user's profile picture in Supabase Storage

-- Add the avatar_url column if it doesn't exist
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Add a comment for documentation
COMMENT ON COLUMN profiles.avatar_url IS 'URL to the user profile picture stored in Supabase Storage (profile-pictures bucket)';

-- Verify the column was added
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'avatar_url'
    ) THEN
        RAISE NOTICE 'SUCCESS: avatar_url column exists in profiles table';
    ELSE
        RAISE EXCEPTION 'ERROR: Failed to add avatar_url column to profiles table';
    END IF;
END $$;
