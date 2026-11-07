-- Execute in a disposable PostgreSQL database only.
BEGIN;
INSERT INTO app_user(id,external_auth_id) VALUES
 ('11111111-1111-4111-8111-111111111111','security-test-a'),
 ('22222222-2222-4222-8222-222222222222','security-test-b');
INSERT INTO economic_subject(id,kind,display_name) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','individual','Test A'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','individual','Test B');
INSERT INTO subject_representation(subject_id,user_id,role,valid_from) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','owner',CURRENT_DATE),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','owner',CURRENT_DATE);
INSERT INTO pass_dossier(id,subject_id,methodology_id) VALUES
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','GULGO_PASS_V1_PILOT'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','GULGO_PASS_V1_PILOT');
SET LOCAL ROLE gulgo_api;
DO $$ BEGIN
 IF has_table_privilege(current_user,'pass_dossier','INSERT') THEN RAISE EXCEPTION 'INSERT privilege leaked'; END IF;
 IF has_table_privilege(current_user,'variable_observation','UPDATE') THEN RAISE EXCEPTION 'UPDATE privilege leaked'; END IF;
 IF has_table_privilege(current_user,'audit_event','SELECT') THEN RAISE EXCEPTION 'Audit table readable'; END IF;
END $$;
SELECT set_config('app.current_user_id','11111111-1111-4111-8111-111111111111',true);
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v13:11111111-1111-4111-8111-111111111111:' || txid_current()::text,'UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$ BEGIN
 IF (SELECT count(*) FROM pass_dossier) <> 1 THEN RAISE EXCEPTION 'A must see exactly one dossier'; END IF;
 IF EXISTS(SELECT 1 FROM pass_dossier WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd') THEN RAISE EXCEPTION 'Cross-tenant leak'; END IF;
 IF (SELECT count(*) FROM economic_subject) <> 1 THEN RAISE EXCEPTION 'Subject isolation failure'; END IF;
END $$;
SELECT set_config('app.current_user_id','22222222-2222-4222-8222-222222222222',true);
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v13:22222222-2222-4222-8222-222222222222:' || txid_current()::text,'UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$ BEGIN
 IF (SELECT count(*) FROM pass_dossier) <> 1 THEN RAISE EXCEPTION 'B must see exactly one dossier'; END IF;
 IF EXISTS(SELECT 1 FROM pass_dossier WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc') THEN RAISE EXCEPTION 'Cross-tenant leak'; END IF;
END $$;
SELECT set_config('app.current_user_id','',true);
SELECT set_config('app.actor_mac','',true);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pass_dossier) THEN RAISE EXCEPTION 'No-actor access leak'; END IF;
END $$;
ROLLBACK;
