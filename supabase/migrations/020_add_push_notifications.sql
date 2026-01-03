-- Migration: Add push notifications support
-- Creates user_devices table to store device tokens for push notifications

-- Create user_devices table
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, device_token)
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);

-- Create index on device_token for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_device_token ON user_devices(device_token);

-- Enable RLS
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own device tokens
CREATE POLICY "Users can view their own device tokens"
    ON user_devices
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own device tokens
CREATE POLICY "Users can insert their own device tokens"
    ON user_devices
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own device tokens
CREATE POLICY "Users can update their own device tokens"
    ON user_devices
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own device tokens
CREATE POLICY "Users can delete their own device tokens"
    ON user_devices
    FOR DELETE
    USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER update_user_devices_updated_at
    BEFORE UPDATE ON user_devices
    FOR EACH ROW
    EXECUTE FUNCTION update_user_devices_updated_at();









