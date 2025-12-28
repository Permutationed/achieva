-- Migration: Add likes system for goals
-- This allows users to like goals they can view

-- Create goal_likes table
CREATE TABLE goal_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(goal_id, user_id) -- Prevent duplicate likes
);

-- Create indexes for performance
CREATE INDEX idx_goal_likes_goal_id ON goal_likes(goal_id);
CREATE INDEX idx_goal_likes_user_id ON goal_likes(user_id);
CREATE INDEX idx_goal_likes_created_at ON goal_likes(created_at DESC);

-- Enable Row Level Security
ALTER TABLE goal_likes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for goal_likes table

-- SELECT: Users can see likes on goals they can view
-- This uses the can_read_goal function to ensure visibility rules are respected
CREATE POLICY "Users can view likes on visible goals"
    ON goal_likes FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM goals
            WHERE goals.id = goal_likes.goal_id
            AND can_read_goal(goals.id)
        )
    );

-- INSERT: Users can like goals they can view (and haven't already liked)
-- The UNIQUE constraint prevents duplicate likes, but we check visibility here
CREATE POLICY "Users can like visible goals"
    ON goal_likes FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM goals
            WHERE goals.id = goal_likes.goal_id
            AND can_read_goal(goals.id)
        )
    );

-- DELETE: Users can unlike their own likes
CREATE POLICY "Users can unlike their own likes"
    ON goal_likes FOR DELETE
    USING (user_id = auth.uid());

-- Function to get likes count for a goal
CREATE OR REPLACE FUNCTION get_goal_likes_count(p_goal_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    likes_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO likes_count
    FROM goal_likes
    WHERE goal_id = p_goal_id;
    
    RETURN COALESCE(likes_count, 0);
END;
$$;

-- Function to check if current user has liked a goal
CREATE OR REPLACE FUNCTION has_user_liked_goal(p_goal_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM goal_likes
        WHERE goal_id = p_goal_id
        AND user_id = p_user_id
    );
END;
$$;



