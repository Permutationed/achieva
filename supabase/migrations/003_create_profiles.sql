-- Migration: Create profiles table per backend.md
-- Profiles store public-facing identity (username, display_name, date_of_birth)
-- Each authenticated user has exactly one profile row

-- Create profiles table
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    date_of_birth DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_profiles_username ON profiles(username);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles table

-- SELECT: Authenticated users can read all profiles (public profiles)
CREATE POLICY "Users can view profiles"
    ON profiles FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- INSERT: Users can only create their own profile (id must match auth.uid())
CREATE POLICY "Users can create their own profile"
    ON profiles FOR INSERT
    WITH CHECK (id = auth.uid());

-- UPDATE: Users can only update their own profile
CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-update updated_at on profiles
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_profiles_updated_at();


