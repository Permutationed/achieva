-- Run this in Supabase SQL Editor to check the current INSERT policy

-- Check if the INSERT policy exists and what it looks like
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual as using_clause,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'goals'
AND cmd = 'INSERT'
ORDER BY policyname;

-- Also show the exact policy definition
SELECT 
    pg_get_expr(polqual, polrelid) as using_expression,
    pg_get_expr(polwithcheck, polrelid) as with_check_expression,
    polname as policy_name
FROM pg_policy pol
JOIN pg_class cls ON pol.polrelid = cls.oid
WHERE cls.relname = 'goals'
AND pol.polcmd = 'r'::"char"; -- 'r' is INSERT in pg_policy

-- Check RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' 
AND tablename = 'goals';

