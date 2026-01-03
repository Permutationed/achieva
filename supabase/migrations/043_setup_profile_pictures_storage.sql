-- Migration: Setup profile pictures storage bucket
-- 1. Create the bucket
-- 2. Set up RLS policies for the bucket

-- Step 1: Create the bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
SELECT 'profile-pictures', 'profile-pictures', true
WHERE NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'profile-pictures'
);

-- Step 2: Set up RLS policies for storage.objects
-- Note: We use bucket_id = 'profile-pictures' to restrict policies to this bucket

-- Policy 1: Users can upload their own profile picture
-- The file path format is: {user_id}/avatar.jpg
CREATE POLICY "Users can upload their own profile picture"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'profile-pictures' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Policy 2: Users can update their own profile picture
CREATE POLICY "Users can update their own profile picture"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'profile-pictures' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Policy 3: Users can delete their own profile picture
CREATE POLICY "Users can delete their own profile picture"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'profile-pictures' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Policy 4: Anyone can view profile pictures (since bucket is public)
CREATE POLICY "Anyone can view profile pictures"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'profile-pictures');
