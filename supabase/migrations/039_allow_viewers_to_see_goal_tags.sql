-- Migration: Allow viewers to see goal tags
-- Currently, goal_tags RLS only allows owners and tagged users to see tags
-- This migration updates the policy to allow anyone who can view the goal to see its tags

-- Drop the existing policy
DROP POLICY IF EXISTS "Users can view tags for their goals or where tagged" ON goal_tags;

-- Create a new policy that allows viewing tags for any goal the user can view
-- This uses can_read_goal to check if the user has access to the goal
CREATE POLICY "Users can view tags for visible goals"
    ON goal_tags FOR SELECT
    USING (
        -- User can view the goal (uses can_read_goal function which checks all visibility rules)
        can_read_goal(goal_tags.goal_id)
    );








