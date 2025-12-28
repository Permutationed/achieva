-- Migration: Add comments system for goals
-- This allows users to comment on goals they can view

-- Create goal_comments table
CREATE TABLE goal_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_goal_comments_goal_id ON goal_comments(goal_id);
CREATE INDEX idx_goal_comments_user_id ON goal_comments(user_id);
CREATE INDEX idx_goal_comments_created_at ON goal_comments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE goal_comments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for goal_comments table

-- SELECT: Users can see comments on goals they can view
-- This uses the can_read_goal function to ensure visibility rules are respected
CREATE POLICY "Users can view comments on visible goals"
    ON goal_comments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM goals
            WHERE goals.id = goal_comments.goal_id
            AND can_read_goal(goals.id)
        )
    );

-- INSERT: Users can comment on goals they can view
CREATE POLICY "Users can comment on visible goals"
    ON goal_comments FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM goals
            WHERE goals.id = goal_comments.goal_id
            AND can_read_goal(goals.id)
        )
    );

-- UPDATE: Users can edit their own comments
CREATE POLICY "Users can update their own comments"
    ON goal_comments FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- DELETE: Users can delete their own comments
CREATE POLICY "Users can delete their own comments"
    ON goal_comments FOR DELETE
    USING (user_id = auth.uid());

-- Trigger to auto-update updated_at on goal_comments
CREATE TRIGGER update_goal_comments_updated_at
    BEFORE UPDATE ON goal_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Note: Realtime must be enabled manually in Supabase Dashboard:
-- 1. Go to Database → Replication
-- 2. Find goal_comments table
-- 3. Toggle "Enable Realtime" to ON



