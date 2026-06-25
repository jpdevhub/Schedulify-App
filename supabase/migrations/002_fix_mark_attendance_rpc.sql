-- Migration 002: Fix mark_attendance RPC
-- Changes:
--   1. Add enrollment check (student must be enrolled in the course)
--   2. Add ±1 window clock skew tolerance to QR hash validation
--   3. Full CREATE OR REPLACE — safe to run whether function exists or not
-- Run: supabase db push

-- Drop first to allow changing the return type
-- (PostgreSQL doesn't allow CREATE OR REPLACE when return type changes)
DROP FUNCTION IF EXISTS mark_attendance(UUID, UUID, TEXT, FLOAT8, FLOAT8, BOOLEAN);

CREATE OR REPLACE FUNCTION mark_attendance(
  p_session_id  UUID,
  p_student_id  UUID,
  p_qr_hash     TEXT,
  p_lat         FLOAT8,
  p_lng         FLOAT8,
  p_is_mocked   BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session         attendance_sessions%ROWTYPE;
  v_course_id       UUID;
  v_window          BIGINT;
  v_hash_now        TEXT;
  v_hash_prev       TEXT;
  v_already_marked  BOOLEAN;
  v_is_enrolled     BOOLEAN;
BEGIN

  -- ── 1. Reject mock/spoofed GPS ────────────────────────────────────────────
  IF p_is_mocked THEN
    RETURN json_build_object('success', false, 'error', 'mock_location');
  END IF;

  -- ── 2. Load the session ───────────────────────────────────────────────────
  SELECT * INTO v_session
  FROM attendance_sessions
  WHERE id = p_session_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'session_not_active');
  END IF;

  IF v_session.status != 'active' THEN
    RETURN json_build_object('success', false, 'error', 'session_not_active');
  END IF;

  v_course_id := v_session.course_id;

  -- ── 3. Validate QR hash (with ±1 window clock skew tolerance) ────────────
  -- Matches Dart: sha256('sessionId:window').hex.substring(0,32)
  -- Window = epoch_ms / 5000 (5-second buckets)
  v_window    := (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT / 5000;
  v_hash_now  := LEFT(
                   ENCODE(SHA256(CONVERT_TO(p_session_id::TEXT || ':' || v_window::TEXT, 'UTF8')), 'hex'),
                   32);
  v_hash_prev := LEFT(
                   ENCODE(SHA256(CONVERT_TO(p_session_id::TEXT || ':' || (v_window - 1)::TEXT, 'UTF8')), 'hex'),
                   32);

  IF p_qr_hash != v_hash_now AND p_qr_hash != v_hash_prev THEN
    RETURN json_build_object('success', false, 'error', 'invalid_qr');
  END IF;

  -- ── 4. Check the student is enrolled in this course ───────────────────────
  -- This prevents students from marking attendance for classes they don't attend
  SELECT EXISTS (
    SELECT 1
    FROM student_enrollments se
    WHERE se.student_id = p_student_id
      AND se.course_id  = v_course_id
      AND se.status     = 'active'
  ) INTO v_is_enrolled;

  IF NOT v_is_enrolled THEN
    RETURN json_build_object('success', false, 'error', 'not_enrolled');
  END IF;

  -- ── 5. Prevent duplicate marking ──────────────────────────────────────────
  SELECT EXISTS (
    SELECT 1
    FROM attendance_records ar
    WHERE ar.session_id  = p_session_id
      AND ar.student_id  = p_student_id
  ) INTO v_already_marked;

  IF v_already_marked THEN
    RETURN json_build_object('success', false, 'error', 'already_marked');
  END IF;

  -- ── 6. Record attendance ──────────────────────────────────────────────────
  INSERT INTO attendance_records (
    session_id,
    student_id,
    status,
    marked_at,
    location_data,
    qr_hash_used,
    is_override
  ) VALUES (
    p_session_id,
    p_student_id,
    'present',
    NOW(),
    json_build_object('lat', p_lat, 'lng', p_lng),
    p_qr_hash,
    false
  );

  RETURN json_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant execute to authenticated users (students call this)
GRANT EXECUTE ON FUNCTION mark_attendance(UUID, UUID, TEXT, FLOAT8, FLOAT8, BOOLEAN) TO authenticated;
