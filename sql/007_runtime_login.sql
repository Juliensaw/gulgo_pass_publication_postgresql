-- V1.1: a dedicated, non-owner login; secrets provisioned outside migrations.
-- Requires PostgreSQL 16 for role membership options.
BEGIN;
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='gulgo_runtime') THEN
   CREATE ROLE gulgo_runtime LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
 END IF;
END $$;
-- Revoke inherited access: only an explicit SET LOCAL ROLE can activate app privileges.
GRANT gulgo_api TO gulgo_runtime WITH INHERIT FALSE, SET TRUE;
REVOKE CREATE ON SCHEMA public FROM gulgo_runtime;
DO $$
DECLARE runtime_role record; api_role record;
BEGIN
 SELECT * INTO runtime_role FROM pg_roles WHERE rolname='gulgo_runtime';
 SELECT * INTO api_role FROM pg_roles WHERE rolname='gulgo_api';
 IF NOT FOUND OR runtime_role.rolsuper OR runtime_role.rolbypassrls
 OR runtime_role.rolcreaterole OR runtime_role.rolcreatedb
 OR runtime_role.rolinherit OR NOT runtime_role.rolcanlogin
 OR api_role.rolcanlogin OR api_role.rolsuper OR api_role.rolbypassrls
 THEN RAISE EXCEPTION 'Unsafe GULGO runtime role configuration'; END IF;
END $$;
COMMIT;
-- Set a strong password using a secret manager or configure an external
-- authentication mechanism. NEVER commit a password or use gulgo_owner in the API DSN.
