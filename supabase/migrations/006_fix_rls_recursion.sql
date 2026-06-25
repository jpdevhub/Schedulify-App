-- Migration 006: Fix infinite recursion in RLS policies
-- Root cause: policies on "profiles" were querying "profiles" to check the role,
--             causing infinite recursion (42P17).
-- Fix: Use a SECURITY DEFINER helper function that bypasses RLS to get the
--      current user's role — then use that in all policies.
-- Run: supabase db push

-- ── Step 1: Helper function that reads role WITHOUT triggering RLS ─────────────
-- SECURITY DEFINER = runs as the function owner (postgres), bypassing RLS.
-- This is the standard Supabase pattern for avoiding recursion.
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE SQL
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$;

-- ── Step 2: Recreate profiles policies using get_my_role() ───────────────────
DROP POLICY IF EXISTS "profiles_read_own"   ON profiles;
DROP POLICY IF EXISTS "profiles_read_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_all"  ON profiles;

-- Students/faculty read their own profile
CREATE POLICY "profiles_read_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Admins read all profiles
CREATE POLICY "profiles_read_admin" ON profiles
  FOR SELECT USING (get_my_role() IN ('admin', 'super_admin'));

-- Anyone updates only their own profile
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Admins do everything (INSERT/DELETE/UPDATE)
CREATE POLICY "profiles_admin_all" ON profiles
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- ── Step 3: Fix all other tables that had the same recursive subquery ─────────
-- Replace EXISTS(SELECT 1 FROM profiles ...) with get_my_role()

-- student_enrollments
DROP POLICY IF EXISTS "enrollments_admin_all"    ON student_enrollments;
CREATE POLICY "enrollments_admin_all" ON student_enrollments
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- attendance_sessions
DROP POLICY IF EXISTS "sessions_admin_all" ON attendance_sessions;
CREATE POLICY "sessions_admin_all" ON attendance_sessions
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- attendance_records
DROP POLICY IF EXISTS "records_admin_all" ON attendance_records;
CREATE POLICY "records_admin_all" ON attendance_records
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- courses
DROP POLICY IF EXISTS "courses_admin" ON courses;
CREATE POLICY "courses_admin" ON courses
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- departments
DROP POLICY IF EXISTS "depts_admin" ON departments;
CREATE POLICY "depts_admin" ON departments
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- classrooms
DROP POLICY IF EXISTS "rooms_admin" ON classrooms;
CREATE POLICY "rooms_admin" ON classrooms
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- timetables
DROP POLICY IF EXISTS "tt_admin" ON timetables;
CREATE POLICY "tt_admin" ON timetables
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- timetable_entries
DROP POLICY IF EXISTS "tte_admin" ON timetable_entries;
CREATE POLICY "tte_admin" ON timetable_entries
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- geofence_config
DROP POLICY IF EXISTS "geofence_admin" ON geofence_config;
CREATE POLICY "geofence_admin" ON geofence_config
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));

-- attendance_audit_logs
DROP POLICY IF EXISTS "audit_admin_all" ON attendance_audit_logs;
CREATE POLICY "audit_admin_all" ON attendance_audit_logs
  FOR ALL USING (get_my_role() IN ('admin', 'super_admin'));
