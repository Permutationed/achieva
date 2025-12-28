-- Migration: Add goal_publish_proposal to message_type enum
-- This allows messages to reference publish proposals for collaborative goals

-- Add 'goal_publish_proposal' to message_type enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'goal_publish_proposal' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'message_type')) THEN
        ALTER TYPE message_type ADD VALUE 'goal_publish_proposal';
    END IF;
END $$;


