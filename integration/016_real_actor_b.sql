-- Separate real PostgreSQL login session; restricted to actor B.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.current_user_id','44444444-4444-4444-8444-444444444444',true);
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v13:44444444-4444-4444-8444-444444444444:' || txid_current()::text,'UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$
DECLARE v_observation uuid;
BEGIN
 IF session_user <> 'gulgo_runtime' OR current_user <> 'gulgo_api'
 THEN RAISE EXCEPTION 'Not a real restricted login'; END IF;
 IF (SELECT count(*) FROM pass_dossier) <> 1
 OR NOT EXISTS (SELECT 1 FROM pass_dossier WHERE id='dddddddd-4444-4444-8444-444444444444')
 OR EXISTS (SELECT 1 FROM pass_dossier WHERE id='cccccccc-3333-4333-8333-333333333333')
 THEN RAISE EXCEPTION 'Actor B dossier visibility failure'; END IF;
 IF EXISTS(SELECT 1 FROM variable_observation
           WHERE dossier_id='cccccccc-3333-4333-8333-333333333333')
 THEN RAISE EXCEPTION 'Actor B read actor A observations'; END IF;
 v_observation:=gulgo_append_observation(
  'dddddddd-4444-4444-8444-444444444444','CI-TWO-ACTOR-TEXT',
  '"Actor B observation"'::jsonb,'available');
 IF v_observation IS NULL
 OR NOT EXISTS(SELECT 1 FROM variable_observation WHERE id=v_observation)
 THEN RAISE EXCEPTION 'Actor B failed to write or read own observation'; END IF;
 BEGIN
  PERFORM gulgo_create_dossier('aaaaaaaa-3333-4333-8333-333333333333',
                               'GULGO_PASS_V1_PILOT');
  RAISE EXCEPTION 'Actor B created a dossier for actor A';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM gulgo_append_observation(
   'cccccccc-3333-4333-8333-333333333333','CI-TWO-ACTOR-TEXT',
   '"B forged A observation"'::jsonb,'available');
  RAISE EXCEPTION 'Actor B wrote into actor A dossier';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
COMMIT;
