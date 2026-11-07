-- Disposable database ONLY. Run with psql -v ON_ERROR_STOP=1 -f integration/rls_isolation.sql
-- after migrations 001, 002, 003, as DB owner with permission to SET ROLE gulgo_api.
BEGIN;
INSERT INTO app_user(id,external_auth_id) VALUES
 ('11111111-1111-4111-8111-111111111111','test-a'),
 ('22222222-2222-4222-8222-222222222222','test-b');
INSERT INTO economic_subject(id,kind,display_name) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','individual','A'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','individual','B');
INSERT INTO subject_representation(subject_id,user_id,role,valid_from) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','owner',CURRENT_DATE),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','owner',CURRENT_DATE);
INSERT INTO pass_dossier(id,subject_id,methodology_id) VALUES
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','GULGO_PASS_V1_PILOT'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','GULGO_PASS_V1_PILOT');
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.current_user_id','11111111-1111-4111-8111-111111111111',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM pass_dossier) <> 1 THEN RAISE EXCEPTION 'A dossier isolation failed'; END IF;
 IF EXISTS (SELECT 1 FROM pass_dossier WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd') THEN RAISE EXCEPTION 'B leaked to A'; END IF;
 IF has_table_privilege(current_user,'pass_dossier','INSERT') THEN RAISE EXCEPTION 'Unexpected direct INSERT privilege'; END IF;
END $$;
SELECT set_config('app.current_user_id','22222222-2222-4222-8222-222222222222',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM pass_dossier) <> 1 THEN RAISE EXCEPTION 'B dossier isolation failed'; END IF;
 IF EXISTS (SELECT 1 FROM pass_dossier WHERE id='cccccccc-cccc-4ccc-8ccc-cccccccccccc') THEN RAISE EXCEPTION 'A leaked to B'; END IF;
END $$;
SELECT set_config('app.current_user_id','',true);
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM pass_dossier) THEN RAISE EXCEPTION 'Unset actor leaked dossiers'; END IF;
END $$;
ROLLBACK;
