-- Migration: Create notification triggers
-- Automatically creates notifications when messages are sent or users are tagged in goals

-- Function to create message notifications
CREATE OR REPLACE FUNCTION notify_message_sent()
RETURNS TRIGGER AS $$
DECLARE
    sender_profile profiles%ROWTYPE;
    conversation_participant RECORD;
    message_preview TEXT;
    notification_title TEXT;
BEGIN
    -- Get sender's profile
    SELECT * INTO sender_profile
    FROM profiles
    WHERE id = NEW.user_id;
    
    -- Create message preview
    IF NEW.text IS NOT NULL AND NEW.text != '' THEN
        -- Truncate long messages
        IF length(NEW.text) > 100 THEN
            message_preview := substring(NEW.text FROM 1 FOR 100) || '...';
        ELSE
            message_preview := NEW.text;
        END IF;
    ELSIF NEW.media_url IS NOT NULL THEN
        CASE NEW.message_type
            WHEN 'image' THEN message_preview := 'sent a photo';
            WHEN 'video' THEN message_preview := 'sent a video';
            WHEN 'audio' THEN message_preview := 'sent an audio message';
            WHEN 'file' THEN message_preview := 'sent a file';
            ELSE message_preview := 'sent a message';
        END CASE;
    ELSE
        message_preview := 'sent a message';
    END IF;
    
    -- Create notification title
    notification_title := COALESCE(sender_profile.first_name || ' ' || sender_profile.last_name, sender_profile.username, 'Someone') || ' sent you a message';
    
    -- Create notifications for all conversation participants except the sender
    FOR conversation_participant IN
        SELECT user_id, last_read_at
        FROM conversation_participants
        WHERE conversation_id = NEW.conversation_id
        AND user_id != NEW.user_id
    LOOP
        -- Only create notification if user hasn't read recent messages
        -- (avoid notifications for users actively viewing the conversation)
        -- Check if last_read_at is NULL or older than 30 seconds ago
        IF conversation_participant.last_read_at IS NULL 
           OR conversation_participant.last_read_at < (NOW() - INTERVAL '30 seconds') THEN
            PERFORM create_notification(
                p_user_id := conversation_participant.user_id,
                p_type := 'message',
                p_title := notification_title,
                p_body := message_preview,
                p_related_id := NEW.conversation_id
            );
        END IF;
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create notifications when messages are sent
CREATE TRIGGER trigger_notify_message_sent
    AFTER INSERT ON messages
    FOR EACH ROW
    WHEN (NEW.deleted_at IS NULL)
    EXECUTE FUNCTION notify_message_sent();

-- Function to create goal tag notifications
CREATE OR REPLACE FUNCTION notify_goal_tagged()
RETURNS TRIGGER AS $$
DECLARE
    tagger_profile profiles%ROWTYPE;
    goal_record goals%ROWTYPE;
    notification_title TEXT;
    notification_body TEXT;
BEGIN
    -- Skip if trying to tag self
    IF NEW.user_id = (SELECT owner_id FROM goals WHERE id = NEW.goal_id) THEN
        RETURN NEW;
    END IF;
    
    -- Get tagger's profile (goal owner)
    SELECT * INTO tagger_profile
    FROM profiles
    WHERE id = (SELECT owner_id FROM goals WHERE id = NEW.goal_id);
    
    -- Get goal details
    SELECT * INTO goal_record
    FROM goals
    WHERE id = NEW.goal_id;
    
    -- Create notification title
    notification_title := COALESCE(tagger_profile.first_name || ' ' || tagger_profile.last_name, tagger_profile.username, 'Someone') || ' tagged you in a goal';
    
    -- Use goal title as body
    notification_body := COALESCE(goal_record.title, 'Untitled Goal');
    
    -- Create notification for the tagged user
    PERFORM create_notification(
        p_user_id := NEW.user_id,
        p_type := 'goal_tag',
        p_title := notification_title,
        p_body := notification_body,
        p_related_id := NEW.goal_id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create notifications when users are tagged in goals
CREATE TRIGGER trigger_notify_goal_tagged
    AFTER INSERT ON goal_tags
    FOR EACH ROW
    EXECUTE FUNCTION notify_goal_tagged();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION notify_message_sent() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_goal_tagged() TO authenticated;
