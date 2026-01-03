-- Migration: Fix check_conversation_membership function for Google OAuth users
-- The issue is that SECURITY DEFINER functions need to explicitly set search_path
-- and ensure RLS is properly bypassed when checking conversation membership
-- This fixes RLS issues preventing Google OAuth users from sending messages

-- Drop and recreate the function with proper RLS bypass
-- SECURITY DEFINER functions run with the privileges of the function owner (postgres)
-- which bypasses RLS, but we need to ensure search_path is set correctly
DROP FUNCTION IF EXISTS check_conversation_membership(UUID, UUID);

CREATE OR REPLACE FUNCTION check_conversation_membership(conv_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- SECURITY DEFINER functions bypass RLS by default
    -- Explicitly use public schema to avoid any search_path issues
    -- This ensures the function works correctly for all users including Google OAuth
    RETURN EXISTS (
        SELECT 1 
        FROM public.conversation_participants
        WHERE conversation_id = conv_id
        AND conversation_participants.user_id = check_conversation_membership.user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_conversation_membership(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_conversation_membership(UUID, UUID) TO anon;

-- Ensure the function is accessible and documented
COMMENT ON FUNCTION check_conversation_membership(UUID, UUID) IS 
'Checks if a user is a participant in a conversation. Bypasses RLS using SECURITY DEFINER. Works for all authentication methods including Google OAuth.';
