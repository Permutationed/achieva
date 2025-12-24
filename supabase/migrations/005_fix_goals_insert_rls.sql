-- Migration: Fix RLS policies for goals table INSERT operations
-- This ensures that authenticated users can create goals with proper auth.uid() resolution

-- Drop existing INSERT policy
DROP POLICY IF EXISTS "Users can create their own goals" ON goals;

-- Create a helper function to verify authentication (for debugging)
CREATE OR REPLACE FUNCTION verify_auth_uid()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN auth.uid();
END;
$$;

-- Recreate the INSERT policy with explicit authentication check
-- This policy ensures:
-- 1. User is authenticated (auth.uid() IS NOT NULL)
-- 2. The owner_id matches the authenticated user's ID
CREATE POLICY "Users can create their own goals"
    ON goals FOR INSERT
    WITH CHECK (
        -- Ensure user is authenticated
        auth.uid() IS NOT NULL 
        -- Ensure owner_id matches authenticated user
        AND owner_id = auth.uid()
        -- Additional safety check: owner_id must not be null
        AND owner_id IS NOT NULL
    );

-- Add a comment for documentation
COMMENT ON POLICY "Users can create their own goals" ON goals IS 
    'Allows authenticated users to create goals where owner_id matches their auth.uid(). Requires valid JWT token.';

-- Verify RLS is enabled on the goals table
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;

-- Verify the policy was created
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'goals' 
        AND policyname = 'Users can create their own goals'
    ) THEN
        RAISE EXCEPTION 'Policy "Users can create their own goals" was not created successfully';
    ELSE
        RAISE NOTICE 'Policy "Users can create their own goals" created successfully';
    END IF;
END $$;

