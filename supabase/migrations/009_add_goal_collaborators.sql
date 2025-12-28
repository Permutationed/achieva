-- Migration: Add goal collaborators table and RLS policies
-- This enables collaborative bucketlist creation where users can invite friends as collaborators

-- Create enum type for collaboration status
CREATE TYPE collaboration_status AS ENUM ('pending', 'accepted', 'declined');

-- Create goal_collaborators table
CREATE TABLE goal_collaborators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status collaboration_status NOT NULL DEFAULT 'pending',
    invited_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(goal_id, user_id),
    CHECK (user_id != invited_by) -- Cannot invite yourself
);

-- Create indexes for performance
CREATE INDEX idx_goal_collaborators_goal_id ON goal_collaborators(goal_id);
CREATE INDEX idx_goal_collaborators_user_id ON goal_collaborators(user_id);
CREATE INDEX idx_goal_collaborators_status ON goal_collaborators(status);
CREATE INDEX idx_goal_collaborators_invited_by ON goal_collaborators(invited_by);

-- Enable Row Level Security
ALTER TABLE goal_collaborators ENABLE ROW LEVEL SECURITY;

-- Helper function: Check if two users are friends
CREATE OR REPLACE FUNCTION are_users_friends(user1_id UUID, user2_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM friendships
        WHERE (
            (user_id_1 = user1_id AND user_id_2 = user2_id)
            OR (user_id_1 = user2_id AND user_id_2 = user1_id)
        )
        AND status = 'accepted'
    );
END;
$$;

-- Helper function: Get accepted collaborator user IDs for a goal
CREATE OR REPLACE FUNCTION get_goal_accepted_collaborators(goal_uuid UUID)
RETURNS UUID[]
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    collaborator_ids UUID[];
BEGIN
    SELECT ARRAY_AGG(gc.user_id)
    INTO collaborator_ids
    FROM goal_collaborators gc
    WHERE gc.goal_id = goal_uuid
    AND gc.status = 'accepted';
    
    RETURN COALESCE(collaborator_ids, ARRAY[]::UUID[]);
END;
$$;

-- Helper function: Check if user is accepted collaborator
CREATE OR REPLACE FUNCTION is_user_goal_collaborator(goal_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM goal_collaborators gc
        WHERE gc.goal_id = goal_uuid
        AND gc.user_id = user_uuid
        AND gc.status = 'accepted'
    );
END;
$$;

-- RLS Policies for goal_collaborators table

-- SELECT: Users can see requests where they are the invited user, or goals they own
CREATE POLICY "Users can view their collaboration requests"
    ON goal_collaborators FOR SELECT
    USING (
        goal_collaborators.user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_collaborators.goal_id
            AND g.owner_id = auth.uid()
        )
    );

-- INSERT: Only goal owners can create collaboration requests, and must be friends
CREATE POLICY "Goal owners can invite friends as collaborators"
    ON goal_collaborators FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_collaborators.goal_id
            AND g.owner_id = auth.uid()
        )
        AND goal_collaborators.invited_by = auth.uid()
        AND are_users_friends(auth.uid(), goal_collaborators.user_id)
    );

-- UPDATE: Invited users can accept/decline their own requests
CREATE POLICY "Invited users can update their collaboration requests"
    ON goal_collaborators FOR UPDATE
    USING (goal_collaborators.user_id = auth.uid())
    WITH CHECK (goal_collaborators.user_id = auth.uid());

-- DELETE: Goal owners can delete requests; users can delete their declined requests
CREATE POLICY "Users can delete collaboration requests"
    ON goal_collaborators FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_collaborators.goal_id
            AND g.owner_id = auth.uid()
        )
        OR (goal_collaborators.user_id = auth.uid() AND goal_collaborators.status = 'declined')
    );

-- Update RLS policies for goals table to include accepted collaborators

-- UPDATE: Allow accepted collaborators to update goals (in addition to owner)
DROP POLICY IF EXISTS "Users can update their own goals" ON goals;
CREATE POLICY "Users can update their own goals"
    ON goals FOR UPDATE
    USING (
        owner_id = auth.uid()
        OR is_user_goal_collaborator(id, auth.uid())
    )
    WITH CHECK (
        owner_id = auth.uid()
        OR is_user_goal_collaborator(id, auth.uid())
    );

-- SELECT: Include goals where user is an accepted collaborator in "own goals" policy
-- Note: The existing "Users can view their own goals" policy already covers owner_id = auth.uid()
-- We'll add a separate policy for collaborators
CREATE POLICY "Users can view goals they collaborate on"
    ON goals FOR SELECT
    USING (
        is_user_goal_collaborator(id, auth.uid())
    );

-- Update RLS policies for goal_items table to allow accepted collaborators to manage items

-- Drop existing policies that only allow owners
DROP POLICY IF EXISTS "Goal owners can manage items" ON goal_items;
DROP POLICY IF EXISTS "Goal editors can manage items" ON goal_items;

-- INSERT/UPDATE/DELETE: Allow accepted collaborators to manage items (in addition to owner)
CREATE POLICY "Goal owners and collaborators can manage items"
    ON goal_items FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_items.goal_id
            AND (
                g.owner_id = auth.uid()
                OR is_user_goal_collaborator(g.id, auth.uid())
            )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_items.goal_id
            AND (
                g.owner_id = auth.uid()
                OR is_user_goal_collaborator(g.id, auth.uid())
            )
        )
    );

-- Trigger to auto-update updated_at on goal_collaborators
CREATE TRIGGER update_goal_collaborators_updated_at
    BEFORE UPDATE ON goal_collaborators
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

