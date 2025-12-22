-- Migration: Fix RLS recursion using SECURITY DEFINER helper functions
-- This replaces the workaround in 002_fix_rls_recursion.sql with a proper solution
-- that preserves backend.md semantics while avoiding infinite recursion

-- ===== Helper Functions (SECURITY DEFINER to bypass RLS) =====

-- Check if current user is the owner of a goal
CREATE OR REPLACE FUNCTION is_goal_owner(goal_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM goals
        WHERE goals.id = goal_id
        AND goals.owner_id = auth.uid()
    );
END;
$$;

-- Check if current user can read a goal (public, owner, friend, or in ACL)
CREATE OR REPLACE FUNCTION can_read_goal(goal_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    goal_visibility goal_visibility;
    goal_owner_id UUID;
BEGIN
    SELECT visibility, owner_id INTO goal_visibility, goal_owner_id
    FROM goals
    WHERE goals.id = goal_id;
    
    -- If goal doesn't exist, return false
    IF goal_visibility IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Owner can always read
    IF goal_owner_id = auth.uid() THEN
        RETURN TRUE;
    END IF;
    
    -- Public goals are readable by anyone (authenticated or not)
    IF goal_visibility = 'public' THEN
        RETURN TRUE;
    END IF;
    
    -- Friends-only: check if friendship exists
    IF goal_visibility = 'friends' AND auth.uid() IS NOT NULL THEN
        RETURN EXISTS (
            SELECT 1 FROM friendships
            WHERE (
                (user_id_1 = auth.uid() AND user_id_2 = goal_owner_id)
                OR (user_id_1 = goal_owner_id AND user_id_2 = auth.uid())
            )
            AND status = 'accepted'
        );
    END IF;
    
    -- Custom visibility: check if user is in ACL
    IF goal_visibility = 'custom' AND auth.uid() IS NOT NULL THEN
        RETURN EXISTS (
            SELECT 1 FROM goal_acl
            WHERE goal_acl.goal_id = goal_id
            AND goal_acl.user_id = auth.uid()
        );
    END IF;
    
    RETURN FALSE;
END;
$$;

-- ===== Drop existing policies =====

-- Drop goal_acl policies
DROP POLICY IF EXISTS "Users can view ACL for their goals" ON goal_acl;
DROP POLICY IF EXISTS "Users can view their own ACL entries" ON goal_acl;
DROP POLICY IF EXISTS "Goal owners can add ACL entries" ON goal_acl;
DROP POLICY IF EXISTS "Goal owners can delete ACL entries" ON goal_acl;

-- Drop goals policies (we'll recreate them)
DROP POLICY IF EXISTS "Users can view public goals" ON goals;
DROP POLICY IF EXISTS "Users can view their own goals" ON goals;
DROP POLICY IF EXISTS "Users can view friends' goals" ON goals;
DROP POLICY IF EXISTS "Users can view custom visibility goals they're in ACL" ON goals;
DROP POLICY IF EXISTS "Users can create their own goals" ON goals;
DROP POLICY IF EXISTS "Users can update their own goals" ON goals;
DROP POLICY IF EXISTS "Users can delete their own goals" ON goals;

-- Drop goal_items policies
DROP POLICY IF EXISTS "Users can view items for visible goals" ON goal_items;
DROP POLICY IF EXISTS "Goal owners can manage items" ON goal_items;
DROP POLICY IF EXISTS "Goal editors can manage items" ON goal_items;

-- ===== Recreate policies using helper functions =====

-- goal_acl policies (non-recursive)
CREATE POLICY "Users can view their own ACL entries"
    ON goal_acl FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Goal owners can add ACL entries"
    ON goal_acl FOR INSERT
    WITH CHECK (is_goal_owner(goal_id));

CREATE POLICY "Goal owners can delete ACL entries"
    ON goal_acl FOR DELETE
    USING (is_goal_owner(goal_id));

-- goals policies (using helper function)
CREATE POLICY "Users can view goals they have access to"
    ON goals FOR SELECT
    USING (can_read_goal(id));

CREATE POLICY "Users can create their own goals"
    ON goals FOR INSERT
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can update their own goals"
    ON goals FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can delete their own goals"
    ON goals FOR DELETE
    USING (owner_id = auth.uid());

-- goal_items policies (using helper function)
CREATE POLICY "Users can view items for accessible goals"
    ON goal_items FOR SELECT
    USING (can_read_goal(goal_id));

CREATE POLICY "Goal owners can manage items"
    ON goal_items FOR ALL
    USING (is_goal_owner(goal_id));

CREATE POLICY "Goal editors can manage items"
    ON goal_items FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM goal_acl
            WHERE goal_acl.goal_id = goal_items.goal_id
            AND goal_acl.user_id = auth.uid()
            AND goal_acl.role = 'editor'
        )
    );

