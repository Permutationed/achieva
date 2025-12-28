-- Add avatar_url column to profiles table for profile pictures

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Note: The avatar_url will store the full URL to the image in Supabase Storage
-- Storage bucket: profile-pictures (needs to be created in Supabase Dashboard)



