-- This script MUST be run with a real gulgo_runtime login, never as owner.
\set ON_ERROR_STOP on
BEGIN;
DO $$
BEGIN
 IF session_user <> 'gulgo_runtime' OR current_user <> 'gulgo_runtime' THEN
  RAISE EXCEPTION 'Expected direct gulgo_runtime login';
 END IF;
 IF has_table_privilege('public.economic_subject', 'SELECT') THEN
  RAISE EXCEPTION 'Runtime login unexpectedly has direct table access';
 END IF;
END $$;
SET LOCAL ROLE gulgo_api;
DO $$
BEGIN
 IF session_user <> 'gulgo_runtime' OR current_user <> 'gulgo_api' THEN
  RAISE EXCEPTION 'Role transition failed';
 END IF;
 IF NOT has_table_privilege('public.economic_subject','SELECT')
 OR has_table_privilege('public.economic_subject','INSERT') THEN
  RAISE EXCEPTION 'API privileges are not minimal';
 END IF;
END $$;
SELECT set_config('app.current_user_id','11111111-1111-4111-8111-111111111111',true);
SELECT count(*) FROM public.economic_subject;
ROLLBACK;
