-- Migration: Auto-create profile when new user signs up
-- This ensures that OAuth users (Google, Apple) automatically get a profile created
-- so they can use the app immediately

-- Function to automatically create a profile when a new user is created
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_username TEXT;
    user_email TEXT;
    username_base TEXT;
    counter INTEGER := 0;
BEGIN
    -- Only create profile if it doesn't already exist
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
        -- Get email from auth.users
        user_email := NEW.email;
        
        -- Generate a unique username from email or user ID
        -- Try to use email prefix (before @), fallback to user ID
        IF user_email IS NOT NULL AND position('@' IN user_email) > 0 THEN
            username_base := lower(substring(user_email FROM 1 FOR position('@' IN user_email) - 1));
            -- Remove any non-alphanumeric characters
            username_base := regexp_replace(username_base, '[^a-z0-9]', '', 'g');
            -- Limit length
            IF length(username_base) > 20 THEN
                username_base := substring(username_base FROM 1 FOR 20);
            END IF;
        ELSE
            -- Fallback: use first 8 characters of UUID (without hyphens)
            username_base := lower(regexp_replace(NEW.id::text, '-', '', 'g'));
            username_base := substring(username_base FROM 1 FOR 8);
        END IF;
        
        -- Ensure username is not empty
        IF username_base IS NULL OR username_base = '' THEN
            username_base := 'user';
        END IF;
        
        -- Generate unique username by appending numbers if needed
        new_username := username_base;
        WHILE EXISTS (SELECT 1 FROM profiles WHERE username = new_username) LOOP
            counter := counter + 1;
            new_username := username_base || counter::text;
        END LOOP;
        
        -- Insert profile with default values
        -- User will need to complete their profile during onboarding
        INSERT INTO profiles (
            id,
            username,
            first_name,
            last_name,
            date_of_birth,
            avatar_url,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,
            new_username,
            'User',  -- Default first name
            '',      -- Default last name (empty)
            '2000-01-01'::DATE,  -- Default date of birth
            NULL,    -- No avatar initially
            NOW(),
            NOW()
        );
        
        RAISE NOTICE 'Auto-created profile for user % with username %', NEW.id, new_username;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on auth.users to auto-create profile
-- This fires AFTER a new user is inserted
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- Note: This trigger will automatically create profiles for:
-- 1. Email/password signups (via signUp)
-- 2. OAuth signups (Google, Apple, etc.)
-- 3. Any other method that creates a user in auth.users
