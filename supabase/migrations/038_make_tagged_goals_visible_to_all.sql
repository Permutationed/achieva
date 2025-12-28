-- Migration: Make tagged goals visible to everyone
-- If a goal has any tags, it should be visible to all authenticated users
-- regardless of the original visibility setting

-- Step 1: Update can_read_goal function to check for tags
-- If a goal has tags, make it visible to everyone (authenticated users)
-- Use CREATE OR REPLACE to avoid dropping dependent policies
DROP POLICY IF EXISTS "Users can view goals they have access to" ON goals;

-- Recreate the function with tag visibility logic
-- This function removes all references to goal_collaborators (which was removed)
-- Using CREATE OR REPLACE so dependent policies (likes, comments) remain intact
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
    
    -- NEW: Check if goal has any tags
    -- If it has tags, make it visible to all authenticated users
    -- Use a direct query that bypasses RLS to avoid recursion
    SELECT EXISTS (
        SELECT 1 FROM goal_tags
        WHERE goal_id = p_goal_id
    ) INTO has_tags;
    
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

-- Step 2: Recreate the SELECT policy that uses can_read_goal
CREATE POLICY "Users can view goals they have access to"
    ON goals FOR SELECT
    USING (can_read_goal(goals.id));

-- Step 3: Grant execute permissions
GRANT EXECUTE ON FUNCTION can_read_goal(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION can_read_goal(UUID) TO anon;

-- Step 4: Remove the old "Users can view goals where they are tagged" policy
-- since tagged goals are now visible to everyone through can_read_goal
DROP POLICY IF EXISTS "Users can view goals where they are tagged" ON goals;

