-- Migration: Fix infinite recursion in goals RLS policy (COMPLETE RE-ARCHITECT)
-- 
-- The problem is circular dependencies between goals and its related tables (goal_acl, goal_tags, goal_items).
-- 1. goals SELECT policy calls can_read_goal()
-- 2. can_read_goal() queries goal_acl or goal_tags
-- 3. goal_acl/goal_tags SELECT policies query goals to check ownership
-- 4. That query on goals calls can_read_goal() again -> RECURSION
-- 
-- Solution: Create SECURITY DEFINER functions for all cross-table checks.
-- These functions run as the creator (postgres) and bypass RLS.

-- Step 1: Create a function to check goal ownership bypassing RLS
CREATE OR REPLACE FUNCTION is_goal_owner(p_goal_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM goals
        WHERE id = p_goal_id
        AND owner_id = p_user_id
    );
$$;

-- Step 2: Create a function to check if a user is in goal ACL bypassing RLS
CREATE OR REPLACE FUNCTION is_user_in_goal_acl(p_goal_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM goal_acl
        WHERE goal_id = p_goal_id
        AND user_id = p_user_id
    );
$$;

-- Step 3: Create a function to check if user is a friend of goal owner bypassing RLS
CREATE OR REPLACE FUNCTION is_friend_of_goal_owner(p_goal_owner_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM friendships
        WHERE status = 'accepted'
        AND (
            (user_id_1 = p_user_id AND user_id_2 = p_goal_owner_id)
            OR (user_id_1 = p_goal_owner_id AND user_id_2 = p_user_id)
        )
    );
$$;

-- Step 4: Redefine can_read_goal to use these functions and bypass RLS
-- We'll make it query a "base" version of the table or just rely on SECURITY DEFINER
CREATE OR REPLACE FUNCTION can_read_goal(p_goal_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    v_visibility goal_visibility;
    v_owner_id UUID;
    v_is_draft BOOLEAN;
    v_has_tags BOOLEAN;
BEGIN
    -- Query goals table directly. Since this is SECURITY DEFINER, 
    -- it bypasses RLS on the table it queries.
    SELECT visibility, owner_id, is_draft INTO v_visibility, v_owner_id, v_is_draft
    FROM goals
    WHERE id = p_goal_id;
    
    -- If goal doesn't exist
    IF v_owner_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- 1. Owner can always read
    IF v_owner_id = auth.uid() THEN
        RETURN TRUE;
    END IF;
    
    -- 2. Drafts are ONLY visible to owner
    IF v_is_draft = true THEN
        RETURN FALSE;
    END IF;
    
    -- 3. Check if goal has any tags (using our SD function from prev migration or direct query)
    -- Direct query is fine here because we are in a SECURITY DEFINER function
    SELECT EXISTS (SELECT 1 FROM goal_tags WHERE goal_id = p_goal_id) INTO v_has_tags;
    
    -- If goal has tags, it's visible to all authenticated users
    IF v_has_tags = true AND auth.uid() IS NOT NULL THEN
        RETURN TRUE;
    END IF;
    
    -- 4. Public goals
    IF v_visibility = 'public' THEN
        RETURN TRUE;
    END IF;
    
    -- 5. Friends-only
    IF v_visibility = 'friends' AND auth.uid() IS NOT NULL THEN
        IF is_friend_of_goal_owner(v_owner_id, auth.uid()) THEN
            RETURN TRUE;
        END IF;
    END IF;
    
    -- 6. Custom visibility (ACL)
    IF v_visibility = 'custom' AND auth.uid() IS NOT NULL THEN
        IF is_user_in_goal_acl(p_goal_id, auth.uid()) THEN
            RETURN TRUE;
        END IF;
    END IF;
    
    RETURN FALSE;
END;
$$;

-- Step 5: Update all related table policies to use these functions instead of querying goals
-- This is critical to break the recursion chain.

-- GOAL_ACL policies
DROP POLICY IF EXISTS "Users can view ACL for their goals" ON goal_acl;
CREATE POLICY "Users can view ACL for their goals"
    ON goal_acl FOR SELECT
    USING (is_goal_owner(goal_id, auth.uid()) OR user_id = auth.uid());

DROP POLICY IF EXISTS "Goal owners can add ACL entries" ON goal_acl;
CREATE POLICY "Goal owners can add ACL entries"
    ON goal_acl FOR INSERT
    WITH CHECK (is_goal_owner(goal_id, auth.uid()));

DROP POLICY IF EXISTS "Goal owners can delete ACL entries" ON goal_acl;
CREATE POLICY "Goal owners can delete ACL entries"
    ON goal_acl FOR DELETE
    USING (is_goal_owner(goal_id, auth.uid()));

-- GOAL_TAGS policies
DROP POLICY IF EXISTS "Users can view tags for their goals or where tagged" ON goal_tags;
CREATE POLICY "Users can view tags for their goals or where tagged"
    ON goal_tags FOR SELECT
    USING (is_goal_owner(goal_id, auth.uid()) OR user_id = auth.uid());

DROP POLICY IF EXISTS "Goal owners can tag friends" ON goal_tags;
CREATE POLICY "Goal owners can tag friends"
    ON goal_tags FOR INSERT
    WITH CHECK (is_goal_owner(goal_id, auth.uid()));

DROP POLICY IF EXISTS "Goal owners can delete tags" ON goal_tags;
CREATE POLICY "Goal owners can delete tags"
    ON goal_tags FOR DELETE
    USING (is_goal_owner(goal_id, auth.uid()));

-- GOAL_ITEMS policies
DROP POLICY IF EXISTS "Goal owners can manage items" ON goal_items;
CREATE POLICY "Goal owners can manage items"
    ON goal_items FOR ALL
    USING (is_goal_owner(goal_id, auth.uid()))
    WITH CHECK (is_goal_owner(goal_id, auth.uid()));

-- Step 6: Ensure exactly one SELECT policy on goals
DROP POLICY IF EXISTS "Users can view goals they have access to" ON goals;
CREATE POLICY "Users can view goals they have access to"
    ON goals FOR SELECT
    USING (can_read_goal(id));

-- Step 7: Fix UPDATE/DELETE policies on goals to avoid recursion
DROP POLICY IF EXISTS "Users can update their own goals" ON goals;
CREATE POLICY "Users can update their own goals"
    ON goals FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own goals" ON goals;
CREATE POLICY "Users can delete their own goals"
    ON goals FOR DELETE
    USING (owner_id = auth.uid());

-- Step 8: Grant permissions
GRANT EXECUTE ON FUNCTION is_goal_owner(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_in_goal_acl(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_friend_of_goal_owner(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION can_read_goal(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION can_read_goal(UUID) TO anon;
