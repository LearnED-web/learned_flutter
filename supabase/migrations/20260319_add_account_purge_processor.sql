-- =============================================
-- ACCOUNT PURGE PROCESSOR (POST RETENTION)
-- Created: 2026-03-19
-- Purpose: Service-role hard purge after scheduled retention date
-- =============================================

CREATE OR REPLACE FUNCTION public.process_account_purge(
    p_user_id uuid DEFAULT NULL,
    p_limit integer DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_row record;
    v_processed integer := 0;
    v_failed integer := 0;
    v_teacher_id uuid;
    v_student_id uuid;
BEGIN
    IF auth.role() IS DISTINCT FROM 'service_role' THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'forbidden',
            'message', 'Only service_role can process account purges.'
        );
    END IF;

    FOR v_row IN
        SELECT u.id, u.user_type
        FROM public.users u
        WHERE u.deletion_status = 'requested'
          AND u.scheduled_purge_at IS NOT NULL
          AND u.scheduled_purge_at <= now()
          AND (p_user_id IS NULL OR u.id = p_user_id)
        ORDER BY u.scheduled_purge_at ASC
        LIMIT GREATEST(1, p_limit)
    LOOP
        BEGIN
            -- Preserve audit history by detaching user references.
            UPDATE public.audit_logs
            SET user_id = NULL
            WHERE user_id = v_row.id;

            UPDATE public.admin_activities
            SET target_user_id = NULL
            WHERE target_user_id = v_row.id;

            DELETE FROM public.admin_activities
            WHERE admin_id = v_row.id;

            DELETE FROM public.teacher_documents
            WHERE uploaded_by = v_row.id;

            UPDATE public.teacher_documents
            SET verified_by = NULL
            WHERE verified_by = v_row.id;

            UPDATE public.teacher_verification
            SET reviewed_by = NULL
            WHERE reviewed_by = v_row.id;

            -- Student data purge path
            SELECT s.id INTO v_student_id
            FROM public.students s
            WHERE s.user_id = v_row.id;

            IF v_student_id IS NOT NULL THEN
                DELETE FROM public.session_attendance WHERE student_id = v_student_id;
                DELETE FROM public.student_assignment_attempts WHERE student_id = v_student_id;
                DELETE FROM public.student_progress WHERE student_id = v_student_id;
                DELETE FROM public.student_enrollments WHERE student_id = v_student_id;
                DELETE FROM public.payments WHERE student_id = v_student_id;
                DELETE FROM public.parent_student_relations WHERE student_id = v_student_id;
                DELETE FROM public.students WHERE id = v_student_id;
            END IF;

            -- Teacher data purge path
            SELECT t.id INTO v_teacher_id
            FROM public.teachers t
            WHERE t.user_id = v_row.id;

            IF v_teacher_id IS NOT NULL THEN
                -- Block purge if teacher still has active enrollments.
                IF EXISTS (
                    SELECT 1
                    FROM public.classrooms c
                    JOIN public.student_enrollments se ON se.classroom_id = c.id
                    WHERE c.teacher_id = v_teacher_id
                      AND se.status::text = 'active'
                ) THEN
                    v_failed := v_failed + 1;
                    CONTINUE;
                END IF;

                DELETE FROM public.teacher_documents WHERE teacher_id = v_teacher_id;
                DELETE FROM public.teacher_verification WHERE teacher_id = v_teacher_id;

                DELETE FROM public.assignment_questions
                WHERE assignment_id IN (
                    SELECT a.id FROM public.assignments a WHERE a.teacher_id = v_teacher_id
                );

                DELETE FROM public.student_assignment_attempts
                WHERE assignment_id IN (
                    SELECT a.id FROM public.assignments a WHERE a.teacher_id = v_teacher_id
                );

                DELETE FROM public.student_progress
                WHERE assignment_id IN (
                    SELECT a.id FROM public.assignments a WHERE a.teacher_id = v_teacher_id
                );

                DELETE FROM public.assignments WHERE teacher_id = v_teacher_id;

                DELETE FROM public.session_attendance
                WHERE session_id IN (
                    SELECT cs.id
                    FROM public.class_sessions cs
                    JOIN public.classrooms c ON c.id = cs.classroom_id
                    WHERE c.teacher_id = v_teacher_id
                );

                DELETE FROM public.class_sessions
                WHERE classroom_id IN (
                    SELECT c.id FROM public.classrooms c WHERE c.teacher_id = v_teacher_id
                );

                DELETE FROM public.learning_materials WHERE teacher_id = v_teacher_id;

                DELETE FROM public.classroom_pricing
                WHERE classroom_id IN (
                    SELECT c.id FROM public.classrooms c WHERE c.teacher_id = v_teacher_id
                );

                DELETE FROM public.student_progress
                WHERE classroom_id IN (
                    SELECT c.id FROM public.classrooms c WHERE c.teacher_id = v_teacher_id
                );

                DELETE FROM public.student_enrollments
                WHERE classroom_id IN (
                    SELECT c.id FROM public.classrooms c WHERE c.teacher_id = v_teacher_id
                );

                DELETE FROM public.payments
                WHERE classroom_id IN (
                    SELECT c.id FROM public.classrooms c WHERE c.teacher_id = v_teacher_id
                );

                DELETE FROM public.classrooms WHERE teacher_id = v_teacher_id;
                DELETE FROM public.teachers WHERE id = v_teacher_id;
            END IF;

            DELETE FROM public.parents WHERE user_id = v_row.id;
            DELETE FROM public.system_notifications WHERE user_id = v_row.id;
            DELETE FROM public.account_deletion_requests WHERE user_id = v_row.id;

            DELETE FROM public.users WHERE id = v_row.id;

            INSERT INTO public.trigger_logs (message, metadata)
            VALUES (
                'Account purged successfully',
                jsonb_build_object('user_id', v_row.id, 'user_type', v_row.user_type)
            );

            v_processed := v_processed + 1;
        EXCEPTION
            WHEN OTHERS THEN
                v_failed := v_failed + 1;
                INSERT INTO public.trigger_logs (message, error_message, metadata)
                VALUES (
                    'process_account_purge failed for user',
                    SQLERRM,
                    jsonb_build_object('user_id', v_row.id, 'error_state', SQLSTATE)
                );
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'processed', v_processed,
        'failed', v_failed
    );
END;
$$;

REVOKE ALL ON FUNCTION public.process_account_purge(uuid, integer) FROM anon;
REVOKE ALL ON FUNCTION public.process_account_purge(uuid, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.process_account_purge(uuid, integer) TO service_role;
