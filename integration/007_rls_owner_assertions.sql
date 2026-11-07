-- Run as trusted database owner after migration 006.
-- Tests that the API role is not table owner, does not bypass RLS, and
-- that application tables retain RLS while trusted owner can write.
DO $$
DECLARE v_bypass boolean; v_login boolean; v_super boolean; v_count integer;
BEGIN
 SELECT rolbypassrls, rolcanlogin, rolsuper INTO v_bypass,v_login,v_super
 FROM pg_roles WHERE rolname='gulgo_api';
 IF NOT FOUND OR v_bypass OR v_login OR v_super THEN
  RAISE EXCEPTION 'Unsafe gulgo_api role'; END IF;
 SELECT count(*) INTO v_count FROM pg_class c
 JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN ('economic_subject','pass_dossier','variable_observation','subject_representation')
 AND c.relrowsecurity AND NOT c.relforcerowsecurity
 AND c.relowner <> (SELECT oid FROM pg_roles WHERE rolname='gulgo_api');
 IF v_count<>4 THEN RAISE EXCEPTION 'RLS owner compatibility failed: %',v_count; END IF;
 IF has_table_privilege('gulgo_api','public.pass_dossier','INSERT')
 OR has_table_privilege('gulgo_api','public.variable_observation','UPDATE')
 THEN RAISE EXCEPTION 'API role has direct write privileges'; END IF;
END $$;
