-- Migration: Create Goal Tags System
-- This migration creates the goal_tags table for tagging friends in goals

-- ==========================================
-- 1. CREATE GOAL_TAGS TABLE
-- ==========================================

CREATE TABLE goal_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(goal_id, user_id)
);

-- ==========================================
-- 2. CREATE INDEXES
-- ==========================================

CREATE INDEX idx_goal_tags_goal_id ON goal_tags(goal_id);
CREATE INDEX idx_goal_tags_user_id ON goal_tags(user_id);
CREATE INDEX idx_goal_tags_conversation_id ON goal_tags(conversation_id);

-- ==========================================
-- 3. ENABLE RLS
-- ==========================================

ALTER TABLE goal_tags ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 4. CREATE RLS POLICIES
-- ==========================================

-- SELECT: Users can view tags for goals they own or where they are tagged
CREATE POLICY "Users can view tags for their goals or where tagged"
    ON goal_tags FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_tags.goal_id
            AND g.owner_id = auth.uid()
        )
        OR goal_tags.user_id = auth.uid()
    );

-- INSERT: Goal owners can create tags (must be friends with tagged user)
CREATE POLICY "Goal owners can tag friends"
    ON goal_tags FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_tags.goal_id
            AND g.owner_id = auth.uid()
        )
        AND goal_tags.user_id != auth.uid() -- Cannot tag yourself
        AND EXISTS (
            -- Check if users are friends
            SELECT 1 FROM friendships
            WHERE (
                (user_id_1 = auth.uid() AND user_id_2 = goal_tags.user_id)
                OR (user_id_1 = goal_tags.user_id AND user_id_2 = auth.uid())
            )
            AND status = 'accepted'
        )
    );

-- DELETE: Goal owners can delete tags
CREATE POLICY "Goal owners can delete tags"
    ON goal_tags FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_tags.goal_id
            AND g.owner_id = auth.uid()
        )
    );

-- ==========================================
-- 5. UPDATE GOALS RLS POLICIES
-- ==========================================

-- Add policy: "Users can view goals where they are tagged"
-- This allows tagged users to see goals in their feed
CREATE POLICY "Users can view goals where they are tagged"
    ON goals FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM goal_tags
            WHERE goal_tags.goal_id = goals.id
            AND goal_tags.user_id = auth.uid()
        )
    );


