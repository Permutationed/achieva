-- Migration: Fix conversations INSERT policy to ensure it works correctly
-- The policy should allow users to insert conversations where created_by matches auth.uid()

-- Drop and recreate the INSERT policy to ensure it's correct
DROP POLICY IF EXISTS "Users can create conversations" ON conversations;

-- Recreate the INSERT policy - users can create conversations if created_by = auth.uid()
-- Note: auth.uid() already returns UUID, so no explicit cast needed
CREATE POLICY "Users can create conversations"
    ON conversations FOR INSERT
    WITH CHECK (created_by = auth.uid());

