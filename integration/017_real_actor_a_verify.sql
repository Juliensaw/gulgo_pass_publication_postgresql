-- Read-after-write isolation across three independent PostgreSQL connections.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.current_user_id','33333333-3333-4333-8333-333333333333',true);
SELECT set_config('app.actor_mac',encode(public.hmac(convert_to('gulgo-actor-v13:33333333-3333-4333-8333-333333333333:' || txid_current()::text,'UTF8'),decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$
BEGIN
 IF session_user <> 'gulgo_runtime' THEN
  RAISE EXCEPTION 'Must use actual login'; END IF;
 IF (SELECT count(*) FROM variable_observation
     WHERE dossier_id='cccccccc-3333-4333-8333-333333333333') <> 1
 THEN RAISE EXCEPTION 'Actor A observation missing after independent session'; END IF;
 IF EXISTS (SELECT 1 FROM variable_observation
            WHERE dossier_id='dddddddd-4444-4444-8444-444444444444')
 THEN RAISE EXCEPTION 'Actor B observation leaked into actor A context'; END IF;
END $$;
ROLLBACK;
