-- Migration: Fix Storage RLS Policies for Public Bucket
-- Description: Simplifies RLS policies to allow public access to images from public goals
-- This works with a public bucket where RLS still controls access based on goal visibility

-- Drop existing SELECT policy
DROP POLICY IF EXISTS "Users can view goal cover images based on visibility" ON storage.objects;

-- Create simplified SELECT policy for public bucket
-- For a public bucket, we still use RLS to control access based on goal visibility
CREATE POLICY "Users can view goal cover images based on visibility"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'goal-covers' AND
  (
    -- Public goals are viewable by anyone (including anonymous users)
    (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM goals WHERE visibility = 'public'
    )
    OR
    -- Friends-only goals viewable by friends or owner
    (
      (storage.foldername(name))[1]::uuid IN (
        SELECT id FROM goals WHERE visibility = 'friends' AND owner_id = auth.uid()
      )
      OR
      (storage.foldername(name))[1]::uuid IN (
        SELECT g.id FROM goals g
        WHERE g.visibility = 'friends' AND g.owner_id IN (
          SELECT user_id_1 FROM friendships WHERE user_id_2 = auth.uid() AND status = 'accepted'
          UNION
          SELECT user_id_2 FROM friendships WHERE user_id_1 = auth.uid() AND status = 'accepted'
        )
      )
    )
    OR
    -- Owner can always view their own goal images
    (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM goals WHERE owner_id = auth.uid()
    )
    OR
    -- Allow anonymous access for public goals (important for public bucket)
    -- This allows images to load even when auth.uid() is NULL
    (auth.uid() IS NULL AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM goals WHERE visibility = 'public'
    ))
  )
);

-- Ensure bucket is public
UPDATE storage.buckets 
SET public = true 
WHERE id = 'goal-covers';

-- Verify the policy was created
SELECT policyname, cmd, qual
FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects' 
AND policyname = 'Users can view goal cover images based on visibility';

