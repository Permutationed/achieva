-- Migration: Update profiles schema
-- Changes:
-- 1. Split display_name into first_name and last_name
-- 2. Make date_of_birth NOT NULL (mandatory)
-- 3. Username already has UNIQUE constraint (no change needed)

-- Step 1: Add new columns (nullable initially for data migration)
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS first_name TEXT,
    ADD COLUMN IF NOT EXISTS last_name TEXT;

-- Step 2: Migrate existing display_name data
-- Split display_name on first space: first word -> first_name, remainder -> last_name
-- If no space found, use entire string as first_name and empty string as last_name
UPDATE profiles
SET 
    first_name = CASE 
        WHEN position(' ' IN display_name) > 0 THEN
            substring(display_name FROM 1 FOR position(' ' IN display_name) - 1)
        ELSE
            display_name
    END,
    last_name = CASE
        WHEN position(' ' IN display_name) > 0 THEN
            substring(display_name FROM position(' ' IN display_name) + 1)
        ELSE
            ''
    END
WHERE first_name IS NULL OR last_name IS NULL;

-- Step 3: Set default values for any remaining NULL values
UPDATE profiles
SET 
    first_name = COALESCE(first_name, 'User'),
    last_name = COALESCE(last_name, '')
WHERE first_name IS NULL OR last_name IS NULL;

-- Step 4: Make first_name and last_name NOT NULL
ALTER TABLE profiles
    ALTER COLUMN first_name SET NOT NULL,
    ALTER COLUMN last_name SET NOT NULL;

-- Step 5: Set default date_of_birth for existing NULL values (use a reasonable default)
-- Using 2000-01-01 as default, but you may want to adjust this
UPDATE profiles
SET date_of_birth = '2000-01-01'::DATE
WHERE date_of_birth IS NULL;

-- Step 6: Make date_of_birth NOT NULL
ALTER TABLE profiles
    ALTER COLUMN date_of_birth SET NOT NULL;

-- Step 7: Drop the old display_name column
ALTER TABLE profiles
    DROP COLUMN IF EXISTS display_name;

-- Step 8: Add indexes for the new columns (optional but recommended for queries)
CREATE INDEX IF NOT EXISTS idx_profiles_first_name ON profiles(first_name);
CREATE INDEX IF NOT EXISTS idx_profiles_last_name ON profiles(last_name);

-- Note: Username already has UNIQUE constraint from migration 003, so no change needed there









