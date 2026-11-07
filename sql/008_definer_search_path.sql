-- V1.1: harden SECURITY DEFINER function name resolution.
-- pg_catalog first; pg_temp last. Public CREATE is revoked in 003.
-- No change to the GUC-based identity trust model: see SECURITY_IDENTITY_DECISION_V11.md.
BEGIN;
ALTER FUNCTION public.gulgo_create_dossier(UUID,TEXT)
  SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION public.gulgo_append_observation(UUID,TEXT,JSONB,TEXT,DATE,DATE,TEXT,UUID)
  SET search_path = pg_catalog, public, pg_temp;
DO $$
DECLARE fn record;
BEGIN
 FOR fn IN
  SELECT p.oid, p.proname, p.prosecdef,
         array_to_string(p.proconfig, ',') AS settings
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname IN ('gulgo_create_dossier','gulgo_append_observation')
 LOOP
  IF NOT fn.prosecdef OR fn.settings NOT LIKE '%search_path=pg_catalog, public, pg_temp%'
  THEN RAISE EXCEPTION 'Unsafe function search path: %',fn.proname; END IF;
 END LOOP;
END $$;
COMMIT;
