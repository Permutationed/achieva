-- Migration: Create test user account
-- Creates a mock account with email test@gmail.com and password 123456
-- This is for development/testing purposes only

-- Enable pgcrypto extension for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Function to create a test user
-- This function bypasses RLS to create the user and profile
CREATE OR REPLACE FUNCTION create_test_user()
RETURNS UUID AS $$
DECLARE
    user_id UUID;
    user_email TEXT := 'test@gmail.com';
    user_password TEXT := '123456';
    hashed_password TEXT;
    instance_uuid UUID;
BEGIN
    -- Check if user already exists
    SELECT id INTO user_id FROM auth.users WHERE email = user_email;
    
    IF user_id IS NOT NULL THEN
        RAISE NOTICE 'User with email % already exists with ID: %', user_email, user_id;
        -- Still create profile if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = user_id) THEN
            INSERT INTO profiles (
                id, username, first_name, last_name, date_of_birth, created_at, updated_at
            ) VALUES (
                user_id, 'testuser', 'Test', 'User', '2000-01-01'::DATE, NOW(), NOW()
            );
            RAISE NOTICE 'Profile created for existing user';
        END IF;
        RETURN user_id;
    END IF;

    -- Get the instance_id from an existing user, or use a default
    SELECT instance_id INTO instance_uuid FROM auth.users LIMIT 1;
    IF instance_uuid IS NULL THEN
        -- If no users exist, we'll need to get it from auth.instances or use a default
        -- For Supabase, this is typically the project's instance UUID
        -- We'll try to get it from auth.instances table
        SELECT id INTO instance_uuid FROM auth.instances LIMIT 1;
        IF instance_uuid IS NULL THEN
            -- Fallback: use a placeholder (this might need adjustment for your Supabase project)
            instance_uuid := '00000000-0000-0000-0000-000000000000'::uuid;
        END IF;
    END IF;

    -- Generate a new UUID for the user
    user_id := gen_random_uuid();
    
    -- Hash the password using bcrypt (Supabase uses bcrypt with cost factor 10)
    hashed_password := crypt(user_password, gen_salt('bf', 10));
    
    -- Insert into auth.users
    -- SECURITY DEFINER allows this function to bypass RLS
    -- Only include required fields and let defaults handle the rest
    INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        raw_app_meta_data,
        raw_user_meta_data,
        is_super_admin,
        role,
        aud
    ) VALUES (
        user_id,
        instance_uuid,
        user_email,
        hashed_password,
        NOW(), -- Email confirmed immediately for test account
        NOW(),
        NOW(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        '{}'::jsonb,
        false,
        'authenticated',
        'authenticated'
    );

    -- Create corresponding profile entry
    -- SECURITY DEFINER allows bypassing RLS policies
    INSERT INTO profiles (
        id,
        username,
        first_name,
        last_name,
        date_of_birth,
        created_at,
        updated_at
    ) VALUES (
        user_id,
        'testuser', -- Username
        'Test', -- First name
        'User', -- Last name
        '2000-01-01'::DATE, -- Date of birth
        NOW(),
        NOW()
    );

    RAISE NOTICE 'Test user created successfully with ID: %', user_id;
    RETURN user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the function to create the test user
SELECT create_test_user();

-- Keep the function for future use (can be called manually if needed)
-- To drop: DROP FUNCTION IF EXISTS create_test_user();

