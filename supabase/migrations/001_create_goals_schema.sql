-- Migration: Create goals schema with RLS
-- This creates the goals table and related tables per backend.md specification

-- Create enum types
CREATE TYPE goal_status AS ENUM ('active', 'completed', 'archived');
CREATE TYPE goal_visibility AS ENUM ('public', 'friends', 'custom');
CREATE TYPE friendship_status AS ENUM ('pending', 'accepted', 'blocked');

-- Friendships table (for friends-only visibility)
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id_1 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id_2 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status friendship_status NOT NULL DEFAULT 'pending',
    established_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id_1, user_id_2),
    CHECK (user_id_1 != user_id_2)
);

-- Goals table (core table - goals are posts)
CREATE TABLE goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT,
    status goal_status NOT NULL DEFAULT 'active',
    visibility goal_visibility NOT NULL DEFAULT 'public',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Goal ACL table (for custom visibility)
CREATE TABLE goal_acl (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'viewer', -- 'viewer' or 'editor'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(goal_id, user_id)
);

-- Goal items table (optional subgoals/checklist items)
CREATE TABLE goal_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_friendships_user_1 ON friendships(user_id_1);
CREATE INDEX idx_friendships_user_2 ON friendships(user_id_2);
CREATE INDEX idx_friendships_status ON friendships(status);
CREATE INDEX idx_goals_owner_id ON goals(owner_id);
CREATE INDEX idx_goals_visibility ON goals(visibility);
CREATE INDEX idx_goals_created_at ON goals(created_at DESC);
CREATE INDEX idx_goal_acl_goal_id ON goal_acl(goal_id);
CREATE INDEX idx_goal_acl_user_id ON goal_acl(user_id);
CREATE INDEX idx_goal_items_goal_id ON goal_items(goal_id);

-- Enable Row Level Security
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE goal_acl ENABLE ROW LEVEL SECURITY;
ALTER TABLE goal_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for friendships table

-- SELECT: Users can see friendships they're involved in
CREATE POLICY "Users can view their friendships"
    ON friendships FOR SELECT
    USING (user_id_1 = auth.uid() OR user_id_2 = auth.uid());

-- INSERT: Users can create friendship requests
CREATE POLICY "Users can create friendship requests"
    ON friendships FOR INSERT
    WITH CHECK (user_id_1 = auth.uid());

-- UPDATE: Users can accept/decline requests where they are user_id_2
CREATE POLICY "Users can update received friendship requests"
    ON friendships FOR UPDATE
    USING (user_id_2 = auth.uid())
    WITH CHECK (user_id_2 = auth.uid());

-- DELETE: Users can delete their own friendship requests (user_id_1) or remove friendships
CREATE POLICY "Users can delete their friendships"
    ON friendships FOR DELETE
    USING (user_id_1 = auth.uid() OR user_id_2 = auth.uid());

-- RLS Policies for goals table

-- SELECT: Users can see goals if:
-- 1. Visibility is 'public'
-- 2. User is the owner
-- 3. Visibility is 'friends' and user is a friend of owner
-- 4. Visibility is 'custom' and user is in goal_acl
CREATE POLICY "Users can view public goals"
    ON goals FOR SELECT
    USING (visibility = 'public');

CREATE POLICY "Users can view their own goals"
    ON goals FOR SELECT
    USING (owner_id = auth.uid());

CREATE POLICY "Users can view friends' goals"
    ON goals FOR SELECT
    USING (
        visibility = 'friends' AND
        EXISTS (
            SELECT 1 FROM friendships
            WHERE (user_id_1 = auth.uid() AND user_id_2 = goals.owner_id)
               OR (user_id_1 = goals.owner_id AND user_id_2 = auth.uid())
            AND status = 'accepted'
        )
    );

CREATE POLICY "Users can view custom visibility goals they're in ACL"
    ON goals FOR SELECT
    USING (
        visibility = 'custom' AND
        EXISTS (
            SELECT 1 FROM goal_acl
            WHERE goal_acl.goal_id = goals.id
            AND goal_acl.user_id = auth.uid()
        )
    );

-- INSERT: Only authenticated users can create goals, and owner_id must be their own
CREATE POLICY "Users can create their own goals"
    ON goals FOR INSERT
    WITH CHECK (owner_id = auth.uid());

-- UPDATE: Only owners can update their goals
CREATE POLICY "Users can update their own goals"
    ON goals FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- DELETE: Only owners can delete their goals
CREATE POLICY "Users can delete their own goals"
    ON goals FOR DELETE
    USING (owner_id = auth.uid());

-- RLS Policies for goal_acl table

-- SELECT: Users can see ACL entries for goals they own or entries where they are the user
CREATE POLICY "Users can view ACL for their goals"
    ON goal_acl FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM goals
            WHERE goals.id = goal_acl.goal_id
            AND goals.owner_id = auth.uid()
        )
    );

CREATE POLICY "Users can view their own ACL entries"
    ON goal_acl FOR SELECT
    USING (user_id = auth.uid());

-- INSERT: Only goal owners can add ACL entries
CREATE POLICY "Goal owners can add ACL entries"
    ON goal_acl FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM goals
            WHERE goals.id = goal_acl.goal_id
            AND goals.owner_id = auth.uid()
        )
    );

-- DELETE: Only goal owners can remove ACL entries
CREATE POLICY "Goal owners can delete ACL entries"
    ON goal_acl FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM goals
            WHERE goals.id = goal_acl.goal_id
            AND goals.owner_id = auth.uid()
        )
    );

-- RLS Policies for goal_items table

-- SELECT: Users can see items if they can see the parent goal
CREATE POLICY "Users can view items for visible goals"
    ON goal_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM goals
            WHERE goals.id = goal_items.goal_id
            AND (
                goals.visibility = 'public'
                OR goals.owner_id = auth.uid()
                OR (goals.visibility = 'friends' AND EXISTS (
                    SELECT 1 FROM friendships
                    WHERE (user_id_1 = auth.uid() AND user_id_2 = goals.owner_id)
                       OR (user_id_1 = goals.owner_id AND user_id_2 = auth.uid())
                    AND status = 'accepted'
                ))
                OR (goals.visibility = 'custom' AND EXISTS (
                    SELECT 1 FROM goal_acl
                    WHERE goal_acl.goal_id = goals.id
                    AND goal_acl.user_id = auth.uid()
                ))
            )
        )
    );

-- INSERT/UPDATE/DELETE: Only goal owners or editors can modify items
CREATE POLICY "Goal owners can manage items"
    ON goal_items FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM goals
            WHERE goals.id = goal_items.goal_id
            AND goals.owner_id = auth.uid()
        )
    );

CREATE POLICY "Goal editors can manage items"
    ON goal_items FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM goals
            JOIN goal_acl ON goal_acl.goal_id = goals.id
            WHERE goals.id = goal_items.goal_id
            AND goal_acl.user_id = auth.uid()
            AND goal_acl.role = 'editor'
        )
    );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-update updated_at on goals
CREATE TRIGGER update_goals_updated_at
    BEFORE UPDATE ON goals
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to auto-update updated_at on goal_items
CREATE TRIGGER update_goal_items_updated_at
    BEFORE UPDATE ON goal_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

