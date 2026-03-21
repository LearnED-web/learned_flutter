-- =============================================
-- ACCOUNT DELETION REQUEST FLOW (SOFT DELETE)
-- Created: 2026-03-19
-- Purpose: User-initiated deletion request with legal retention metadata
-- =============================================

-- Add account deletion lifecycle fields to users
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS deletion_status character varying DEFAULT 'active';

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS deletion_requested_at timestamp with time zone;

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS scheduled_purge_at timestamp with time zone;

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS deletion_reason text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'users_deletion_status_check'
    ) THEN
        ALTER TABLE public.users
        ADD CONSTRAINT users_deletion_status_check
        CHECK (deletion_status::text = ANY (ARRAY['active', 'requested', 'purged']::text[]));
    END IF;
END $$;

-- Track deletion requests for compliance and review
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id),
    requested_by uuid NOT NULL,
    user_type character varying,
    request_source character varying DEFAULT 'in_app',
    reason text,
    status character varying NOT NULL DEFAULT 'accepted',
    requested_at timestamp with time zone NOT NULL DEFAULT now(),
    retention_until timestamp with time zone NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_user_id
ON public.account_deletion_requests(user_id);

CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_requested_at
ON public.account_deletion_requests(requested_at DESC);

-- Main RPC for authenticated users to request account deletion
CREATE OR REPLACE FUNCTION public.request_account_deletion(
    p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_user public.users%ROWTYPE;
    v_teacher_blocked boolean := false;
    v_retention_until timestamp with time zone := now() + interval '7 years';
BEGIN
    v_uid := auth.uid();

    IF v_uid IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'unauthenticated',
            'message', 'You must be authenticated to request account deletion.'
        );
    END IF;

    SELECT *
    INTO v_user
    FROM public.users
    WHERE id = v_uid;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'user_not_found',
            'message', 'No profile found for the authenticated account.'
        );
    END IF;

    IF COALESCE(v_user.deletion_status, 'active') = 'requested' THEN
        RETURN jsonb_build_object(
            'success', true,
            'code', 'already_requested',
            'message', 'Account deletion has already been requested.',
            'scheduled_purge_at', v_user.scheduled_purge_at
        );
    END IF;

    IF v_user.user_type::text = 'teacher' THEN
        SELECT EXISTS (
            SELECT 1
            FROM public.teachers t
            JOIN public.classrooms c ON c.teacher_id = t.id
            JOIN public.student_enrollments se ON se.classroom_id = c.id
            WHERE t.user_id = v_uid
              AND se.status::text = 'active'
        ) INTO v_teacher_blocked;

        IF v_teacher_blocked THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'teacher_has_active_students',
                'message', 'Account deletion is blocked while active student enrollments exist. Please transfer or close classes first.'
            );
        END IF;
    END IF;

    INSERT INTO public.account_deletion_requests (
        user_id,
        requested_by,
        user_type,
        reason,
        retention_until,
        metadata
    ) VALUES (
        v_uid,
        v_uid,
        v_user.user_type::text,
        p_reason,
        v_retention_until,
        jsonb_build_object(
            'email', v_user.email,
            'requested_via', 'mobile_app',
            'retention_policy', 'legal_financial_records_7_years'
        )
    );

    UPDATE public.users
    SET
        is_active = false,
        deletion_status = 'requested',
        deletion_requested_at = now(),
        scheduled_purge_at = v_retention_until,
        deletion_reason = p_reason,
        phone = NULL,
        profile_image_url = NULL,
        date_of_birth = NULL,
        address = NULL,
        city = NULL,
        state = NULL,
        country = NULL,
        postal_code = NULL,
        updated_at = now()
    WHERE id = v_uid;

    INSERT INTO public.trigger_logs (message, metadata)
    VALUES (
        'Account deletion requested',
        jsonb_build_object(
            'user_id', v_uid,
            'user_type', v_user.user_type,
            'retention_until', v_retention_until
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'code', 'deletion_requested',
        'message', 'Account deletion requested successfully. Your access has been disabled.',
        'retention_until', v_retention_until
    );
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO public.trigger_logs (message, error_message, metadata)
        VALUES (
            'request_account_deletion failed',
            SQLERRM,
            jsonb_build_object('user_id', auth.uid(), 'error_state', SQLSTATE)
        );

        RETURN jsonb_build_object(
            'success', false,
            'code', 'internal_error',
            'message', 'Failed to process account deletion request.'
        );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_account_deletion(text) TO authenticated;
