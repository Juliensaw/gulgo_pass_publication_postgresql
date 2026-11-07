-- V1.2 security acceptance test (RED until identity trust boundary is fixed).
-- Disposable database ONLY. DO NOT add to green CI as an expected-pass
-- characterization of the existing vulnerability.
-- The test succeeds ONLY if a SQL-capable gulgo_api caller cannot read B's
-- dossier after tampering with app.current_user_id.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO app_user(id,external_auth_id) VALUES
 ('71717171-7171-4171-8171-717171717171','v12-negative-a'),
 ('82828282-8282-4282-8282-828282828282','v12-negative-b');
INSERT INTO economic_subject(id,kind,display_name) VALUES
 ('a1a1a1a1-a1a1-41a1-81a1-a1a1a1a1a1a1','individual','V12 A synthetic'),
 ('b2b2b2b2-b2b2-42b2-82b2-b2b2b2b2b2b2','individual','V12 B synthetic');
INSERT INTO subject_representation(subject_id,user_id,role,valid_from) VALUES
 ('a1a1a1a1-a1a1-41a1-81a1-a1a1a1a1a1a1','71717171-7171-4171-8171-717171717171','owner',CURRENT_DATE),
 ('b2b2b2b2-b2b2-42b2-82b2-b2b2b2b2b2b2','82828282-8282-4282-8282-828282828282','owner',CURRENT_DATE);
INSERT INTO pass_dossier(id,subject_id,methodology_id) VALUES
 ('c3c3c3c3-c3c3-43c3-83c3-c3c3c3c3c3c3','a1a1a1a1-a1a1-41a1-81a1-a1a1a1a1a1a1','GULGO_PASS_V1_PILOT'),
 ('d4d4d4d4-d4d4-44d4-84d4-d4d4d4d4d4d4','b2b2b2b2-b2b2-42b2-82b2-b2b2b2b2b2b2','GULGO_PASS_V1_PILOT');
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.actor_expires',(floor(extract(epoch from clock_timestamp()))::bigint + 30)::text,true);
SELECT set_config('app.actor_key_id','primary',true);
SELECT set_config('app.current_user_id','71717171-7171-4171-8171-717171717171',true);
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v132:primary:71717171-7171-4171-8171-717171717171:' || txid_current()::text || ':' || current_setting('app.actor_expires'),'UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$
BEGIN
 IF public.gulgo_actor_id() IS DISTINCT FROM '71717171-7171-4171-8171-717171717171'::uuid
 THEN RAISE EXCEPTION 'FAIL: valid signed actor A rejected'; END IF;
 IF (SELECT count(*) FROM pass_dossier) <> 1
 THEN RAISE EXCEPTION 'FAIL: signed A must see exactly one dossier'; END IF;
 IF EXISTS(SELECT 1 FROM pass_dossier WHERE id='d4d4d4d4-d4d4-44d4-84d4-d4d4d4d4d4d4')
 THEN RAISE EXCEPTION 'FAIL: B visible to A before attack'; END IF;
END $$;
-- Deliberate identity tampering. This MUST NOT grant B's permissions.
SELECT set_config('app.current_user_id','82828282-8282-4282-8282-828282828282',true);
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM pass_dossier WHERE id='d4d4d4d4-d4d4-44d4-84d4-d4d4d4d4d4d4')
 THEN RAISE EXCEPTION 'SECURITY FAILURE: spoofed GUC granted access to B'; END IF;
END $$;
ROLLBACK;
