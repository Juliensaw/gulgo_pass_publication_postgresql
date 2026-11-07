-- This script MUST be run with a real gulgo_runtime login, never as owner.
\set ON_ERROR_STOP on
BEGIN;
DO $$
BEGIN
 IF session_user <> 'gulgo_runtime' OR current_user <> 'gulgo_runtime' THEN
  RAISE EXCEPTION 'Expected direct gulgo_runtime login';
 END IF;
 IF has_schema_privilege(current_user,'public','CREATE')
 OR has_database_privilege(current_user,current_database(),'CREATE')
 THEN RAISE EXCEPTION 'Runtime login has object-creation privileges'; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user
           AND (rolsuper OR rolbypassrls OR rolcreatedb OR rolcreaterole))
 THEN RAISE EXCEPTION 'Runtime login has privileged role attributes'; END IF;
  IF has_table_privilege('public.economic_subject', 'SELECT') THEN
  RAISE EXCEPTION 'Runtime login unexpectedly has direct table access';
 END IF;
END $$;
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.actor_expires',(floor(extract(epoch from clock_timestamp()))::bigint + 30)::text,true);
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
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v131:11111111-1111-4111-8111-111111111111:' || txid_current()::text || ':' || current_setting('app.actor_expires'),'UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
SELECT count(*) FROM public.economic_subject;
ROLLBACK;
