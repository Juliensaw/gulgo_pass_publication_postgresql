-- Ensure controlled-write functions are SECURITY DEFINER with safe search path.
BEGIN;
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_proc p
 JOIN pg_namespace ns ON ns.oid=p.pronamespace
 WHERE ns.nspname='public'
   AND p.proname IN ('gulgo_create_dossier','gulgo_append_observation')
   AND p.prosecdef
   AND 'search_path=pg_catalog, public, pg_temp' = ANY(p.proconfig);
 IF n <> 2 THEN RAISE EXCEPTION 'Expected two hardened SECURITY DEFINER functions, found %',n; END IF;
 IF EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace,
       LATERAL aclexplode(COALESCE(p.proacl, acldefault('f',p.proowner))) a
  WHERE ns.nspname='public'
    AND p.proname IN ('gulgo_create_dossier','gulgo_append_observation')
    AND a.grantee=0 AND a.privilege_type='EXECUTE'
 ) THEN RAISE EXCEPTION 'Public EXECUTE leaked on controlled-write functions'; END IF;
END $$;
ROLLBACK;
