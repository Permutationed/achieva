-- Migration: Robust Storage Policies for Profile Pictures (v2)
-- This migration re-creates the storage policies for the profile-pictures bucket
-- using a more robust name-based check with LIKE.

-- Ensure the bucket is public
UPDATE storage.buckets SET public = true WHERE id = 'profile-pictures';

-- Remove old policies
DROP POLICY IF EXISTS "Users can upload their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view profile pictures" ON storage.objects;

-- Policy 1: Users can upload their own profile picture (INSERT)
CREATE POLICY "Users can upload their own profile picture"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'profile-pictures' AND
    name LIKE auth.uid()::text || '/%'
);

-- Policy 2: Users can update their own profile picture (UPDATE)
CREATE POLICY "Users can update their own profile picture"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'profile-pictures' AND
    name LIKE auth.uid()::text || '/%'
)
WITH CHECK (
    bucket_id = 'profile-pictures' AND
    name LIKE auth.uid()::text || '/%'
);

-- Policy 3: Users can delete their own profile picture (DELETE)
CREATE POLICY "Users can delete their own profile picture"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'profile-pictures' AND
    name LIKE auth.uid()::text || '/%'
);

-- Policy 4: Anyone can view profile pictures (SELECT)
CREATE POLICY "Anyone can view profile pictures"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-pictures');

-- Ensure profiles policies are also robust
DROP POLICY IF EXISTS "Users can view profiles" ON profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;

CREATE POLICY "Users can view profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can create their own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
