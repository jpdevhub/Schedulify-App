-- Migration 005: Scope enrollments to student's exact department
--               + Comprehensive RLS policies for all tables
-- Run: supabase db push

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 1: Fix enrollment scoping
-- Problem: students from CST were getting enrolled in CSE courses because
--          the timetable's department_id matched but the course itself
--          belongs to a different department.
-- Fix: Only enroll student in a course if course.department_id = student.department_id
-- ══════════════════════════════════════════════════════════════════════════════

-- Step 1a: Remove cross-department enrollments (the bad ones)
DELETE FROM student_enrollments se
WHERE NOT EXISTS (
  SELECT 1
  FROM profiles p
  JOIN courses c ON c.id = se.course_id
  WHERE p.id = se.student_id
    AND c.department_id = p.department_id
);

-- Step 1b: Fix the auto-enroll trigger to also match on course department
CREATE OR REPLACE FUNCTION auto_enroll_on_timetable_publish()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'published' AND (OLD.status IS DISTINCT FROM 'published') THEN

    INSERT INTO student_enrollments (student_id, course_id, status)
    SELECT
      p.id         AS student_id,
      te.course_id AS course_id,
      'active'     AS status
    FROM timetable_entries te
    JOIN courses c ON c.id = te.course_id
    -- Only students whose department matches BOTH the timetable AND the course
    JOIN profiles p ON p.department_id = NEW.department_id
                   AND p.department_id = c.department_id
                   AND p.role          = 'student'
                   AND p.is_active     = true
    WHERE te.timetable_id = NEW.id
      AND te.course_id IS NOT NULL
    ON CONFLICT (student_id, course_id) DO NOTHING;

  END IF;
  RETURN NEW;
END;
$$;

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 2: RLS Policies
-- Enable RLS on every table that doesn't have it yet, then define policies.
-- These use auth.uid() which Supabase sets automatically from the JWT.
-- ══════════════════════════════════════════════════════════════════════════════

-- ── profiles ─────────────────────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop old policies first (so re-running is safe)
DROP POLICY IF EXISTS "profiles_read_own"    ON profiles;
DROP POLICY IF EXISTS "profiles_read_admin"  ON profiles;
DROP POLICY IF EXISTS "profiles_update_own"  ON profiles;
DROP POLICY IF EXISTS "profiles_admin_all"   ON profiles;

-- Students & faculty can read their own profile
CREATE POLICY "profiles_read_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Admins can read all profiles (needed for user management)
CREATE POLICY "profiles_read_admin" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

-- Anyone can update only their own profile
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Admins can do everything
CREATE POLICY "profiles_admin_all" ON profiles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

-- ── student_enrollments ───────────────────────────────────────────────────────
ALTER TABLE student_enrollments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "enrollments_read_own"    ON student_enrollments;
DROP POLICY IF EXISTS "enrollments_admin_all"   ON student_enrollments;
DROP POLICY IF EXISTS "enrollments_faculty_read" ON student_enrollments;

-- Students can only see their own enrollments
CREATE POLICY "enrollments_read_own" ON student_enrollments
  FOR SELECT USING (student_id = auth.uid());

-- Faculty can see enrollments for courses they teach
-- (needed to know who should be in their class)
CREATE POLICY "enrollments_faculty_read" ON student_enrollments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM timetable_entries te
      WHERE te.course_id  = student_enrollments.course_id
        AND te.faculty_id = auth.uid()
    )
  );

-- Admins can do everything on enrollments
CREATE POLICY "enrollments_admin_all" ON student_enrollments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

-- ── attendance_sessions ───────────────────────────────────────────────────────
ALTER TABLE attendance_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sessions_faculty_own"     ON attendance_sessions;
DROP POLICY IF EXISTS "sessions_student_active"  ON attendance_sessions;
DROP POLICY IF EXISTS "sessions_admin_all"        ON attendance_sessions;

-- Faculty can manage their own sessions
CREATE POLICY "sessions_faculty_own" ON attendance_sessions
  FOR ALL USING (faculty_id = auth.uid());

