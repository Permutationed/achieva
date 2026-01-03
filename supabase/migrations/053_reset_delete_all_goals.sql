-- Migration: Reset - Delete all goals and related data
-- WARNING: This will permanently delete ALL goals and related data
-- Use with caution - this action cannot be undone

DO $$ 
BEGIN
    -- Disable triggers temporarily to avoid cascading issues
    SET LOCAL session_replication_role = replica;

    -- Delete from child tables first (due to foreign key constraints)
    -- Even though we have ON DELETE CASCADE, we do this explicitly for clarity

    -- 1. Delete all goal tags
    DELETE FROM goal_tags;
    RAISE NOTICE 'Deleted all goal tags';

    -- 2. Delete all goal comments
    DELETE FROM goal_comments;
    RAISE NOTICE 'Deleted all goal comments';

    -- 3. Delete all goal likes
    DELETE FROM goal_likes;
    RAISE NOTICE 'Deleted all goal likes';

    -- 4. Delete all goal items (checklist items)
    DELETE FROM goal_items;
    RAISE NOTICE 'Deleted all goal items';

    -- 5. Delete all goal ACL entries (custom visibility permissions)
    DELETE FROM goal_acl;
    RAISE NOTICE 'Deleted all goal ACL entries';

    -- 6. Delete all goal collaborators (if table exists)
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'goal_collaborators') THEN
        DELETE FROM goal_collaborators;
        RAISE NOTICE 'Deleted all goal collaborators';
    END IF;

    -- 7. Delete notifications related to goals (goal tags and goal-related notifications)
    DELETE FROM notifications WHERE type = 'goal_tag';
    RAISE NOTICE 'Deleted all goal-related notifications';

    -- 8. Finally, delete all goals
    DELETE FROM goals;
    RAISE NOTICE 'Deleted all goals';

    -- Re-enable triggers
    SET LOCAL session_replication_role = DEFAULT;

    RAISE NOTICE 'All goals and related data have been deleted successfully';
END $$;

-- Note: VACUUM must be run separately outside of transactions
-- Run these commands manually if needed to reclaim space:
-- VACUUM ANALYZE goals;
-- VACUUM ANALYZE goal_items;
-- VACUUM ANALYZE goal_acl;
-- VACUUM ANALYZE goal_likes;
-- VACUUM ANALYZE goal_comments;
-- VACUUM ANALYZE goal_tags;
-- VACUUM ANALYZE notifications;
