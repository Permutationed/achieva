-- Migration: Fix goal_items RLS ambiguity using SECURITY DEFINER function
-- This creates an RPC function that bypasses RLS join context issues entirely

-- Create a SECURITY DEFINER function to fetch visible goal items
-- This function takes an array of goal IDs and returns items only for goals
-- that the current user can see, completely bypassing RLS policy evaluation
CREATE OR REPLACE FUNCTION get_visible_goal_items(goal_ids UUID[])
RETURNS TABLE (
    id UUID,
    goal_id UUID,
    title TEXT,
    completed BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        gi.id,
        gi.goal_id,
        gi.title,
        gi.completed,
        gi.created_at,
        gi.updated_at
    FROM goal_items gi
    INNER JOIN goals g ON g.id = gi.goal_id
    WHERE gi.goal_id = ANY(goal_ids)
    AND (
        -- Owner can always see items
        g.owner_id = auth.uid()
        -- Public goals are visible to everyone
        OR g.visibility = 'public'
        -- Friends-only: check if friendship exists
        OR (
            g.visibility = 'friends'
            AND auth.uid() IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM friendships f
                WHERE (
                    (f.user_id_1 = auth.uid() AND f.user_id_2 = g.owner_id)
                    OR (f.user_id_1 = g.owner_id AND f.user_id_2 = auth.uid())
                )
                AND f.status = 'accepted'
            )
        )
        -- Custom visibility: check if user is in ACL
        OR (
            g.visibility = 'custom'
            AND auth.uid() IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM goal_acl ga
                WHERE ga.goal_id = g.id
                AND ga.user_id = auth.uid()
            )
        )
        -- Collaborators can see items
        OR EXISTS (
            SELECT 1 FROM goal_collaborators gc
            WHERE gc.goal_id = g.id
            AND gc.user_id = auth.uid()
            AND gc.status = 'accepted'
        )
    )
    ORDER BY gi.created_at ASC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_visible_goal_items(UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_visible_goal_items(UUID[]) TO anon;











