-- Migration 004: Atomic publish_timetable function
-- Problem: The Flutter app currently does two separate UPDATE calls to publish
--   a timetable (archive all others, then publish the target). If the network
--   drops between the two calls, ALL timetables end up archived with none published.
-- Fix: Single Postgres function that does both in one transaction.
-- The Flutter app will call: supabase.rpc('publish_timetable', params: {'p_timetable_id': id})
-- Run: supabase db push

CREATE OR REPLACE FUNCTION publish_timetable(p_timetable_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Both UPDATEs run in one transaction — either both succeed or neither does.

  -- Step 1: Archive all OTHER timetables
  UPDATE timetables
  SET    status    = 'archived',
         is_active = false
  WHERE  id != p_timetable_id;

  -- Step 2: Publish the target timetable
  UPDATE timetables
  SET    status    = 'published',
         is_active = true
  WHERE  id = p_timetable_id;

  -- Verify it actually exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Timetable % not found', p_timetable_id;
  END IF;

  RETURN json_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant to authenticated (admins call this)
GRANT EXECUTE ON FUNCTION publish_timetable(UUID) TO authenticated;
