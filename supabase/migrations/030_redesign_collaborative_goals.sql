-- Migration: Redesign Collaborative Goals - DM-First
-- 1. Update goal_status enum
-- 2. Update goals table
-- 3. Update RLS policies

-- ==========================================
-- 1. ENUM UPDATES
-- ==========================================

-- Adding 'proposed' to goal_status
ALTER TYPE goal_status ADD VALUE IF NOT EXISTS 'proposed';

-- Adding 'private' to goal_visibility (ensuring it exists if previous migrations were skipped)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum 
        WHERE enumlabel = 'private' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'goal_visibility')
    ) THEN
        ALTER TYPE goal_visibility ADD VALUE 'private';
    END IF;
END $$;

-- ==========================================
-- 2. TABLE UPDATES
-- ==========================================

-- Add conversation_id to link goals to DM threads
ALTER TABLE goals 
ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL;

-- Add proposed_note for initial context
ALTER TABLE goals
ADD COLUMN IF NOT EXISTS proposed_note TEXT;

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_goals_conversation_id ON goals(conversation_id);

-- ==========================================
-- 3. RLS UPDATES
-- ==========================================

-- Allow participants of the linked conversation to view proposed goals
-- This is necessary so the recipient can see the proposal card in chat
-- NOTE: We cast 'status' to text because Postgres doesn't allow using a new enum value 
-- in the same transaction it was added for type-checked comparisons.
DROP POLICY IF EXISTS "Users can view proposed goals in their conversations" ON goals;
CREATE POLICY "Users can view proposed goals in their conversations"
    ON goals FOR SELECT
    TO authenticated
    USING (
        status::text = 'proposed'
        AND conversation_id IN (
            SELECT id FROM conversations -- Fixed subquery to check participant membership correctly
            WHERE id IN (
                SELECT cp.conversation_id FROM conversation_participants cp
                WHERE cp.user_id = auth.uid()
            )
        )
    );

-- Allow participants to potentially update a proposed goal (accept/pass logic will be in functions/Rethink later if needed)
-- For now, we'll handle the state transition via service calls or a dedicated function.

-- Ensure that conversation participants can also see the goal once it's active
-- This complements the existing collaborator policy
DROP POLICY IF EXISTS "Users can view active goals in their conversations" ON goals;
CREATE POLICY "Users can view active goals in their conversations"
    ON goals FOR SELECT
    TO authenticated
    USING (
        conversation_id IN (
            SELECT conversation_id FROM conversation_participants
            WHERE user_id = auth.uid()
        )
    );

-- ==========================================
-- 4. GOAL_COLLABORATORS RLS UPDATES
-- ==========================================

-- Redefine goal_collaborators INSERT policy to allow adding conversation participants
-- This is needed for collaborative goals proposed in a DM
DROP POLICY IF EXISTS "Goal owners can invite friends as collaborators" ON goal_collaborators;
CREATE POLICY "Goal owners can invite conversation participants"
    ON goal_collaborators FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_collaborators.goal_id
            AND g.owner_id = auth.uid()
        )
        AND goal_collaborators.invited_by = auth.uid()
        AND (
            -- Either a friend (legacy flow)
            are_users_friends(auth.uid(), goal_collaborators.user_id)
            -- Or a participant in the same conversation (new DM-first flow)
            OR EXISTS (
                SELECT 1 FROM goals g
                JOIN conversation_participants cp ON g.conversation_id = cp.conversation_id
                WHERE g.id = goal_collaborators.goal_id
                AND cp.user_id = goal_collaborators.user_id
            )
        )
    );
