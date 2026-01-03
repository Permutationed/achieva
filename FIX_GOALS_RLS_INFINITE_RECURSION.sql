-- ==========================================
-- FIX INFINITE RECURSION IN GOALS RLS POLICY
-- ==========================================
-- 
-- Run this in Supabase Dashboard → SQL Editor
-- 
-- Problem: The "Users can view goals where they are tagged" policy causes
-- infinite recursion because:
-- 1. Goals policy checks goal_tags
-- 2. Goal_tags RLS policy checks goals
-- 3. This creates a circular dependency
--
-- Solution: Use a SECURITY DEFINER function to bypass RLS when checking goal_tags
-- ==========================================

-- Step 1: Create a function that checks goal_tags without triggering RLS recursion
CREATE OR REPLACE FUNCTION user_is_tagged_in_goal(p_goal_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM goal_tags
        WHERE goal_id = p_goal_id
        AND user_id = p_user_id
    );
$$;

-- Step 2: Drop the problematic goals policy
DROP POLICY IF EXISTS "Users can view goals where they are tagged" ON goals;

-- Step 3: Recreate the policy using the function (which bypasses RLS)
CREATE POLICY "Users can view goals where they are tagged"
    ON goals FOR SELECT
    USING (
        user_is_tagged_in_goal(goals.id, auth.uid())
    );

-- Step 4: Also simplify the goal_tags policy to avoid recursion
DROP POLICY IF EXISTS "Users can view tags for their goals or where tagged" ON goal_tags;

CREATE POLICY "Users can view tags for their goals or where tagged"
    ON goal_tags FOR SELECT
    USING (
        -- User is tagged - simple check, no goals reference needed
        goal_tags.user_id = auth.uid()
        -- User owns the goal - this checks goals but won't recurse because
        -- the goals policy for owners doesn't check goal_tags
        OR EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_tags.goal_id
            AND g.owner_id = auth.uid()
        )
    );








