-- Migration: Fix infinite recursion in goals RLS policy
-- The "Users can view goals where they are tagged" policy causes recursion
-- because goal_tags RLS policy checks goals, which checks goal_tags again.
-- Solution: Simplify goal_tags SELECT policy to avoid circular dependency.

-- Drop the problematic policy on goal_tags
DROP POLICY IF EXISTS "Users can view tags for their goals or where tagged" ON goal_tags;

-- Recreate with simpler logic that doesn't cause recursion
-- Users can view tags where they are the tagged user (no goals check needed)
-- OR where they own the goal (but we'll check this more carefully)
CREATE POLICY "Users can view tags for their goals or where tagged"
    ON goal_tags FOR SELECT
    USING (
        -- User is tagged (simple check, no goals reference)
        goal_tags.user_id = auth.uid()
        -- OR user owns the goal (but we need to check goals, which might cause recursion)
        -- Actually, let's use a more direct approach - check if the goal exists and user owns it
        -- but use a security definer function or just allow goal owners to see all tags for their goals
        OR EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_tags.goal_id
            AND g.owner_id = auth.uid()
            -- Add a check to prevent infinite recursion by ensuring we're not in a recursive call
            -- Actually, the issue is that when checking goals, it checks goal_tags, which checks goals again
            -- The solution is to make the goal_tags policy NOT check goals when the user is the tagged user
        )
    );

-- Actually, a better solution: Make the goal_tags policy simpler
-- Drop and recreate with a non-recursive version
DROP POLICY IF EXISTS "Users can view tags for their goals or where tagged" ON goal_tags;

-- Simple policy: users can see tags where they are tagged OR where they own the goal
-- But we need to avoid the recursion. The key is that when checking goals RLS,
-- it should NOT trigger goal_tags RLS check again.
-- 
-- The real fix: The goal_tags policy should use SECURITY DEFINER or bypass RLS
-- when checking goals. But a simpler fix is to make the goals policy check goal_tags
-- in a way that doesn't trigger RLS on goal_tags.

-- Let's use a different approach: Make goal_tags SELECT policy bypass RLS check for the tagged user case
CREATE POLICY "Users can view tags for their goals or where tagged"
    ON goal_tags FOR SELECT
    USING (
        -- If user is tagged, allow access (no goals check needed)
        goal_tags.user_id = auth.uid()
        -- If user owns the goal, allow access (this will check goals, but won't recurse
        -- because we're not checking goal_tags from within this policy)
        OR EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_tags.goal_id
            AND g.owner_id = auth.uid()
        )
    );

-- The issue is that when the goals policy checks goal_tags, it triggers goal_tags RLS,
-- which checks goals, which checks goal_tags again.
-- 
-- Solution: Use a security definer function or make the goal_tags check in goals policy
-- use a subquery that bypasses RLS. But the simplest fix is to make the goal_tags
-- policy for "where tagged" not check goals at all - just check user_id directly.

-- Actually, I think the real issue is in the goals policy. Let me check if we can
-- make it use a more direct check that doesn't trigger RLS.

-- Better solution: Modify the goals policy to use a direct query that bypasses RLS
-- by using a function or by restructuring the policy.

-- For now, let's try a simpler fix: Make the goal_tags policy not check goals
-- when the user is the tagged user. The ownership check can stay, but it should
-- be done in a way that doesn't cause recursion.

-- Actually, the PostgreSQL RLS system should handle this, but there might be an issue
-- with how the policies are structured. Let's try using a function with SECURITY DEFINER.

-- Simpler fix: Just allow users to see tags where they are tagged, period.
-- The ownership check can be separate or we can rely on the fact that goal owners
-- can see their goals through the "Users can view their own goals" policy.

DROP POLICY IF EXISTS "Users can view tags for their goals or where tagged" ON goal_tags;

-- Create a simpler policy that doesn't cause recursion
CREATE POLICY "Users can view tags for their goals or where tagged"
    ON goal_tags FOR SELECT
    USING (
        -- User is tagged - simple check, no goals reference
        goal_tags.user_id = auth.uid()
        -- User owns the goal - this will check goals RLS, but since we're checking
        -- ownership directly, it shouldn't recurse (the goals policy for owners
        -- doesn't check goal_tags)
        OR EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_tags.goal_id
            AND g.owner_id = auth.uid()
        )
    );

-- Now fix the goals policy to avoid recursion when checking goal_tags
-- The issue is that when checking goal_tags, PostgreSQL applies RLS to goal_tags,
-- which then checks goals, creating a loop.

-- Solution: Use a function with SECURITY DEFINER to bypass RLS when checking goal_tags
-- OR restructure the policy to avoid the circular dependency.

-- Let's create a function that checks goal_tags without triggering RLS recursion
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

-- Now update the goals policy to use this function
DROP POLICY IF EXISTS "Users can view goals where they are tagged" ON goals;

CREATE POLICY "Users can view goals where they are tagged"
    ON goals FOR SELECT
    USING (
        user_is_tagged_in_goal(goals.id, auth.uid())
    );


