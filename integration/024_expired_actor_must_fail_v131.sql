-- Disposable database: expiry is mandatory and authenticated.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE gulgo_api;
SELECT set_config('app.current_user_id','33333333-3333-4333-8333-333333333333',true);
SELECT set_config('app.actor_expires',(floor(extract(epoch from clock_timestamp()))::bigint - 1)::text,true);
SELECT set_config('app.actor_key_id','primary',true);
SELECT set_config('app.actor_mac',encode(public.hmac(
 convert_to('gulgo-actor-v132:primary:33333333-3333-4333-8333-333333333333:' || txid_current()::text || ':' || current_setting('app.actor_expires'),'UTF8'),
 decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$
BEGIN
 IF public.gulgo_actor_id() IS NOT NULL
 THEN RAISE EXCEPTION 'SECURITY FAILURE: expired signed actor accepted'; END IF;
END $$;
SELECT set_config('app.actor_expires',(floor(extract(epoch from clock_timestamp()))::bigint + 3600)::text,true);
SELECT set_config('app.actor_key_id','primary',true);
SELECT set_config('app.actor_mac',encode(public.hmac(
 convert_to('gulgo-actor-v132:primary:33333333-3333-4333-8333-333333333333:' || txid_current()::text || ':' || current_setting('app.actor_expires'),'UTF8'),
 decode(repeat('ab',32),'hex'),'sha256'),'hex'),true);
DO $$
BEGIN
 IF public.gulgo_actor_id() IS NOT NULL
 THEN RAISE EXCEPTION 'SECURITY FAILURE: unbounded future signature accepted'; END IF;
END $$;
ROLLBACK;
