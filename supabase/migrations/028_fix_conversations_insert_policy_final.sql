-- Migration: Fix conversations INSERT policy - final comprehensive fix
-- This ensures authenticated users can create conversations

-- Drop the existing policy (IF EXISTS ensures no error if it doesn't exist)
DROP POLICY IF EXISTS "Users can create conversations" ON conversations;

-- Create a new INSERT policy
-- TO authenticated: Only applies to authenticated users (not anon role)
-- WITH CHECK: Validates the row being inserted meets the conditions
--   - auth.uid() IS NOT NULL: Ensures user is actually authenticated
--   - created_by = auth.uid(): Ensures user can only set themselves as the creator
CREATE POLICY "Users can create conversations"
    ON conversations FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL 
        AND created_by = auth.uid()
    );

-- Verification: Query to confirm the policy was created correctly
-- This will show the policy details if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'conversations' 
        AND policyname = 'Users can create conversations'
        AND cmd = 'INSERT'
    ) THEN
        RAISE NOTICE '✅ Policy "Users can create conversations" created successfully';
    ELSE
        RAISE EXCEPTION '❌ Policy "Users can create conversations" was not created';
    END IF;
END $$;
