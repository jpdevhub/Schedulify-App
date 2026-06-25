-- Migration 003: Auto-enroll students when a timetable is published
-- Changes:
--   1. Ensure student_enrollments has a unique constraint on (student_id, course_id)
--      so ON CONFLICT works correctly
--   2. Create trigger function that auto-enrolls all active students in a department
--      when their timetable is published
--   3. Attach trigger to timetables table
-- Run: supabase db push

-- ── Step 1: Ensure unique constraint exists ──────────────────────────────────
-- Prevents duplicate enrollments. Safe to run if it already exists.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'student_enrollments_student_course_unique'
  ) THEN
    ALTER TABLE student_enrollments
      ADD CONSTRAINT student_enrollments_student_course_unique
      UNIQUE (student_id, course_id);
  END IF;
END;
$$;

-- ── Step 2: Trigger function ──────────────────────────────────────────────────
-- When a timetable status changes to 'published', find all:
--   - active students whose department_id matches the timetable's department_id
-- Then enroll them in every course referenced by the timetable's entries.
-- Uses ON CONFLICT DO NOTHING so re-publishing doesn't create duplicates.

CREATE OR REPLACE FUNCTION auto_enroll_on_timetable_publish()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only fire when status transitions INTO 'published'
  IF NEW.status = 'published' AND (OLD.status IS DISTINCT FROM 'published') THEN

    INSERT INTO student_enrollments (student_id, course_id, status)
    SELECT
      p.id        AS student_id,
      te.course_id AS course_id,
      'active'    AS status
    FROM timetable_entries te
    -- All active students in the same department as this timetable
    CROSS JOIN (
      SELECT id
      FROM profiles
      WHERE role        = 'student'
        AND is_active   = true
        AND department_id = NEW.department_id
    ) p
    WHERE te.timetable_id = NEW.id
      AND te.course_id IS NOT NULL
    -- If the student is already enrolled in this course (from a previous
    -- timetable), just skip — don't duplicate or overwrite status.
    ON CONFLICT (student_id, course_id) DO NOTHING;

  END IF;

  RETURN NEW;
END;
$$;

-- ── Step 3: Attach trigger to timetables ─────────────────────────────────────
-- Drop first so re-running this migration doesn't error
DROP TRIGGER IF EXISTS trg_auto_enroll_on_publish ON timetables;

CREATE TRIGGER trg_auto_enroll_on_publish
  AFTER UPDATE OF status ON timetables
  FOR EACH ROW
  EXECUTE FUNCTION auto_enroll_on_timetable_publish();

-- ── Step 4: Backfill — enroll students for already-published timetables ──────
-- This handles the case where timetables were published BEFORE this migration.
-- Safe to run: ON CONFLICT DO NOTHING prevents any duplicates.
INSERT INTO student_enrollments (student_id, course_id, status)
SELECT
  p.id         AS student_id,
  te.course_id AS course_id,
  'active'     AS status
FROM timetables t
JOIN timetable_entries te ON te.timetable_id = t.id
CROSS JOIN (
  SELECT id, department_id
  FROM profiles
  WHERE role      = 'student'
    AND is_active = true
) p
WHERE t.status        = 'published'
  AND t.department_id = p.department_id
  AND te.course_id IS NOT NULL
ON CONFLICT (student_id, course_id) DO NOTHING;
