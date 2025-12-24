# How to Run Migration 006: Simplify Goals INSERT Policy

## Overview
This migration simplifies the RLS INSERT policy for the `goals` table and adds debugging capabilities to diagnose authentication issues.

## Steps to Apply Migration

### Option 1: Supabase Dashboard (Recommended)

1. **Open Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your project

2. **Navigate to SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New query"

3. **Copy and Run the Migration**
   - Open `supabase/migrations/006_simplify_goals_insert_policy.sql`
   - Copy the entire contents
   - Paste into the SQL Editor
   - Click "Run" or press Cmd+Enter (Mac) / Ctrl+Enter (Windows)

4. **Verify Success**
   - You should see success messages including:
     - "✅ INSERT policy created successfully"
     - A list of current RLS policies for the goals table
   - Check that no errors occurred

### Option 2: Supabase CLI

If you have Supabase CLI installed:

```bash
cd /Users/joshuawang/mvp1
supabase db push
```

## What This Migration Does

1. **Drops the existing INSERT policy** to start fresh
2. **Creates a debugging function** (`debug_auth_context()`) to help diagnose auth issues
3. **Creates a simplified INSERT policy** that only checks `owner_id = auth.uid()`
4. **Adds documentation** to the policy for future reference
5. **Verifies RLS is enabled** on the goals table
6. **Grants execute permissions** on the debug function
7. **Displays current policies** for verification

## Testing the Fix

After running this migration, test goal creation in the app:

1. **Try creating a goal** in the app
2. **Check the Xcode console** for debug output:
   - Session information
   - Auth test results (profiles query)
   - Goal creation attempt
   - Any error messages

3. **If it still fails**, use the debug function to check auth state:
   ```sql
   SELECT * FROM debug_auth_context();
   ```
   This will show:
   - `current_user_id`: Should match your user ID
   - `current_role`: Should be 'authenticated' or 'anon'
   - `jwt_claims`: Full JWT token claims

## Troubleshooting

### If you see "current_user_id is NULL"
- The JWT token is not being sent correctly
- Check that the Supabase client is properly initialized
- Verify the user is signed in

### If you see "Permission denied" error
- The owner_id in the INSERT doesn't match auth.uid()
- Check the debug output in Xcode console
- Verify the session is not expired

### If migration fails to run
- Check if migration 005 conflicts with this one
- You may need to drop migration 005's policy first
- Contact support if issues persist

## Rollback (if needed)

If you need to revert this migration:

```sql
-- Drop the new policy
DROP POLICY IF EXISTS "Users can create their own goals" ON goals;

-- Recreate the old policy (from migration 004)
CREATE POLICY "Users can create their own goals"
    ON goals FOR INSERT
    WITH CHECK (owner_id = auth.uid());

-- Drop the debug function
DROP FUNCTION IF EXISTS debug_auth_context();
```

## Next Steps

After running this migration:
1. Test goal creation in the app
2. Check console logs for auth debugging output
3. If it works, the issue is resolved ✅
4. If it fails, run `SELECT * FROM debug_auth_context();` in SQL Editor to diagnose
