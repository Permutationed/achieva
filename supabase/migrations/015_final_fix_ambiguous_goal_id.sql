-- Migration: Final fix for ambiguous goal_id error
-- This migration exhaustively drops all possible SELECT policies and creates
-- a single consolidated policy with a function that has no parameter naming conflicts

-- Step 1: Exhaustively drop ALL possible SELECT policies on goals table
-- This ensures no policy conflicts or ambiguous references
DROP POLICY IF EXISTS "Users can view public goals" ON goals;
DROP POLICY IF EXISTS "Users can view their own goals" ON goals;
DROP POLICY IF EXISTS "Users can view friends' goals" ON goals;
DROP POLICY IF EXISTS "Users can view custom visibility goals they're in ACL" ON goals;
DROP POLICY IF EXISTS "Users can view goals they have access to" ON goals;
DROP POLICY IF EXISTS "Users can view goals they collaborate on" ON goals;

-- Step 2: Drop and recreate can_read_goal function with renamed parameter to avoid conflicts
-- Using p_goal_id instead of goal_id prevents any potential naming conflicts
-- in policy evaluation contexts where multiple tables with goal_id columns exist
-- Must drop first because PostgreSQL doesn't allow changing parameter names
DROP FUNCTION IF EXISTS can_read_goal(UUID);
CREATE FUNCTION can_read_goal(p_goal_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    goal_visibility goal_visibility;
    goal_owner_id UUID;
BEGIN
    SELECT visibility, owner_id INTO goal_visibility, goal_owner_id
    FROM goals
    WHERE goals.id = p_goal_id;
    
    -- If goal doesn't exist, return false
    IF goal_visibility IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Owner can always read
    IF goal_owner_id = auth.uid() THEN
        RETURN TRUE;
    END IF;
    
    -- Collaborators: check if user is an accepted collaborator
    -- This applies regardless of visibility setting, so check early
    IF auth.uid() IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM goal_collaborators gc
            WHERE gc.goal_id = p_goal_id
            AND gc.user_id = auth.uid()
            AND gc.status = 'accepted'
        ) THEN
            RETURN TRUE;
        END IF;
    END IF;
    
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

-- Step 3: Create exactly ONE SELECT policy using the updated function
-- This single policy consolidates all access logic and prevents ambiguity
CREATE POLICY "Users can view goals they have access to"
    ON goals FOR SELECT
    USING (can_read_goal(goals.id));

-- Step 4: Fix UPDATE policy to use explicit table references
-- Ensure all goal_id references are qualified with table aliases
DROP POLICY IF EXISTS "Users can update their own goals" ON goals;
CREATE POLICY "Users can update their own goals"
    ON goals FOR UPDATE
    USING (
        goals.owner_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM goal_collaborators gc
            WHERE gc.goal_id = goals.id
            AND gc.user_id = auth.uid()
            AND gc.status = 'accepted'
        )
    )
    WITH CHECK (
        goals.owner_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM goal_collaborators gc
            WHERE gc.goal_id = goals.id
            AND gc.user_id = auth.uid()
            AND gc.status = 'accepted'
        )
    );

