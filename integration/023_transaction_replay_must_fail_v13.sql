-- A valid MAC from T1 must fail in a distinct transaction T2.
-- Disposable CI database only, using synthetic test key.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.actor_expires',(floor(extract(epoch from clock_timestamp()))::bigint + 30)::text,true);
SELECT encode(public.hmac(
  convert_to('gulgo-actor-v131:33333333-3333-4333-8333-333333333333:' || txid_current()::text || ':' || current_setting('app.actor_expires'),'UTF8'),
  decode(repeat('ab',32),'hex'),'sha256'),'hex') AS saved_mac \gset
SELECT set_config('app.current_user_id','33333333-3333-4333-8333-333333333333',true);
SELECT set_config('app.actor_mac',:'saved_mac',true);
DO $$
BEGIN
 IF public.gulgo_actor_id() IS DISTINCT FROM '33333333-3333-4333-8333-333333333333'::uuid
 THEN RAISE EXCEPTION 'Valid T1 signature rejected'; END IF;
END $$;
COMMIT;
BEGIN;
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.actor_expires',(floor(extract(epoch from clock_timestamp()))::bigint + 30)::text,true);
SELECT set_config('app.current_user_id','33333333-3333-4333-8333-333333333333',true);
SELECT set_config('app.actor_mac',:'saved_mac',true);
DO $$
BEGIN
 IF public.gulgo_actor_id() IS NOT NULL
 THEN RAISE EXCEPTION 'SECURITY FAILURE: T1 signature replayed in T2'; END IF;
END $$;
ROLLBACK;
