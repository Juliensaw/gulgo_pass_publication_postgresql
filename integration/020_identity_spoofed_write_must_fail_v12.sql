-- V1.2 acceptance test: unauthorized write MUST fail after GUC spoofing.
-- RED on the vulnerable baseline. Disposable PostgreSQL only.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO app_user(id,external_auth_id) VALUES
 ('91919191-9191-4191-8191-919191919191','v12-write-a'),
 ('92929292-9292-4292-8292-929292929292','v12-write-b');
INSERT INTO economic_subject(id,kind,display_name) VALUES
 ('a9a9a9a9-a9a9-49a9-89a9-a9a9a9a9a9a9','individual','V12 write A'),
 ('b9b9b9b9-b9b9-49b9-89b9-b9b9b9b9b9b9','individual','V12 write B');
INSERT INTO subject_representation(subject_id,user_id,role,valid_from) VALUES
 ('a9a9a9a9-a9a9-49a9-89a9-a9a9a9a9a9a9','91919191-9191-4191-8191-919191919191','owner',CURRENT_DATE),
 ('b9b9b9b9-b9b9-49b9-89b9-b9b9b9b9b9b9','92929292-9292-4292-8292-929292929292','owner',CURRENT_DATE);
INSERT INTO pass_dossier(id,subject_id,methodology_id) VALUES
 ('c9c9c9c9-c9c9-49c9-89c9-c9c9c9c9c9c9','a9a9a9a9-a9a9-49a9-89a9-a9a9a9a9a9a9','GULGO_PASS_V1_PILOT'),
 ('d9d9d9d9-d9d9-49d9-89d9-d9d9d9d9d9d9','b9b9b9b9-b9b9-49b9-89b9-b9b9b9b9b9b9','GULGO_PASS_V1_PILOT');
INSERT INTO variable_definition(methodology_id,code,label,value_type)
 VALUES('GULGO_PASS_V1_PILOT','V12-WRITE-TEST','V12 synthetic value','text');
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.current_user_id','91919191-9191-4191-8191-919191919191',true);
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v12:91919191-9191-4191-8191-919191919191','UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
-- Confirm the original signed actor A is valid before adversarial writes.
DO $ BEGIN
 IF public.gulgo_actor_id() IS DISTINCT FROM '91919191-9191-4191-8191-919191919191'::uuid
 THEN RAISE EXCEPTION 'FAIL: signed actor A rejected'; END IF;
END $;
-- A cannot write to B under the original identity.
DO $$
BEGIN
 BEGIN
  PERFORM gulgo_append_observation('d9d9d9d9-d9d9-49d9-89d9-d9d9d9d9d9d9',
   'V12-WRITE-TEST','"unauthorized"'::jsonb,'available');
  RAISE EXCEPTION 'SECURITY FAILURE: A could write to B before spoofing';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
-- Attack: change the identity GUC. A secure implementation must STILL deny.
SELECT set_config('app.current_user_id','92929292-9292-4292-8292-929292929292',true);
DO $$
BEGIN
 BEGIN
  PERFORM gulgo_append_observation('d9d9d9d9-d9d9-49d9-89d9-d9d9d9d9d9d9',
   'V12-WRITE-TEST','"unauthorized"'::jsonb,'available');
  RAISE EXCEPTION 'SECURITY FAILURE: spoofed identity permitted writing to B';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
ROLLBACK;
