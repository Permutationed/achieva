# How to Run Migration 007: Add Goal Cover Image Support

This migration adds cover image support to goals by adding a `cover_image_url` column and setting up Supabase Storage with proper RLS policies.

## Prerequisites

1. Access to your Supabase project dashboard
2. SQL Editor access in Supabase

## Steps

### Step 1: Create Storage Bucket (Dashboard)

1. Go to your Supabase project dashboard
2. Navigate to **Storage** in the left sidebar
3. Click **"New bucket"**
4. Configure the bucket:
   - **Name**: `goal-covers`
   - **Public**: Unchecked (keep it private, RLS will handle access)
   - **File size limit**: 5 MB (recommended)
   - **Allowed MIME types**: `image/jpeg`, `image/png`, `image/webp`
5. Click **"Create bucket"**

### Step 2: Run SQL Migration

1. In your Supabase dashboard, go to **SQL Editor**
2. Click **"New query"**
3. Copy the entire contents of `supabase/migrations/007_add_goal_cover_image.sql`
4. Paste into the SQL Editor
5. Click **"Run"** or press `Cmd/Ctrl + Enter`

### Step 3: Verify

Run this query to verify the migration was successful:

```sql
-- Check if column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'goals' AND column_name = 'cover_image_url';

-- Check if storage bucket exists
SELECT * FROM storage.buckets WHERE id = 'goal-covers';

-- Check storage policies
SELECT * FROM pg_policies 
WHERE schemaname = 'storage' 
AND tablename = 'objects' 
AND policyname LIKE '%goal%cover%';
```

Expected results:
- The `cover_image_url` column should appear as TEXT type
- The `goal-covers` bucket should be listed
- Four RLS policies should be created for storage.objects

## What This Migration Does

1. **Adds `cover_image_url` column** to the `goals` table (nullable TEXT field)
2. **Sets up Storage RLS policies** for the `goal-covers` bucket:
   - Users can upload images for their own goals
   - Users can view images based on goal visibility (public/friends/owner)
   - Users can update their own goal images
   - Users can delete their own goal images

## Rollback (if needed)

If you need to rollback this migration:

```sql
-- Remove column
ALTER TABLE goals DROP COLUMN IF EXISTS cover_image_url;

-- Remove policies
DROP POLICY IF EXISTS "Users can upload cover images for their goals" ON storage.objects;
DROP POLICY IF EXISTS "Users can view goal cover images based on visibility" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own goal cover images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own goal cover images" ON storage.objects;

-- Remove bucket (via Dashboard > Storage > goal-covers > Settings > Delete bucket)
-- Or via SQL:
-- DELETE FROM storage.buckets WHERE id = 'goal-covers';
```

## Notes

- The storage bucket must be created via the Dashboard before running the SQL migration
- Images will be stored with path structure: `goal-covers/{goal-id}/cover.jpg`
- Maximum file size is recommended at 5MB to keep uploads fast
- RLS policies ensure users can only upload/modify images for goals they own
- Image visibility follows goal visibility settings (public/friends/custom)

