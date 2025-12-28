-- Migration: Remove Collaborative Goals System
-- This migration deletes all collaborative goals and removes the collaborative goal schema

-- ==========================================
-- 1. DELETE COLLABORATIVE GOALS DATA
-- ==========================================

-- Delete goal_items for goals that will be deleted
DELETE FROM goal_items
WHERE goal_id IN (
    SELECT id FROM goals WHERE status::text = 'proposed'
    UNION
    SELECT goal_id FROM goal_collaborators
);

-- Delete goal_acl for goals that will be deleted
DELETE FROM goal_acl
WHERE goal_id IN (
    SELECT id FROM goals WHERE status::text = 'proposed'
    UNION
    SELECT goal_id FROM goal_collaborators
);

-- Delete goals with 'proposed' status
DELETE FROM goals WHERE status::text = 'proposed';

-- Delete goals that have collaborators
DELETE FROM goals
WHERE id IN (SELECT DISTINCT goal_id FROM goal_collaborators);

-- ==========================================
-- 2. DROP COLLABORATIVE GOAL TABLES AND ENUMS
-- ==========================================

-- Drop goal_collaborators table (CASCADE will handle foreign keys)
DROP TABLE IF EXISTS goal_collaborators CASCADE;

-- Drop collaboration_status enum
DROP TYPE IF EXISTS collaboration_status CASCADE;

-- Remove 'proposed' from goal_status enum
-- PostgreSQL doesn't support removing enum values directly, so we need to recreate the enum
DO $$
BEGIN
    -- Check if 'proposed' exists in the enum
    IF EXISTS (
        SELECT 1 FROM pg_enum 
        WHERE enumlabel = 'proposed' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'goal_status')
    ) THEN
        -- Create a new enum without 'proposed'
        CREATE TYPE goal_status_new AS ENUM ('active', 'completed', 'archived');
        
        -- Update goals table to use new enum
        ALTER TABLE goals 
            ALTER COLUMN status TYPE goal_status_new 
            USING CASE 
                WHEN status::text = 'proposed' THEN 'active'::goal_status_new
                ELSE status::text::goal_status_new
            END;
        
        -- Drop old enum and rename new one
        DROP TYPE goal_status;
        ALTER TYPE goal_status_new RENAME TO goal_status;
    END IF;
END $$;

-- ==========================================
-- 3. REMOVE COLLABORATIVE COLUMNS FROM GOALS
-- ==========================================

-- Remove conversation_id column
ALTER TABLE goals DROP COLUMN IF EXISTS conversation_id;

-- Remove approved_by column (if it exists as a column, not just in model)
ALTER TABLE goals DROP COLUMN IF EXISTS approved_by;

-- Remove proposed_note column
ALTER TABLE goals DROP COLUMN IF EXISTS proposed_note;

-- Drop related indexes
DROP INDEX IF EXISTS idx_goals_conversation_id;

-- ==========================================
-- 4. REMOVE HELPER FUNCTIONS
-- ==========================================

DROP FUNCTION IF EXISTS are_users_friends(UUID, UUID);
DROP FUNCTION IF EXISTS get_goal_accepted_collaborators(UUID);
DROP FUNCTION IF EXISTS is_user_goal_collaborator(UUID, UUID);

-- ==========================================
-- 5. UPDATE RLS POLICIES
-- ==========================================

-- Remove collaborator-related policies from goals table
DROP POLICY IF EXISTS "Users can view goals they collaborate on" ON goals;
DROP POLICY IF EXISTS "Users can view proposed goals in their conversations" ON goals;
DROP POLICY IF EXISTS "Users can view active goals in their conversations" ON goals;

-- Restore original "Users can update their own goals" policy (owner only)
DROP POLICY IF EXISTS "Users can update their own goals" ON goals;
CREATE POLICY "Users can update their own goals"
    ON goals FOR UPDATE
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- Update goal_items RLS to only allow owners (remove collaborator access)
DROP POLICY IF EXISTS "Goal owners and collaborators can manage items" ON goal_items;
DROP POLICY IF EXISTS "Goal owners can manage items" ON goal_items;
DROP POLICY IF EXISTS "Goal editors can manage items" ON goal_items;

-- Restore owner-only policy for goal_items
CREATE POLICY "Goal owners can manage items"
    ON goal_items FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_items.goal_id
            AND g.owner_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM goals g
            WHERE g.id = goal_items.goal_id
            AND g.owner_id = auth.uid()
        )
    );

-- Remove collaborator-related policies from goal_collaborators (table already dropped, but clean up if migration is re-run)
DROP POLICY IF EXISTS "Users can view their collaboration requests" ON goal_collaborators;
DROP POLICY IF EXISTS "Goal owners can invite friends as collaborators" ON goal_collaborators;
DROP POLICY IF EXISTS "Goal owners can invite conversation participants" ON goal_collaborators;
DROP POLICY IF EXISTS "Invited users can update their collaboration requests" ON goal_collaborators;
DROP POLICY IF EXISTS "Users can delete collaboration requests" ON goal_collaborators;


