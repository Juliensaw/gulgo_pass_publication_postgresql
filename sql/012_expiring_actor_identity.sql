-- V1.3.1: transaction-bound actor MAC with mandatory expiry (Unix seconds).
-- Expiration cannot substitute for SQL execution isolation within a transaction.
BEGIN;
CREATE OR REPLACE FUNCTION public.gulgo_actor_id() RETURNS UUID
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
 v_actor TEXT := current_setting('app.current_user_id', true);
 v_mac TEXT := current_setting('app.actor_mac', true);
 v_exp TEXT := current_setting('app.actor_expires', true);
 v_secret BYTEA;
 v_expected TEXT;
 v_now BIGINT;
BEGIN
 IF v_actor IS NULL OR v_mac IS NULL OR v_exp IS NULL OR
    v_actor !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' OR
    v_mac !~ '^[0-9a-f]{64}$' OR v_exp !~ '^[0-9]{10,11}$'
 THEN RETURN NULL; END IF;
 v_now := floor(extract(epoch from clock_timestamp()))::bigint;
 IF v_exp::bigint <= v_now OR v_exp::bigint > v_now + 60
 THEN RETURN NULL; END IF;
 SELECT secret INTO v_secret FROM public.gulgo_identity_secret WHERE id=TRUE;
 IF v_secret IS NULL THEN RETURN NULL; END IF;
 v_expected := encode(public.hmac(
    convert_to('gulgo-actor-v131:' || v_actor || ':' || txid_current()::text || ':' || v_exp, 'UTF8'),
    v_secret, 'sha256'), 'hex');
 IF v_expected <> v_mac THEN RETURN NULL; END IF;
 RETURN v_actor::uuid;
END $$;
REVOKE ALL ON FUNCTION public.gulgo_actor_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.gulgo_actor_id() TO gulgo_api;
COMMIT;
