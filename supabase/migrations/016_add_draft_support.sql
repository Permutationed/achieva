-- Migration: Add draft support for goals
-- This allows users to save goals as drafts before publishing
-- Collaborative goals automatically start as drafts and require approval

-- Step 1: Add is_draft column to goals table
ALTER TABLE goals ADD COLUMN IF NOT EXISTS is_draft BOOLEAN NOT NULL DEFAULT false;

-- Step 2: Add approved_by column to track which collaborators have approved (nullable array)
ALTER TABLE goals ADD COLUMN IF NOT EXISTS approved_by UUID[];

-- Step 3: Add approved column to goal_collaborators table
ALTER TABLE goal_collaborators ADD COLUMN IF NOT EXISTS approved BOOLEAN NOT NULL DEFAULT false;

-- Step 4: Create index for draft queries
CREATE INDEX IF NOT EXISTS idx_goals_is_draft ON goals(is_draft);
CREATE INDEX IF NOT EXISTS idx_goals_owner_draft ON goals(owner_id, is_draft) WHERE is_draft = true;

-- Step 5: Update can_read_goal function to handle draft visibility
-- Drafts are ONLY visible to owner and accepted collaborators
-- First, drop the policy that depends on the function
DROP POLICY IF EXISTS "Users can view goals they have access to" ON goals;
-- Now drop the function
DROP FUNCTION IF EXISTS can_read_goal(UUID);
-- Recreate the function with draft support
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
    goal_is_draft BOOLEAN;
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
    
    -- If goal is a draft, only owner and accepted collaborators can see it
    IF goal_is_draft = true THEN
        -- Check if user is an accepted collaborator
        IF auth.uid() IS NOT NULL THEN
            RETURN EXISTS (
                SELECT 1 FROM goal_collaborators gc
                WHERE gc.goal_id = p_goal_id
                AND gc.user_id = auth.uid()
                AND gc.status = 'accepted'
            );
        END IF;
        -- Drafts are not visible to anyone else
        RETURN FALSE;
    END IF;
    
    -- For published goals (is_draft = false), use existing visibility rules
    
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

-- Step 6: Recreate the SELECT policy that uses can_read_goal
-- This policy consolidates all access logic and prevents ambiguity
CREATE POLICY "Users can view goals they have access to"
    ON goals FOR SELECT
    USING (can_read_goal(goals.id));

-- Step 7: Create helper function to check if user can approve a draft
CREATE OR REPLACE FUNCTION can_approve_draft(p_goal_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    goal_owner_id UUID;
    goal_is_draft BOOLEAN;
    is_collaborator BOOLEAN;
BEGIN
    SELECT owner_id, is_draft INTO goal_owner_id, goal_is_draft
    FROM goals
    WHERE goals.id = p_goal_id;
    
    -- Goal must exist and be a draft
    IF goal_owner_id IS NULL OR goal_is_draft = false THEN
        RETURN FALSE;
    END IF;
    
    -- Owner cannot approve their own draft
    IF goal_owner_id = p_user_id THEN
        RETURN FALSE;
    END IF;
    
    -- User must be an accepted collaborator
    SELECT EXISTS (
        SELECT 1 FROM goal_collaborators gc
        WHERE gc.goal_id = p_goal_id
        AND gc.user_id = p_user_id
        AND gc.status = 'accepted'
    ) INTO is_collaborator;
    
    RETURN is_collaborator;
END;
$$;

-- Step 8: Create or replace insert_goal function to support drafts
CREATE OR REPLACE FUNCTION insert_goal(
    p_title TEXT,
    p_body TEXT,
    p_status TEXT,
    p_visibility TEXT,
    p_owner_id UUID,
    p_is_draft BOOLEAN DEFAULT false
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_goal_id UUID;
BEGIN
    -- Insert the goal
    INSERT INTO goals (owner_id, title, body, status, visibility, is_draft)
    VALUES (p_owner_id, p_title, p_body, p_status::goal_status, p_visibility::goal_visibility, p_is_draft)
    RETURNING id INTO new_goal_id;
    
    RETURN new_goal_id;
END;
$$;

-- Step 9: Grant execute permissions
GRANT EXECUTE ON FUNCTION can_read_goal(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION can_read_goal(UUID) TO anon;
GRANT EXECUTE ON FUNCTION can_approve_draft(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_goal(TEXT, TEXT, TEXT, TEXT, UUID, BOOLEAN) TO authenticated;