-- Students can read active sessions (so they can mark attendance)
CREATE POLICY "sessions_student_active" ON attendance_sessions
  FOR SELECT USING (
    status = 'active'
    AND EXISTS (
      SELECT 1 FROM student_enrollments se
      WHERE se.student_id = auth.uid()
        AND se.course_id  = attendance_sessions.course_id
        AND se.status     = 'active'
    )
  );

-- Admins can do everything
CREATE POLICY "sessions_admin_all" ON attendance_sessions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

-- ── attendance_records ────────────────────────────────────────────────────────
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "records_read_own"      ON attendance_records;
DROP POLICY IF EXISTS "records_faculty_read"  ON attendance_records;
DROP POLICY IF EXISTS "records_admin_all"     ON attendance_records;

-- Students can only see their own records
CREATE POLICY "records_read_own" ON attendance_records
  FOR SELECT USING (student_id = auth.uid());

-- Faculty can see records for their sessions
CREATE POLICY "records_faculty_read" ON attendance_records
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM attendance_sessions s
      WHERE s.id         = attendance_records.session_id
        AND s.faculty_id = auth.uid()
    )
  );

-- Admins can do everything
CREATE POLICY "records_admin_all" ON attendance_records
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

-- ── courses, departments, classrooms, timetables, timetable_entries ───────────
-- These are reference/read-mostly tables.
-- All authenticated users can READ. Only admins can WRITE.

ALTER TABLE courses           ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE classrooms        ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetables        ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetable_entries ENABLE ROW LEVEL SECURITY;

-- Drop and recreate for each
DROP POLICY IF EXISTS "courses_read"     ON courses;
DROP POLICY IF EXISTS "courses_admin"    ON courses;
DROP POLICY IF EXISTS "depts_read"       ON departments;
DROP POLICY IF EXISTS "depts_admin"      ON departments;
DROP POLICY IF EXISTS "rooms_read"       ON classrooms;
DROP POLICY IF EXISTS "rooms_admin"      ON classrooms;
DROP POLICY IF EXISTS "tt_read"          ON timetables;
DROP POLICY IF EXISTS "tt_admin"         ON timetables;
DROP POLICY IF EXISTS "tte_read"         ON timetable_entries;
DROP POLICY IF EXISTS "tte_admin"        ON timetable_entries;

-- Read: any authenticated user
CREATE POLICY "courses_read"     ON courses           FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "depts_read"       ON departments       FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "rooms_read"       ON classrooms        FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "tt_read"          ON timetables        FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "tte_read"         ON timetable_entries FOR SELECT USING (auth.role() = 'authenticated');

-- Write: admins only
CREATE POLICY "courses_admin"    ON courses           FOR ALL USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));
CREATE POLICY "depts_admin"      ON departments       FOR ALL USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));
CREATE POLICY "rooms_admin"      ON classrooms        FOR ALL USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));
CREATE POLICY "tt_admin"         ON timetables        FOR ALL USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));
CREATE POLICY "tte_admin"        ON timetable_entries FOR ALL USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));

-- ── geofence_config ───────────────────────────────────────────────────────────
ALTER TABLE geofence_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "geofence_read"  ON geofence_config;
DROP POLICY IF EXISTS "geofence_admin" ON geofence_config;

-- All authenticated users need to read it for the geofence check
CREATE POLICY "geofence_read"  ON geofence_config FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "geofence_admin" ON geofence_config FOR ALL    USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin')));

-- ── attendance_audit_logs ─────────────────────────────────────────────────────
ALTER TABLE attendance_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "audit_admin_all"    ON attendance_audit_logs;
DROP POLICY IF EXISTS "audit_faculty_read" ON attendance_audit_logs;

-- Only admins can read/write audit logs
CREATE POLICY "audit_admin_all" ON attendance_audit_logs
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','super_admin'))
  );

-- Faculty can read audit logs for their sessions
CREATE POLICY "audit_faculty_read" ON attendance_audit_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM attendance_sessions s
      WHERE s.id = attendance_audit_logs.session_id AND s.faculty_id = auth.uid()
    )
  );
