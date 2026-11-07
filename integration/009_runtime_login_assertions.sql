-- Validate real non-owner login in disposable CI database.
-- The test runner must provision a temporary password before this file is executed.
BEGIN;
SET LOCAL ROLE gulgo_runtime;
DO $$
BEGIN
 IF current_user <> 'gulgo_runtime' THEN
  RAISE EXCEPTION 'Runtime role not active';
 END IF;
 IF has_table_privilege('public.economic_subject','SELECT') THEN
  RAISE EXCEPTION 'Runtime login inherited table SELECT unexpectedly';
 END IF;
END $$;
SET LOCAL ROLE gulgo_api;
DO $$
BEGIN
 IF current_user <> 'gulgo_api' THEN RAISE EXCEPTION 'Cannot assume restricted API role'; END IF;
 IF NOT has_table_privilege('public.economic_subject','SELECT') THEN
  RAISE EXCEPTION 'API role missing expected SELECT';
 END IF;
 IF has_table_privilege('public.economic_subject','INSERT') THEN
  RAISE EXCEPTION 'API role has unexpected direct write permission';
 END IF;
END $$;
ROLLBACK;
