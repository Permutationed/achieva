-- Migration: Fix Profile Picture Permissions
-- This migration uses a simpler, more permissive approach for profile picture uploads
-- Since profile pictures are public anyway, we can allow authenticated users full access

-- ============================================
-- STEP 1: Ensure the storage bucket exists and is configured correctly
-- ============================================

-- Create the bucket if it doesn't exist, or update it to be public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'profile-pictures', 
    'profile-pictures', 
    true,  -- Public bucket (anyone can view)
    5242880,  -- 5MB limit
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

-- ============================================
-- STEP 2: Remove ALL existing policies for profile-pictures bucket
-- ============================================

-- Drop any policies that might exist (using DO block to handle if they don't exist)
DO $$ 
BEGIN
    -- Try to drop each policy, ignore errors if they don't exist
    DROP POLICY IF EXISTS "Users can upload their own profile picture" ON storage.objects;
    DROP POLICY IF EXISTS "Users can update their own profile picture" ON storage.objects;
    DROP POLICY IF EXISTS "Users can delete their own profile picture" ON storage.objects;
    DROP POLICY IF EXISTS "Anyone can view profile pictures" ON storage.objects;
    DROP POLICY IF EXISTS "Allow authenticated uploads to profile-pictures" ON storage.objects;
    DROP POLICY IF EXISTS "Allow authenticated updates to profile-pictures" ON storage.objects;
    DROP POLICY IF EXISTS "Allow authenticated deletes from profile-pictures" ON storage.objects;
    DROP POLICY IF EXISTS "Allow public reads from profile-pictures" ON storage.objects;
    DROP POLICY IF EXISTS "profile_pictures_insert" ON storage.objects;
    DROP POLICY IF EXISTS "profile_pictures_update" ON storage.objects;
    DROP POLICY IF EXISTS "profile_pictures_delete" ON storage.objects;
    DROP POLICY IF EXISTS "profile_pictures_select" ON storage.objects;
EXCEPTION WHEN OTHERS THEN
    -- Ignore any errors
    NULL;
END $$;

-- ============================================
-- STEP 3: Create simple, permissive policies
-- ============================================

-- INSERT: Any authenticated user can upload to their own folder
CREATE POLICY "profile_pictures_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'profile-pictures'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- UPDATE: Any authenticated user can update files in their own folder
CREATE POLICY "profile_pictures_update" ON storage.objects
FOR UPDATE TO authenticated
USING (
    bucket_id = 'profile-pictures'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'profile-pictures'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- DELETE: Any authenticated user can delete files in their own folder
CREATE POLICY "profile_pictures_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id = 'profile-pictures'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- SELECT: Anyone can view files in the profile-pictures bucket (it's public)
CREATE POLICY "profile_pictures_select" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'profile-pictures');

-- ============================================
-- STEP 4: Ensure profiles table has correct RLS policies
-- ============================================

-- Drop existing profile policies
DROP POLICY IF EXISTS "Users can view profiles" ON profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;

-- Recreate with simple checks
CREATE POLICY "Users can view profiles" ON profiles
FOR SELECT USING (true);

CREATE POLICY "Users can create their own profile" ON profiles
FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update their own profile" ON profiles
FOR UPDATE 
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- ============================================
-- STEP 5: Grant necessary permissions
-- ============================================

GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;
GRANT SELECT ON storage.objects TO anon;
GRANT SELECT ON storage.buckets TO anon;
GRANT ALL ON profiles TO authenticated;
GRANT SELECT ON profiles TO anon;

-- ============================================
-- STEP 6: Verify the bucket is set up correctly
-- ============================================

-- This should return the bucket with public = true
DO $$
DECLARE
    bucket_exists BOOLEAN;
    is_public BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM storage.buckets WHERE id = 'profile-pictures') INTO bucket_exists;
    SELECT public FROM storage.buckets WHERE id = 'profile-pictures' INTO is_public;
    
    IF NOT bucket_exists THEN
        RAISE NOTICE 'WARNING: profile-pictures bucket does not exist!';
    ELSIF NOT is_public THEN
        RAISE NOTICE 'WARNING: profile-pictures bucket is not public!';
    ELSE
        RAISE NOTICE 'SUCCESS: profile-pictures bucket is configured correctly';
    END IF;
END $$;
