# Supabase Migration Instructions

## Running the Migration

### Option 1: Supabase Dashboard (Recommended - No Password Needed)

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy and paste the entire contents of `001_create_goals_schema.sql`
5. Click **Run** (or press Cmd+Enter)
6. The migration will execute and create all tables, indexes, and RLS policies

**You do NOT need a database password** - the Supabase dashboard uses your project authentication.

### Option 2: Supabase CLI (If you have it set up)

```bash
supabase db push
```

This will run all migrations in the `supabase/migrations/` folder.

### Option 3: Direct PostgreSQL Connection (Requires Password)

Only if you're connecting directly to PostgreSQL (not recommended):

1. Get your database password from Supabase Dashboard → Settings → Database
2. Connect using a PostgreSQL client (psql, pgAdmin, etc.)
3. Run the migration SQL

**For the Swift app, you only need the Supabase URL and Anon Key** - no database password required!

## What the Migration Creates

- ✅ `friendships` table (for friends-only visibility)
- ✅ `goals` table (core goals/posts table)
- ✅ `goal_acl` table (custom visibility access control)
- ✅ `goal_items` table (subgoals/checklist items)
- ✅ All RLS policies for security
- ✅ Indexes for performance
- ✅ Triggers for auto-updating timestamps

## Environment Variables

In your `.env` file, you need:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

Get these from: Supabase Dashboard → Settings → API

**No database password needed for the app!** The anon key handles authentication.


