-- V0.8: immutable correction chain and least-privilege defense-in-depth.
-- Apply after 004 in a disposable database; review before production.
BEGIN;
-- Prevent two concurrent corrections from superseding the same observation.
CREATE UNIQUE INDEX IF NOT EXISTS uq_observation_supersedes_once
  ON variable_observation(supersedes_id) WHERE supersedes_id IS NOT NULL;
-- Prevent an observation from superseding itself (also guarded by FK).
ALTER TABLE variable_observation ADD CONSTRAINT ck_no_self_supersession
  CHECK (supersedes_id IS NULL OR supersedes_id <> id);
-- Explicitly deny public execution of privileged write functions.
REVOKE ALL ON FUNCTION public.gulgo_create_dossier(UUID,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.gulgo_append_observation(UUID,TEXT,JSONB,TEXT,DATE,DATE,TEXT,UUID) FROM PUBLIC;
-- Application role must not be allowed to alter schemas or tables.
REVOKE CREATE ON SCHEMA public FROM gulgo_api;
COMMIT;
