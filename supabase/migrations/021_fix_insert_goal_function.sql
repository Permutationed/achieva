-- Fix insert_goal function to ensure it has the correct signature with p_is_draft
-- This migration ensures the function matches what the Swift client expects

-- Drop the function if it exists (to handle any old versions)
DROP FUNCTION IF EXISTS insert_goal(TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS insert_goal(TEXT, TEXT, TEXT, TEXT, UUID, BOOLEAN);

-- Create the function with the correct signature
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
    VALUES (p_owner_id, p_title, p_body, p_status::goal_status, p_visibility::goal_visibility, COALESCE(p_is_draft, false))
    RETURNING id INTO new_goal_id;
    
    RETURN new_goal_id;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION insert_goal(TEXT, TEXT, TEXT, TEXT, UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_goal(TEXT, TEXT, TEXT, TEXT, UUID, BOOLEAN) TO anon;









