-- Migration: Add goal_proposal and goal_event to message_type enum
-- This allows messages to reference proposed goals and goal events
-- Note: PostgreSQL doesn't support IF NOT EXISTS for ALTER TYPE ADD VALUE
-- If these values already exist, this migration will fail - that's expected behavior
-- Run manually if needed: DO $$ BEGIN ... END $$;

-- Add 'goal_proposal' to message_type enum
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'goal_proposal' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'message_type')) THEN
        ALTER TYPE message_type ADD VALUE 'goal_proposal';
    END IF;
END $$;

-- Add 'goal_event' to message_type enum
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'goal_event' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'message_type')) THEN
        ALTER TYPE message_type ADD VALUE 'goal_event';
    END IF;
END $$;

