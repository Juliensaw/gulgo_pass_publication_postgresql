-- Adversarial security characterization on disposable database ONLY.
-- This test PASSES if and only if the known identity-spoofing vulnerability
-- is reproduced. It is NOT a security fix and must remain a release blocker.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO app_user(id,external_auth_id) VALUES
 ('55555555-5555-4555-8555-555555555555','attack-characterization-a'),
 ('66666666-6666-4666-8666-666666666666','attack-characterization-b');
INSERT INTO economic_subject(id,kind,display_name) VALUES
 ('aaaaaaaa-5555-4555-8555-555555555555','individual','Attack A synthetic'),
 ('bbbbbbbb-6666-4666-8666-666666666666','individual','Attack B synthetic');
INSERT INTO subject_representation(subject_id,user_id,role,valid_from) VALUES
 ('aaaaaaaa-5555-4555-8555-555555555555','55555555-5555-4555-8555-555555555555','owner',CURRENT_DATE),
 ('bbbbbbbb-6666-4666-8666-666666666666','66666666-6666-4666-8666-666666666666','owner',CURRENT_DATE);
INSERT INTO pass_dossier(id,subject_id,methodology_id) VALUES
 ('cccccccc-5555-4555-8555-555555555555','aaaaaaaa-5555-4555-8555-555555555555','GULGO_PASS_V1_PILOT'),
 ('dddddddd-6666-4666-8666-666666666666','bbbbbbbb-6666-4666-8666-666666666666','GULGO_PASS_V1_PILOT');
INSERT INTO variable_definition(methodology_id,code,label,value_type)
 VALUES('GULGO_PASS_V1_PILOT','CI-ATTACK-TEXT','Attack synthetic variable','text');
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.current_user_id','55555555-5555-4555-8555-555555555555',true);
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM pass_dossier WHERE id='dddddddd-6666-4666-8666-666666666666')
 THEN RAISE EXCEPTION 'Attack baseline failed: B visible before spoofing'; END IF;
END $$;
-- SQL-capable adversary impersonates B without a valid B JWT.
SELECT set_config('app.current_user_id','66666666-6666-4666-8666-666666666666',true);
DO $$
DECLARE created_id uuid;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pass_dossier WHERE id='dddddddd-6666-4666-8666-666666666666')
 THEN RAISE EXCEPTION 'Expected read impersonation not reproduced'; END IF;
 created_id:=gulgo_append_observation(
  'dddddddd-6666-4666-8666-666666666666','CI-ATTACK-TEXT',
  '"synthetic unauthorized write"'::jsonb,'available');
 IF created_id IS NULL OR NOT EXISTS(
  SELECT 1 FROM variable_observation WHERE id=created_id
 ) THEN RAISE EXCEPTION 'Expected write impersonation not reproduced'; END IF;
 RAISE NOTICE 'SECURITY BLOCKER: SQL actor spoofing enables read AND write under victim identity';
END $$;
ROLLBACK;
