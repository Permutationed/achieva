-- Migration: Cleanup legacy proposed goals
-- This migration is a no-op since migration 033 already converted all 'proposed' goals to 'active'
-- and removed 'proposed' from the goal_status enum.
-- 
-- The Swift decoder in Models/Goal.swift handles any edge cases by mapping 'proposed' to 'active'
-- for backward compatibility with any data that might have been created before migrations ran.

-- No SQL needed - migration 033 already handled the cleanup

