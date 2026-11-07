-- V0.3: run as database owner after 001 and 002. No application-facing writes.
-- This role must NEVER own tables, have BYPASSRLS, CREATE, or be exposed to end users.
BEGIN;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='gulgo_api') THEN
    CREATE ROLE gulgo_api NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
  END IF;
END $$;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO gulgo_api;

-- Representation lookup is necessary for the existing RLS subject predicates.
ALTER TABLE subject_representation ENABLE ROW LEVEL SECURITY;
ALTER TABLE subject_representation FORCE ROW LEVEL SECURITY;
CREATE POLICY representation_self_read ON subject_representation
 FOR SELECT TO gulgo_api USING (user_id = gulgo_actor_id()
   AND valid_from <= CURRENT_DATE
   AND (valid_until IS NULL OR valid_until >= CURRENT_DATE));

-- Minimal read permissions; never grant writes directly to gulgo_api.
GRANT SELECT ON subject_representation, economic_subject, pass_dossier,
 variable_observation, evidence, evidence_link, commercial_relationship,
 commitment, commitment_event, incident, organization_practice,
 economic_vulnerability, control_finding, applicability_decision,
 assessment_run, assessment_result, evidence_assessment TO gulgo_api;

-- Avoid inadvertently granting execution on future privileged functions.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
-- Existing functions are callable only where explicitly granted.
REVOKE ALL ON FUNCTION gulgo_actor_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION gulgo_can_access_subject(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION gulgo_can_access_dossier(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gulgo_actor_id() TO gulgo_api;
GRANT EXECUTE ON FUNCTION gulgo_can_access_subject(UUID) TO gulgo_api;
GRANT EXECUTE ON FUNCTION gulgo_can_access_dossier(UUID) TO gulgo_api;
COMMIT;
