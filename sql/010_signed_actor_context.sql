-- V1.2: authenticated actor context, fail closed until secret is provisioned.
-- Install as gulgo_owner. Requires pgcrypto from 001_init.sql.
-- Provision the secret OUT OF BAND, never in source control:
--   INSERT INTO gulgo_identity_secret(id, secret)
--   VALUES (true, decode('<64+ random hex characters>', 'hex'));
-- The runtime and API roles must never SELECT this table.
BEGIN;
CREATE TABLE IF NOT EXISTS public.gulgo_identity_secret (
  id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
  secret BYTEA NOT NULL CHECK (octet_length(secret) >= 32)
);
REVOKE ALL ON public.gulgo_identity_secret FROM PUBLIC, gulgo_api, gulgo_runtime;
ALTER TABLE public.gulgo_identity_secret ENABLE ROW LEVEL SECURITY;
-- Owner can access secret; runtime roles cannot.
CREATE OR REPLACE FUNCTION public.gulgo_actor_id() RETURNS UUID
LANGUAGE plpgsql STABLE SECURITY DEFINER
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
  -- Domain separation prevents reuse of the MAC for unrelated messages.
  v_expected := encode(public.hmac(convert_to('gulgo-actor-v12:' || v_actor, 'UTF8'),
                                   v_secret, 'sha256'), 'hex');
  IF v_expected <> v_mac THEN RETURN NULL; END IF;
  RETURN v_actor::UUID;
END $$;
REVOKE ALL ON FUNCTION public.gulgo_actor_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.gulgo_actor_id() TO gulgo_api;
COMMIT;
-- LIMITATION: a SQL-capable adversary who obtains another user's signed
-- context could replay it. Network isolation, no arbitrary SQL, short-lived
-- transaction scope and an independent security review remain mandatory.
