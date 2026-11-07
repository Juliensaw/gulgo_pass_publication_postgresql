-- Security assertions for disposable PostgreSQL only.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE gulgo_api;
DO $$
BEGIN
 IF has_table_privilege(current_user,'public.gulgo_identity_secret','SELECT')
 OR has_table_privilege(current_user,'public.gulgo_identity_secret','INSERT')
 OR has_table_privilege(current_user,'public.gulgo_identity_secret','UPDATE')
 OR has_table_privilege(current_user,'public.gulgo_identity_secret','DELETE')
 THEN RAISE EXCEPTION 'SECURITY FAILURE: application role can access signing key table'; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls))
 THEN RAISE EXCEPTION 'SECURITY FAILURE: application role bypasses RLS'; END IF;
 IF public.gulgo_actor_id() IS NOT NULL
 THEN RAISE EXCEPTION 'SECURITY FAILURE: missing identity proof accepted'; END IF;
END $$;
SELECT set_config('app.current_user_id','31313131-3131-4131-8131-313131313131',true);
SELECT set_config('app.actor_mac',repeat('0',64),true);
DO $$
BEGIN
 IF public.gulgo_actor_id() IS NOT NULL
 THEN RAISE EXCEPTION 'SECURITY FAILURE: invalid MAC accepted'; END IF;
END $$;
ROLLBACK;
