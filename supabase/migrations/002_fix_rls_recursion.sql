-- Migration: Fix RLS recursion between goals and goal_acl
--
-- Symptom:
--   "infinite recursion detected in policy for relation \"goals\""
--
-- Cause:
--   goals SELECT policy checks membership via goal_acl,
--   but goal_acl policies also query goals to check ownership.
--   This creates a recursive policy dependency.
--
-- Fix:
--   Remove goal_acl policies that query goals. Keep only a self-contained
--   policy that allows users to read their own ACL rows (user_id = auth.uid()).
--   Also tighten AND/OR precedence in friends/custom goal visibility policies.

-- ===== goal_acl: drop recursive policies =====
DROP POLICY IF EXISTS "Users can view ACL for their goals" ON goal_acl;
DROP POLICY IF EXISTS "Goal owners can add ACL entries" ON goal_acl;
DROP POLICY IF EXISTS "Goal owners can delete ACL entries" ON goal_acl;

-- Recreate the safe, non-recursive policy.
DROP POLICY IF EXISTS "Users can view their own ACL entries" ON goal_acl;
CREATE POLICY "Users can view their own ACL entries"
  ON goal_acl
  FOR SELECT
  USING (user_id = auth.uid());

-- NOTE:
-- We intentionally do NOT recreate insert/delete policies for goal_acl here.
-- Those ownership checks require querying goals and would reintroduce recursion.

-- ===== goals: tighten policies (no recursion) =====
DROP POLICY IF EXISTS "Users can view friends' goals" ON goals;
CREATE POLICY "Users can view friends' goals"
  ON goals
  FOR SELECT
  USING (
    visibility = 'friends'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM friendships
      WHERE (
        (user_id_1 = auth.uid() AND user_id_2 = goals.owner_id)
        OR (user_id_1 = goals.owner_id AND user_id_2 = auth.uid())
      )
      AND status = 'accepted'
    )
  );

DROP POLICY IF EXISTS "Users can view custom visibility goals they're in ACL" ON goals;
CREATE POLICY "Users can view custom visibility goals they're in ACL"
  ON goals
  FOR SELECT
  USING (
    visibility = 'custom'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM goal_acl
      WHERE goal_acl.goal_id = goals.id
        AND goal_acl.user_id = auth.uid()
    )
  );

-- ===== goal_items: tighten friends/custom checks to avoid precedence issues =====
DROP POLICY IF EXISTS "Users can view items for visible goals" ON goal_items;
CREATE POLICY "Users can view items for visible goals"
  ON goal_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM goals
      WHERE goals.id = goal_items.goal_id
        AND (
          goals.visibility = 'public'
          OR goals.owner_id = auth.uid()
          OR (
            goals.visibility = 'friends'
            AND auth.uid() IS NOT NULL
            AND EXISTS (
              SELECT 1
              FROM friendships
              WHERE (
                (user_id_1 = auth.uid() AND user_id_2 = goals.owner_id)
                OR (user_id_1 = goals.owner_id AND user_id_2 = auth.uid())
              )
              AND status = 'accepted'
            )
          )
          OR (
            goals.visibility = 'custom'
            AND auth.uid() IS NOT NULL
            AND EXISTS (
              SELECT 1
              FROM goal_acl
              WHERE goal_acl.goal_id = goals.id
                AND goal_acl.user_id = auth.uid()
            )
          )
        )
    )
  );



