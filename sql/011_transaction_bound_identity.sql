-- V1.3: bind signed actor to PostgreSQL transaction identifier.
-- Does NOT establish expiration, key rotation, or defense against SQL execution
-- inside the already authenticated transaction.
BEGIN;
CREATE OR REPLACE FUNCTION public.gulgo_actor_id() RETURNS UUID
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_actor TEXT := current_setting('app.current_user_id', true);
  v_mac TEXT := current_setting('app.actor_mac', true);
  v_secret BYTEA;
  v_expected TEXT;
BEGIN
  IF v_actor IS NULL OR v_mac IS NULL OR
     v_actor !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' OR
     v_mac !~ '^[0-9a-f]{64}$'
  THEN RETURN NULL; END IF;
  SELECT secret INTO v_secret FROM public.gulgo_identity_secret WHERE id=TRUE;
  IF v_secret IS NULL THEN RETURN NULL; END IF;
  v_expected := encode(public.hmac(
    convert_to('gulgo-actor-v13:' || v_actor || ':' || txid_current()::text, 'UTF8'),
    v_secret, 'sha256'), 'hex');
  IF v_expected <> v_mac THEN RETURN NULL; END IF;
  RETURN v_actor::UUID;
END $$;
REVOKE ALL ON FUNCTION public.gulgo_actor_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.gulgo_actor_id() TO gulgo_api;
COMMIT;
