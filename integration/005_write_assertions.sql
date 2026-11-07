-- Integration test, owner connection, temporary fixtures, transaction rollback.
-- SECURITY DEFINER functions called with SET LOCAL ROLE gulgo_api.
BEGIN;
INSERT INTO app_user(id,external_auth_id) VALUES
 ('11111111-1111-4111-8111-111111111111','write-test-a'),
 ('22222222-2222-4222-8222-222222222222','write-test-b');
INSERT INTO economic_subject(id,kind,display_name) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','individual','Write A'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','individual','Write B');
INSERT INTO subject_representation(subject_id,user_id,role,valid_from) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','owner',CURRENT_DATE),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','owner',CURRENT_DATE);
INSERT INTO variable_definition(methodology_id,code,label,value_type) VALUES
 ('GULGO_PASS_V1_PILOT','ECO-002','Montant','number');
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.current_user_id','11111111-1111-4111-8111-111111111111',true);
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v12:11111111-1111-4111-8111-111111111111','UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$
DECLARE v_dossier uuid; v_observation uuid; v_audit int;
BEGIN
 v_dossier:=gulgo_create_dossier('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','GULGO_PASS_V1_PILOT');
 IF v_dossier IS NULL THEN RAISE EXCEPTION 'No dossier created'; END IF;
 v_observation:=gulgo_append_observation(v_dossier,'ECO-002','120'::jsonb,'available');
 IF v_observation IS NULL THEN RAISE EXCEPTION 'No observation created'; END IF;
 IF (SELECT count(*) FROM pass_dossier WHERE id=v_dossier)<>1 THEN RAISE EXCEPTION 'Created dossier invisible'; END IF;
 IF (SELECT count(*) FROM variable_observation WHERE id=v_observation)<>1 THEN RAISE EXCEPTION 'Created observation invisible'; END IF;
 -- Switch to owner for audit visibility (app role has no audit SELECT).
 PERFORM set_config('app.test_created_dossier',v_dossier::text,true);
END $$;
DO $$
BEGIN
 BEGIN
  PERFORM gulgo_create_dossier('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','GULGO_PASS_V1_PILOT');
  RAISE EXCEPTION 'Cross-tenant write unexpectedly succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
SELECT set_config('app.current_user_id','22222222-2222-4222-8222-222222222222',true);
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v12:22222222-2222-4222-8222-222222222222','UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$
DECLARE v_dossier uuid;
BEGIN
 v_dossier:=current_setting('app.test_created_dossier')::uuid;
 BEGIN
  PERFORM gulgo_append_observation(v_dossier,'ECO-002','200'::jsonb,'available');
  RAISE EXCEPTION 'Cross-tenant observation unexpectedly succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
RESET ROLE;
DO $$
DECLARE v_dossier uuid;
BEGIN
 v_dossier:=current_setting('app.test_created_dossier')::uuid;
 IF (SELECT count(*) FROM audit_event WHERE object_id=v_dossier AND action='created')<>1
 THEN RAISE EXCEPTION 'Missing dossier audit'; END IF;
 IF (SELECT count(*) FROM audit_event WHERE object_type='variable_observation' AND detail->>'dossier_id'=v_dossier::text)<>1
 THEN RAISE EXCEPTION 'Missing observation audit'; END IF;
END $$;
ROLLBACK;
