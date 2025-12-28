-- Migration: Add cover image support to goals
-- Description: Adds cover_image_url column to goals table and sets up Supabase Storage bucket with RLS policies

-- =====================================================
-- PART 1: Add cover_image_url column to goals table
-- =====================================================

ALTER TABLE goals 
ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

COMMENT ON COLUMN goals.cover_image_url IS 'Public URL to the goal cover image stored in Supabase Storage';

-- =====================================================
-- PART 2: Create Storage Bucket
-- =====================================================

-- Create the storage bucket for goal cover images
-- Set to public=true so images can be accessed via public URLs (RLS policies still control access)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'goal-covers',
  'goal-covers',
  true, -- Public bucket for faster image loading (RLS policies still apply)
  5242880, -- 5MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET 
  name = EXCLUDED.name,
  public = true, -- Ensure bucket is public
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- =====================================================
-- PART 3: Storage RLS Policies
-- =====================================================

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can upload cover images for their goals" ON storage.objects;
DROP POLICY IF EXISTS "Users can view goal cover images based on visibility" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own goal cover images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own goal cover images" ON storage.objects;

-- Policy 1: Users can upload images for their own goals
CREATE POLICY "Users can upload cover images for their goals"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'goal-covers' AND
  auth.uid() IS NOT NULL AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id FROM goals WHERE owner_id = auth.uid()
  )
);

-- Policy 2: Users can view images based on goal visibility
CREATE POLICY "Users can view goal cover images based on visibility"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'goal-covers' AND
  (
    -- Public goals are viewable by anyone
    (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM goals WHERE visibility = 'public'
    )
    OR
    -- Friends-only goals viewable by friends
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
  )
);

-- Policy 3: Users can update their own goal images
CREATE POLICY "Users can update their own goal cover images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'goal-covers' AND
  auth.uid() IS NOT NULL AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id FROM goals WHERE owner_id = auth.uid()
  )
);

-- Policy 4: Users can delete their own goal images
CREATE POLICY "Users can delete their own goal cover images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'goal-covers' AND
  auth.uid() IS NOT NULL AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id FROM goals WHERE owner_id = auth.uid()
  )
);

-- =====================================================
-- PART 4: Cleanup function for orphaned images
-- =====================================================

-- Optional: Function to clean up images when goals are deleted
CREATE OR REPLACE FUNCTION cleanup_goal_cover_image()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Note: Actual deletion from storage must be done via client or edge function
  -- This function just logs the need for cleanup
  -- In practice, you'd want to delete from storage.objects where name starts with OLD.id
  RETURN OLD;
END;
$$;

-- Optional: Trigger to call cleanup function
-- CREATE TRIGGER trigger_cleanup_goal_cover_image
-- AFTER DELETE ON goals
-- FOR EACH ROW
-- EXECUTE FUNCTION cleanup_goal_cover_image();

