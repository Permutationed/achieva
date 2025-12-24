-- Test to understand why auth.uid() works for SELECT but not INSERT

-- Test 1: Direct auth.uid() call (will be NULL in SQL Editor)
SELECT auth.uid() as test1_direct_call;

-- Test 2: Check if there's an active JWT
SELECT current_setting('request.jwt.claims', true) as test2_jwt_claims;

-- Test 3: Check current role
SELECT current_setting('request.jwt.claims', true)::jsonb->>'role' as test3_role;

-- Test 4: Try to see what policies exist for INSERT
SELECT 
    policyname,
    pg_get_expr(polwithcheck, polrelid) as with_check_expression
FROM pg_policy pol
JOIN pg_class cls ON pol.polrelid = cls.oid
WHERE cls.relname = 'goals'
AND polcmd = 'a'; -- 'a' is INSERT

-- The issue is that auth.uid() returns NULL even when JWT is sent
-- This is likely a Supabase PostgREST issue with the Swift SDK

