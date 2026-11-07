-- Disposable database: revocation must invalidate a previously valid MAC.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.gulgo_actor_key(key_id,secret,enabled)
VALUES ('revocation-test',decode(repeat('cd',32),'hex'),TRUE);
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.current_user_id','33333333-3333-4333-8333-333333333333',true);
SELECT set_config('app.actor_key_id','revocation-test',true);
SELECT set_config('app.actor_expires',(floor(extract(epoch from clock_timestamp()))::bigint + 30)::text,true);
SELECT set_config('app.actor_mac',encode(public.hmac(
 convert_to('gulgo-actor-v132:revocation-test:33333333-3333-4333-8333-333333333333:' || txid_current()::text || ':' || current_setting('app.actor_expires'),'UTF8'),
 decode(repeat('cd',32),'hex'),'sha256'),'hex'),true);
DO $$
BEGIN
 IF public.gulgo_actor_id() IS DISTINCT FROM '33333333-3333-4333-8333-333333333333'::uuid
 THEN RAISE EXCEPTION 'Valid test key rejected before revocation'; END IF;
END $$;
RESET ROLE;
UPDATE public.gulgo_actor_key SET enabled=FALSE WHERE key_id='revocation-test';
SET LOCAL ROLE gulgo_api;
DO $$
BEGIN
 IF public.gulgo_actor_id() IS NOT NULL
 THEN RAISE EXCEPTION 'SECURITY FAILURE: revoked key accepted'; END IF;
END $$;
ROLLBACK;
