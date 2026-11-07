-- Adversarial test documenting a KNOWN VULNERABILITY.
-- Any client able to execute arbitrary SQL as gulgo_api can overwrite the
-- custom identity GUC and read another tenant's RLS-protected records.
-- This test intentionally passes only if the vulnerability is reproduced.
-- Run on disposable CI database only; fixtures rolled back.
BEGIN;
INSERT INTO app_user(id,external_auth_id) VALUES
 ('11111111-1111-4111-8111-111111111111','spoof-test-a'),
 ('22222222-2222-4222-8222-222222222222','spoof-test-b');
INSERT INTO economic_subject(id,kind,display_name) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','individual','Spoof A'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','individual','Spoof B');
INSERT INTO subject_representation(subject_id,user_id,role,valid_from) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','owner',CURRENT_DATE),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','owner',CURRENT_DATE);
INSERT INTO pass_dossier(id,subject_id,methodology_id) VALUES
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','GULGO_PASS_V1_PILOT'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','GULGO_PASS_V1_PILOT');
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.current_user_id','11111111-1111-4111-8111-111111111111',true);
DO $$
BEGIN
 IF EXISTS (SELECT 1 FROM pass_dossier WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd')
 THEN RAISE EXCEPTION 'Baseline isolation already broken'; END IF;
END $$;
-- Attack: an SQL-capable client changes its identity without any JWT.
SELECT set_config('app.current_user_id','22222222-2222-4222-8222-222222222222',true);
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pass_dossier WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd')
 THEN RAISE EXCEPTION 'Expected GUC spoofing reproduction was not observed'; END IF;
 RAISE NOTICE 'KNOWN RISK CONFIRMED: arbitrary SQL can impersonate tenant B via session GUC';
END $$;
ROLLBACK;
