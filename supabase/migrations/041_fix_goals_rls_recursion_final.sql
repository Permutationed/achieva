-- Migration: Fix infinite recursion in goals RLS policy (FINAL FIX)
-- 
-- Problem: The can_read_goal function checks goal_tags, which triggers RLS on goal_tags.
-- The goal_tags RLS policy checks goals, which calls can_read_goal again → infinite recursion.
-- 
-- This happens when:
-- 1. Creating a goal with a cover image (triggers SELECT to verify access)
-- 2. Completing a goal (triggers UPDATE which checks SELECT access)
-- 
-- Solution: Create a SECURITY DEFINER function to check goal_tags without triggering RLS

-- Step 1: Create a function that checks if a goal has tags, bypassing RLS
-- This function runs with SECURITY DEFINER, so it bypasses RLS on goal_tags
CREATE OR REPLACE FUNCTION goal_has_tags(p_goal_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM goal_tags
        WHERE goal_id = p_goal_id
        LIMIT 1
    );
$$;

-- Step 2: Update can_read_goal to use the new function instead of direct query
-- This prevents RLS recursion because goal_has_tags bypasses RLS
DROP POLICY IF EXISTS "Users can view goals they have access to" ON goals;

CREATE OR REPLACE FUNCTION can_read_goal(p_goal_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    goal_visibility goal_visibility;
    goal_owner_id UUID;
    goal_is_draft BOOLEAN;
    has_tags BOOLEAN;
BEGIN
    SELECT visibility, owner_id, is_draft INTO goal_visibility, goal_owner_id, goal_is_draft
    FROM goals
    WHERE goals.id = p_goal_id;
    
    -- If goal doesn't exist, return false
    IF goal_visibility IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Owner can always read (including drafts)
    IF goal_owner_id = auth.uid() THEN
        RETURN TRUE;
    END IF;
    
    -- If goal is a draft, only owner can see it (no tag visibility for drafts)
    IF goal_is_draft = true THEN
        RETURN FALSE;
    END IF;
    
    -- NEW: Check if goal has any tags using the SECURITY DEFINER function
    -- This bypasses RLS on goal_tags, preventing infinite recursion
    SELECT goal_has_tags(p_goal_id) INTO has_tags;
    
    -- If goal has tags, it's visible to all authenticated users
    IF has_tags = true AND auth.uid() IS NOT NULL THEN
        RETURN TRUE;
    END IF;
    
    -- For published goals without tags, use existing visibility rules
    
    -- Public goals are readable by anyone (authenticated or not)
    IF goal_visibility = 'public' THEN
        RETURN TRUE;
    END IF;
    
    -- Friends-only: check if friendship exists
    IF goal_visibility = 'friends' AND auth.uid() IS NOT NULL THEN
        RETURN EXISTS (
            SELECT 1 FROM friendships f
            WHERE (
                (f.user_id_1 = auth.uid() AND f.user_id_2 = goal_owner_id)
                OR (f.user_id_1 = goal_owner_id AND f.user_id_2 = auth.uid())
            )
            AND f.status = 'accepted'
        );
    END IF;
    
    -- Custom visibility: check if user is in ACL
    IF goal_visibility = 'custom' AND auth.uid() IS NOT NULL THEN
        RETURN EXISTS (
            SELECT 1 FROM goal_acl ga
            WHERE ga.goal_id = p_goal_id
            AND ga.user_id = auth.uid()
        );
    END IF;
    
    RETURN FALSE;
END;
$$;

-- Step 3: Recreate the SELECT policy that uses can_read_goal
CREATE POLICY "Users can view goals they have access to"
    ON goals FOR SELECT
    USING (can_read_goal(goals.id));

-- Step 4: Grant execute permissions
GRANT EXECUTE ON FUNCTION goal_has_tags(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION goal_has_tags(UUID) TO anon;
GRANT EXECUTE ON FUNCTION can_read_goal(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION can_read_goal(UUID) TO anon;

-- Step 5: Also fix the goal_tags SELECT policy to avoid recursion
-- The current policy checks goals, which might trigger can_read_goal
-- We'll simplify it to avoid the circular dependency
DROP POLICY IF EXISTS "Users can view tags for their goals or where tagged" ON goal_tags;
DROP POLICY IF EXISTS "Users can view tags for visible goals" ON goal_tags;

-- Create a simpler policy that doesn't cause recursion
-- Users can see tags where they are tagged (simple check, no goals reference)
-- OR where they own the goal (using a direct ownership check that won't recurse)
CREATE POLICY "Users can view tags for their goals or where tagged"
    ON goal_tags FOR SELECT
    USING (
        -- User is tagged - simple check, no goals reference needed
        goal_tags.user_id = auth.uid()
        -- OR user owns the goal - check ownership directly without triggering can_read_goal
        -- This works because we're checking ownership directly, not visibility
        OR EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_tags.goal_id
            AND g.owner_id = auth.uid()
        )
    );

-- Note: The ownership check above won't cause recursion because:
-- 1. It only checks owner_id directly, not visibility
-- 2. The goals SELECT policy for owners (owner_id = auth.uid()) doesn't check goal_tags
-- 3. So there's no circular dependency
