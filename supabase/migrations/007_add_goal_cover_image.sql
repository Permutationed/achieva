-- Migration: Add cover image support to goals
-- Description: Adds cover_image_url column to goals table and sets up Supabase Storage bucket with RLS policies

-- =====================================================
-- PART 1: Add cover_image_url column to goals table
-- =====================================================

ALTER TABLE goals 
ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

COMMENT ON COLUMN goals.cover_image_url IS 'Public URL to the goal cover image stored in Supabase Storage';

-- =====================================================
-- PART 2: Create Storage Bucket (run via Supabase Dashboard or API)
-- =====================================================

-- Note: Storage bucket creation is typically done via Supabase Dashboard or API
-- Bucket name: 'goal-covers'
-- Bucket settings: 
--   - Public: false (use authenticated access)
--   - File size limit: 5MB recommended
--   - Allowed MIME types: image/jpeg, image/png, image/webp

-- To create via SQL, you would need to insert into storage.buckets:
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('goal-covers', 'goal-covers', false)
-- ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- PART 3: Storage RLS Policies
-- =====================================================

-- Policy 1: Users can upload images for their own goals
CREATE POLICY IF NOT EXISTS "Users can upload cover images for their goals"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'goal-covers' AND
  auth.uid() IS NOT NULL AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id FROM goals WHERE owner_id = auth.uid()
  )
);

-- Policy 2: Users can view images based on goal visibility
CREATE POLICY IF NOT EXISTS "Users can view goal cover images based on visibility"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'goal-covers' AND
  (
    -- Public goals are viewable by anyone
    (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM goals WHERE visibility = 'public'
    )
    OR
    -- Friends-only goals viewable by friends (when friendships table is ready)
    (
      (storage.foldername(name))[1]::uuid IN (
        SELECT id FROM goals WHERE visibility = 'friends' AND owner_id = auth.uid()
      )
      OR
      (storage.foldername(name))[1]::uuid IN (
        SELECT g.id FROM goals g
        WHERE g.visibility = 'friends' AND g.owner_id IN (
          SELECT user_id FROM friendships WHERE friend_id = auth.uid() AND status = 'accepted'
          UNION
          SELECT friend_id FROM friendships WHERE user_id = auth.uid() AND status = 'accepted'
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
CREATE POLICY IF NOT EXISTS "Users can update their own goal cover images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'goal-covers' AND
  auth.uid() IS NOT NULL AND
  (storage.foldername(name))[1]::uuid IN (
    SELECT id FROM goals WHERE owner_id = auth.uid()
  )
);

-- Policy 4: Users can delete their own goal images
CREATE POLICY IF NOT EXISTS "Users can delete their own goal cover images"
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

