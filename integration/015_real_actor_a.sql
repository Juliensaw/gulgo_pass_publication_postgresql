-- Run with a REAL PostgreSQL gulgo_runtime login, not gulgo_owner.
-- The JWT actor has already been verified by the API in the actual app;
-- these direct-SQL integration tests cover the resulting RLS role context.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.actor_expires',(floor(extract(epoch from clock_timestamp()))::bigint + 30)::text,true);
SELECT set_config('app.actor_key_id','primary',true);
SELECT set_config('app.current_user_id','33333333-3333-4333-8333-333333333333',true);
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v132:primary:33333333-3333-4333-8333-333333333333:' || txid_current()::text || ':' || current_setting('app.actor_expires'),'UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$
DECLARE v_observation uuid;
BEGIN
 IF session_user <> 'gulgo_runtime' OR current_user <> 'gulgo_api'
 THEN RAISE EXCEPTION 'Not a real restricted login'; END IF;
 IF (SELECT count(*) FROM pass_dossier) <> 1
 OR NOT EXISTS (SELECT 1 FROM pass_dossier WHERE id='cccccccc-3333-4333-8333-333333333333')
 OR EXISTS (SELECT 1 FROM pass_dossier WHERE id='dddddddd-4444-4444-8444-444444444444')
 THEN RAISE EXCEPTION 'Actor A dossier visibility failure'; END IF;
 IF (SELECT count(*) FROM economic_subject) <> 1
 THEN RAISE EXCEPTION 'Actor A subject isolation failure'; END IF;
 v_observation:=gulgo_append_observation(
  'cccccccc-3333-4333-8333-333333333333','CI-TWO-ACTOR-TEXT',
  '"Actor A observation"'::jsonb,'available');
 IF v_observation IS NULL
 OR NOT EXISTS (SELECT 1 FROM variable_observation WHERE id=v_observation)
 THEN RAISE EXCEPTION 'Actor A failed to record or read own observation'; END IF;
 IF EXISTS(SELECT 1 FROM variable_observation
           WHERE dossier_id='dddddddd-4444-4444-8444-444444444444')
 THEN RAISE EXCEPTION 'Actor A read actor B observations'; END IF;
 BEGIN
  PERFORM gulgo_create_dossier('bbbbbbbb-4444-4444-8444-444444444444',
                               'GULGO_PASS_V1_PILOT');
  RAISE EXCEPTION 'Actor A created dossier for actor B';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM gulgo_append_observation(
   'dddddddd-4444-4444-8444-444444444444','CI-TWO-ACTOR-TEXT',
   '"A forged B observation"'::jsonb,'available');
  RAISE EXCEPTION 'Actor A wrote into actor B dossier';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 IF has_table_privilege(current_user,'variable_observation','UPDATE')
 THEN RAISE EXCEPTION 'Actor A can edit immutable observations'; END IF;
END $$;
COMMIT;
