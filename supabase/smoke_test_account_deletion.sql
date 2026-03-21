-- =============================================
-- ACCOUNT DELETION SMOKE TEST (NON-DESTRUCTIVE)
-- Purpose: Validate request_account_deletion behavior
-- Safety: Wrapped in a transaction and rolled back
-- =============================================

BEGIN;

DO $$
DECLARE
    v_test_user_id uuid := gen_random_uuid();
    v_test_email text := 'smoke+' || replace(v_test_user_id::text, '-', '') || '@example.test';
    v_response jsonb;
    v_request_count integer;
    v_status text;
BEGIN
    IF to_regprocedure('public.request_account_deletion(text)') IS NULL THEN
        RAISE EXCEPTION 'request_account_deletion(text) function is missing';
    END IF;

    -- Minimal profile row required by request_account_deletion
    INSERT INTO public.users (
        id,
        email,
        user_type,
        first_name,
        last_name,
        is_active
    ) VALUES (
        v_test_user_id,
        v_test_email,
        'student'::user_type,
        'Smoke',
        'Tester',
        true
    );

    -- Simulate authenticated request context so auth.uid() resolves correctly.
    PERFORM set_config(
        'request.jwt.claims',
        json_build_object(
            'sub', v_test_user_id::text,
            'role', 'authenticated'
        )::text,
        true
    );

    SELECT public.request_account_deletion('smoke test request') INTO v_response;

    IF COALESCE((v_response ->> 'success')::boolean, false) IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'request_account_deletion failed: %', v_response;
    END IF;

    SELECT COUNT(*)
    INTO v_request_count
    FROM public.account_deletion_requests
    WHERE user_id = v_test_user_id;

    IF v_request_count <> 1 THEN
        RAISE EXCEPTION 'Expected 1 account_deletion_requests row, found %', v_request_count;
    END IF;

    SELECT deletion_status
    INTO v_status
    FROM public.users
    WHERE id = v_test_user_id;

    IF v_status <> 'requested' THEN
        RAISE EXCEPTION 'Expected deletion_status=requested, found %', v_status;
    END IF;

    RAISE NOTICE 'Smoke test passed for user_id=% response=%', v_test_user_id, v_response;
END
$$;

-- Keep database unchanged.
ROLLBACK;
