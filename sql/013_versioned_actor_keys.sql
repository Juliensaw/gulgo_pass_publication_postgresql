-- V1.3.2: versioned signing keys; owner-controlled rotation and revocation.
-- Only one active key per request; old keys can be revoked immediately.
BEGIN;
CREATE TABLE public.gulgo_actor_key (
 key_id TEXT PRIMARY KEY CHECK (key_id ~ '^[a-z0-9_-]{1,32}$'),
 secret BYTEA NOT NULL CHECK (octet_length(secret) >= 32),
 enabled BOOLEAN NOT NULL DEFAULT FALSE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON public.gulgo_actor_key FROM PUBLIC, gulgo_api, gulgo_runtime;
ALTER TABLE public.gulgo_actor_key ENABLE ROW LEVEL SECURITY;
-- Migration of the existing key is performed by the owner, without exposing it.
INSERT INTO public.gulgo_actor_key(key_id,secret,enabled)
SELECT 'primary', secret, TRUE FROM public.gulgo_identity_secret WHERE id=TRUE
ON CONFLICT (key_id) DO NOTHING;
CREATE OR REPLACE FUNCTION public.gulgo_actor_id() RETURNS UUID
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
 v_actor TEXT := current_setting('app.current_user_id', true);
 v_mac TEXT := current_setting('app.actor_mac', true);
 v_exp TEXT := current_setting('app.actor_expires', true);
 v_key TEXT := current_setting('app.actor_key_id', true);
 v_secret BYTEA;
 v_expected TEXT;
 v_now BIGINT;
BEGIN
 IF v_actor IS NULL OR v_mac IS NULL OR v_exp IS NULL OR v_key IS NULL OR
    v_actor !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' OR
    v_mac !~ '^[0-9a-f]{64}$' OR v_exp !~ '^[0-9]{10,11}$' OR
    v_key !~ '^[a-z0-9_-]{1,32}$'
 THEN RETURN NULL; END IF;
 v_now := floor(extract(epoch from clock_timestamp()))::bigint;
 IF v_exp::bigint <= v_now OR v_exp::bigint > v_now + 60 THEN RETURN NULL; END IF;
 SELECT secret INTO v_secret FROM public.gulgo_actor_key
 WHERE key_id=v_key AND enabled=TRUE;
 IF v_secret IS NULL THEN RETURN NULL; END IF;
 v_expected := encode(public.hmac(
  convert_to('gulgo-actor-v132:' || v_key || ':' || v_actor || ':' || txid_current()::text || ':' || v_exp,'UTF8'),
  v_secret,'sha256'),'hex');
 IF v_expected <> v_mac THEN RETURN NULL; END IF;
 RETURN v_actor::uuid;
END $$;
REVOKE ALL ON FUNCTION public.gulgo_actor_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.gulgo_actor_id() TO gulgo_api;
COMMIT;
