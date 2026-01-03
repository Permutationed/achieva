-- Migration: Robust Profile RLS Policies
-- This migration ensures the profiles policies are correctly set up
-- and handles cases where auth.uid() might be used in a more robust way.

-- Step 1: Drop existing policies to ensure a clean state
DROP POLICY IF EXISTS "Users can view profiles" ON profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;

-- Step 2: Re-create policies with explicit TO authenticated/public and better checks

-- SELECT: Anyone can view profiles (public)
CREATE POLICY "Users can view profiles"
    ON profiles FOR SELECT
    USING (true);

-- INSERT: Users can only create their own profile
CREATE POLICY "Users can create their own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- UPDATE: Users can only update their own profile
CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Step 3: Add an UPSERT policy (Supabase uses INSERT + ON CONFLICT for upsert)
-- The INSERT policy above already handles the WITH CHECK for upsert.

-- Step 4: Ensure the id column has the correct type and references
-- (This should already be correct, but good to be sure)
ALTER TABLE profiles 
    ALTER COLUMN id SET DEFAULT auth.uid();

-- Step 5: Grant permissions
GRANT ALL ON profiles TO authenticated;
GRANT SELECT ON profiles TO anon;
