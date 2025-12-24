-- Migration: Simplify goals INSERT RLS policy to fix auth.uid() resolution
-- This migration creates a more explicit and debuggable RLS policy for goal creation
-- 
-- Problem: The existing policy may not be recognizing auth.uid() correctly
-- Solution: Create a simpler policy that only checks owner_id = auth.uid()

-- ===== Step 1: Drop existing INSERT policy =====
DROP POLICY IF EXISTS "Users can create their own goals" ON goals;

-- ===== Step 2: Create simplified INSERT policy =====
-- This policy is more explicit and easier to debug
-- It only checks that owner_id matches auth.uid()
CREATE POLICY "Users can create their own goals"
    ON goals 
    FOR INSERT 
    WITH CHECK (
        -- Simple check: owner_id must match the authenticated user's ID
        owner_id = auth.uid()
    );

-- ===== Step 3: Add policy comment for documentation =====
COMMENT ON POLICY "Users can create their own goals" ON goals IS 
    'Simplified INSERT policy: allows authenticated users to create goals where owner_id matches auth.uid(). 
     If this fails with error 42501, check:
     1. JWT token is being sent in Authorization header
     2. auth.uid() is not NULL (user is authenticated)
     3. owner_id in INSERT data matches auth.uid()';

-- ===== Step 4: Verify RLS is enabled =====
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;

-- ===== Step 5: Verify policy was created =====
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'goals' 
    AND policyname = 'Users can create their own goals'
    AND cmd = 'INSERT';
    
    IF policy_count = 0 THEN
        RAISE EXCEPTION 'INSERT policy was not created successfully';
    ELSE
        RAISE NOTICE '✅ INSERT policy created successfully';
        RAISE NOTICE 'Policy check: owner_id = auth.uid()';
    END IF;
END $$;

-- ===== Step 6: Display current policies for verification =====
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    RAISE NOTICE '=== Current RLS Policies for goals table ===';
    FOR policy_record IN 
        SELECT policyname, cmd
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'goals'
        ORDER BY cmd, policyname
    LOOP
        RAISE NOTICE 'Policy: % (Command: %)', policy_record.policyname, policy_record.cmd;
    END LOOP;
END $$;
