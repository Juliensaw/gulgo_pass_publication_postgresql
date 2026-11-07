-- V0.8 integration assertions; owner connection, rollback-only fixtures.
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.gulgo_create_dossier(uuid,text)') IS NULL THEN
  RAISE EXCEPTION 'Missing controlled write function'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public'
  AND indexname='uq_observation_supersedes_once') THEN
  RAISE EXCEPTION 'Missing unique supersession index'; END IF;
 IF has_schema_privilege('gulgo_api','public','CREATE') THEN
  RAISE EXCEPTION 'Application role can create in public schema'; END IF;
 IF has_table_privilege('gulgo_api','variable_observation','UPDATE') THEN
  RAISE EXCEPTION 'Application role can update immutable observations'; END IF;
 IF NOT has_function_privilege('gulgo_api','public.gulgo_append_observation(uuid,text,jsonb,text,date,date,text,uuid)','EXECUTE') THEN
  RAISE EXCEPTION 'App role cannot execute controlled append'; END IF;
 -- The ACL represents PUBLIC as grantee OID 0.
 IF EXISTS (
  SELECT 1 FROM pg_proc AS p
  CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) AS acl
  WHERE p.oid = 'public.gulgo_append_observation(uuid,text,jsonb,text,date,date,text,uuid)'::regprocedure
    AND acl.grantee = 0 AND acl.privilege_type = 'EXECUTE'
 ) THEN
  RAISE EXCEPTION 'Public can execute controlled append'; END IF;
END $$;
ROLLBACK;
