-- Add private visibility option to goal_visibility enum
-- Private goals are only visible to the owner

-- Add 'private' value to enum (if not already exists)
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

-- RLS Policy: Users can view their own private goals
CREATE POLICY IF NOT EXISTS "Users can view their own private goals"
    ON goals FOR SELECT
    USING (visibility = 'private' AND owner_id = auth.uid());

-- Note: Private goals are automatically excluded from public/friends feeds
-- because the existing policies only allow:
-- 1. Public goals (visibility = 'public')
-- 2. Own goals (owner_id = auth.uid())
-- 3. Friends' goals (visibility = 'friends' AND friendship exists)
-- 4. Custom goals (visibility = 'custom' AND user in ACL)
-- Private goals will only be visible through the "own goals" policy









