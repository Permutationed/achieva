-- EMERGENCY FIX: Run this if migration 006 didn't work
-- This is the absolute simplest INSERT policy that should work

-- Step 1: Drop ALL existing INSERT policies for goals
DROP POLICY IF EXISTS "Users can create their own goals" ON goals;

-- Step 2: Create the simplest possible INSERT policy
CREATE POLICY "Users can create their own goals"
    ON goals 
    FOR INSERT 
    WITH CHECK (owner_id = auth.uid());

-- Step 3: Verify it was created
SELECT 
    policyname,
    cmd,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'goals'
AND cmd = 'INSERT';

-- Step 4: Test auth.uid() is working
SELECT auth.uid() as current_user_id;

-- If you see your user ID above, the policy should now work!

