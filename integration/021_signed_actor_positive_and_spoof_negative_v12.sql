-- Positive AND negative acceptance on disposable PostgreSQL.
-- Synthetic test key only. Never reuse in any deployed environment.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.gulgo_identity_secret(id,secret)
VALUES(TRUE, decode(repeat('ab',32),'hex')) ON CONFLICT (id) DO NOTHING;
INSERT INTO app_user(id,external_auth_id) VALUES
 ('31313131-3131-4131-8131-313131313131','signed-test-a'),
 ('32323232-3232-4232-8232-323232323232','signed-test-b');
INSERT INTO economic_subject(id,kind,display_name) VALUES
 ('a3a3a3a3-a3a3-43a3-83a3-a3a3a3a3a3a3','individual','Signed A'),
 ('b3b3b3b3-b3b3-43b3-83b3-b3b3b3b3b3b3','individual','Signed B');
INSERT INTO subject_representation(subject_id,user_id,role,valid_from) VALUES
 ('a3a3a3a3-a3a3-43a3-83a3-a3a3a3a3a3a3','31313131-3131-4131-8131-313131313131','owner',CURRENT_DATE),
 ('b3b3b3b3-b3b3-43b3-83b3-b3b3b3b3b3b3','32323232-3232-4232-8232-323232323232','owner',CURRENT_DATE);
INSERT INTO pass_dossier(id,subject_id,methodology_id) VALUES
 ('c3c3c3c3-3131-4131-8131-313131313131','a3a3a3a3-a3a3-43a3-83a3-a3a3a3a3a3a3','GULGO_PASS_V1_PILOT'),
 ('d3d3d3d3-3232-4232-8232-323232323232','b3b3b3b3-b3b3-43b3-83b3-b3b3b3b3b3b3','GULGO_PASS_V1_PILOT');
INSERT INTO variable_definition(methodology_id,code,label,value_type)
 VALUES('GULGO_PASS_V1_PILOT','V12-SIGNED','Synthetic signed observation','text');
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.actor_expires',(floor(extract(epoch from clock_timestamp()))::bigint + 30)::text,true);
SELECT set_config('app.current_user_id','31313131-3131-4131-8131-313131313131',true);
-- Generate synthetic MAC as owner in a separate security-definer test helper,
-- never grant direct access to the production signing secret to gulgo_api.
-- MAC is generated from a known, synthetic key literal in this disposable test.
SELECT set_config('app.actor_mac',
 encode(public.hmac(convert_to('gulgo-actor-v131:31313131-3131-4131-8131-313131313131:' || txid_current()::text || ':' || current_setting('app.actor_expires'),'UTF8'),
 decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$
BEGIN
 IF public.gulgo_actor_id() IS DISTINCT FROM '31313131-3131-4131-8131-313131313131'::uuid
 THEN RAISE EXCEPTION 'VALID SIGNATURE REJECTED'; END IF;
 IF (SELECT count(*) FROM pass_dossier) <> 1
 THEN RAISE EXCEPTION 'Signed A must see exactly its own dossier'; END IF;
END $$;
-- Tampering with actor ID while keeping A's MAC must fail.
SELECT set_config('app.current_user_id','32323232-3232-4232-8232-323232323232',true);
DO $$
BEGIN
 IF public.gulgo_actor_id() IS NOT NULL
 THEN RAISE EXCEPTION 'SPOOFED ACTOR ACCEPTED'; END IF;
 IF EXISTS(SELECT 1 FROM pass_dossier)
 THEN RAISE EXCEPTION 'SPOOFED ACTOR CAN READ DOSSIERS'; END IF;
 BEGIN
  PERFORM gulgo_append_observation('d3d3d3d3-3232-4232-8232-323232323232',
   'V12-SIGNED','"forged"'::jsonb,'available');
  RAISE EXCEPTION 'SPOOFED ACTOR CAN WRITE';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
ROLLBACK;
