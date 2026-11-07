-- Disposable PostgreSQL CI database ONLY. Committed fixtures for separate real sessions.
-- This test intentionally does not run in a rollback transaction: the subsequent
-- authenticated gulgo_runtime sessions must see these records.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO app_user (id,external_auth_id) VALUES
 ('33333333-3333-4333-8333-333333333333','ci-real-actor-a'),
 ('44444444-4444-4444-8444-444444444444','ci-real-actor-b');
INSERT INTO economic_subject (id,kind,display_name) VALUES
 ('aaaaaaaa-3333-4333-8333-333333333333','individual','CI fictitious actor A'),
 ('bbbbbbbb-4444-4444-8444-444444444444','organization','CI fictitious actor B');
INSERT INTO subject_representation(subject_id,user_id,role,valid_from) VALUES
 ('aaaaaaaa-3333-4333-8333-333333333333','33333333-3333-4333-8333-333333333333','owner',CURRENT_DATE),
 ('bbbbbbbb-4444-4444-8444-444444444444','44444444-4444-4444-8444-444444444444','owner',CURRENT_DATE);
INSERT INTO pass_dossier(id,subject_id,methodology_id) VALUES
 ('cccccccc-3333-4333-8333-333333333333','aaaaaaaa-3333-4333-8333-333333333333','GULGO_PASS_V1_PILOT'),
 ('dddddddd-4444-4444-8444-444444444444','bbbbbbbb-4444-4444-8444-444444444444','GULGO_PASS_V1_PILOT');
INSERT INTO variable_definition(methodology_id,code,label,value_type) VALUES
 ('GULGO_PASS_V1_PILOT','CI-TWO-ACTOR-TEXT','CI fictitious observation','text');
COMMIT;
