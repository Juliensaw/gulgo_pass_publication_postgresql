-- GULGO PASS 0.2. Apply AFTER 001_init.sql in a disposable PostgreSQL database.
-- Assumptions: PostgreSQL >=14; authenticated API sets app.current_user_id via SET LOCAL
-- inside EACH transaction. Never expose direct SQL or SET permissions to end users.
BEGIN;

-- Business objects for D3-D6. Economic observations stay in variable_observation.
CREATE TABLE commercial_relationship (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), dossier_id UUID NOT NULL REFERENCES pass_dossier(id),
 relationship_type TEXT NOT NULL CHECK (relationship_type IN ('client','supplier','partner','other')),
 counterparty_ref TEXT NOT NULL, started_on DATE, ended_on DATE,
 CHECK (ended_on IS NULL OR started_on IS NULL OR ended_on >= started_on), UNIQUE(id,dossier_id)
);
CREATE TABLE commitment (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), dossier_id UUID NOT NULL REFERENCES pass_dossier(id),
 relationship_id UUID NOT NULL, kind TEXT NOT NULL, due_on DATE NOT NULL,
 status TEXT NOT NULL CHECK (status IN ('open','fulfilled','late','unfulfilled','disputed')),
 FOREIGN KEY (relationship_id,dossier_id) REFERENCES commercial_relationship(id,dossier_id), UNIQUE(id,dossier_id)
);
CREATE TABLE commitment_event (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), dossier_id UUID NOT NULL REFERENCES pass_dossier(id),
 commitment_id UUID NOT NULL, event_type TEXT NOT NULL CHECK (event_type IN ('created','due_date_changed','fulfilled','disputed','reviewed')),
 occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(), detail JSONB NOT NULL DEFAULT '{}'::jsonb,
 FOREIGN KEY(commitment_id,dossier_id) REFERENCES commitment(id,dossier_id)
);
CREATE TABLE incident (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), dossier_id UUID NOT NULL REFERENCES pass_dossier(id),
 commitment_id UUID, incident_type TEXT NOT NULL, occurred_on DATE,
 dispute_status TEXT NOT NULL CHECK(dispute_status IN ('not_disputed','disputed','adjudicated','unknown')),
 resolution_status TEXT NOT NULL CHECK(resolution_status IN ('open','resolved','unresolved','unknown')),
 resolved_on DATE, FOREIGN KEY(commitment_id,dossier_id) REFERENCES commitment(id,dossier_id),
 CHECK(resolved_on IS NULL OR resolution_status='resolved')
);
CREATE TABLE organization_practice (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), dossier_id UUID NOT NULL REFERENCES pass_dossier(id),
 function_code TEXT NOT NULL, tool_type TEXT NOT NULL, use_frequency TEXT,
 observed_on DATE, note TEXT
);
CREATE TABLE economic_vulnerability (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), dossier_id UUID NOT NULL REFERENCES pass_dossier(id),
 vulnerability_type TEXT NOT NULL, started_on DATE, ended_on DATE,
 status TEXT NOT NULL CHECK(status IN ('active','resolved','undetermined')),
 observed_impact TEXT, mitigation TEXT,
 CHECK(ended_on IS NULL OR started_on IS NULL OR ended_on>=started_on)
);
CREATE TABLE sharing_authorization (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), subject_id UUID NOT NULL REFERENCES economic_subject(id),
 partner_user_id UUID NOT NULL REFERENCES app_user(id),
 granted_by UUID NOT NULL REFERENCES app_user(id),
 scope TEXT NOT NULL CHECK(scope IN ('view_subject','view_dossiers')),
 valid_from TIMESTAMPTZ NOT NULL DEFAULT now(), valid_until TIMESTAMPTZ,
 revoked_at TIMESTAMPTZ, CHECK(valid_until IS NULL OR valid_until>=valid_from)
);

-- Cross-dossier and methodology integrity, including supersession.
ALTER TABLE variable_observation ADD CONSTRAINT uq_obs_id_dossier_method UNIQUE(id,dossier_id,methodology_id);
ALTER TABLE pass_dossier ADD CONSTRAINT uq_dossier_id_method UNIQUE(id,methodology_id);
ALTER TABLE variable_observation ADD CONSTRAINT fk_observation_dossier_method
 FOREIGN KEY(dossier_id,methodology_id) REFERENCES pass_dossier(id,methodology_id);
ALTER TABLE variable_observation ADD CONSTRAINT fk_supersession_same_dossier_method
 FOREIGN KEY(supersedes_id,dossier_id,methodology_id) REFERENCES variable_observation(id,dossier_id,methodology_id);
ALTER TABLE applicability_decision ADD CONSTRAINT fk_applicability_dossier_method
 FOREIGN KEY(dossier_id,methodology_id) REFERENCES pass_dossier(id,methodology_id);
ALTER TABLE assessment_run ADD CONSTRAINT uq_run_id_method UNIQUE(id,methodology_id);
ALTER TABLE assessment_run ADD CONSTRAINT fk_run_dossier_method
 FOREIGN KEY(dossier_id,methodology_id) REFERENCES pass_dossier(id,methodology_id);

-- Make evaluation results reference a real indicator from the same methodology release.
ALTER TABLE assessment_result ADD COLUMN methodology_id TEXT;
UPDATE assessment_result r SET methodology_id = a.methodology_id FROM assessment_run a WHERE a.id=r.run_id;
ALTER TABLE assessment_result ALTER COLUMN methodology_id SET NOT NULL;
ALTER TABLE assessment_result ADD CONSTRAINT fk_result_run_method
 FOREIGN KEY(run_id,methodology_id) REFERENCES assessment_run(id,methodology_id);
ALTER TABLE assessment_result ADD CONSTRAINT fk_result_indicator_method
 FOREIGN KEY(methodology_id,indicator_code) REFERENCES indicator_definition(methodology_id,code);

-- Restrict source edits after creation: correction via new observation with supersedes_id.
CREATE FUNCTION gulgo_forbid_update_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Immutable record: create a superseding record instead'; END $$;
CREATE TRIGGER immutable_observation BEFORE UPDATE OR DELETE ON variable_observation
 FOR EACH ROW EXECUTE FUNCTION gulgo_forbid_update_delete();
CREATE TRIGGER immutable_evidence BEFORE UPDATE OR DELETE ON evidence
 FOR EACH ROW EXECUTE FUNCTION gulgo_forbid_update_delete();
CREATE TRIGGER immutable_evidence_link BEFORE UPDATE OR DELETE ON evidence_link
 FOR EACH ROW EXECUTE FUNCTION gulgo_forbid_update_delete();
CREATE TRIGGER immutable_evidence_assessment BEFORE UPDATE OR DELETE ON evidence_assessment
 FOR EACH ROW EXECUTE FUNCTION gulgo_forbid_update_delete();
CREATE TRIGGER immutable_assessment_run BEFORE UPDATE OR DELETE ON assessment_run
 FOR EACH ROW EXECUTE FUNCTION gulgo_forbid_update_delete();
CREATE TRIGGER immutable_assessment_result BEFORE UPDATE OR DELETE ON assessment_result
 FOR EACH ROW EXECUTE FUNCTION gulgo_forbid_update_delete();
CREATE TRIGGER immutable_audit_event BEFORE UPDATE OR DELETE ON audit_event
 FOR EACH ROW EXECUTE FUNCTION gulgo_forbid_update_delete();
CREATE TRIGGER immutable_methodology BEFORE UPDATE OR DELETE ON methodology_release
 FOR EACH ROW EXECUTE FUNCTION gulgo_forbid_update_delete();

-- Authenticated user context, fail closed when unset or invalid.
CREATE FUNCTION gulgo_actor_id() RETURNS UUID LANGUAGE plpgsql STABLE AS $$
BEGIN RETURN NULLIF(current_setting('app.current_user_id',true),'')::UUID;
EXCEPTION WHEN invalid_text_representation THEN RETURN NULL;
END $$;
CREATE FUNCTION gulgo_can_access_subject(p_subject UUID) RETURNS BOOLEAN
 LANGUAGE sql STABLE SECURITY INVOKER AS $$
 SELECT EXISTS (
 SELECT 1 FROM subject_representation sr
 WHERE sr.subject_id=p_subject AND sr.user_id=gulgo_actor_id()
 AND sr.valid_from<=CURRENT_DATE AND (sr.valid_until IS NULL OR sr.valid_until>=CURRENT_DATE)
 )
 $$;
CREATE FUNCTION gulgo_can_access_dossier(p_dossier UUID) RETURNS BOOLEAN
 LANGUAGE sql STABLE SECURITY INVOKER AS $$
 SELECT EXISTS(SELECT 1 FROM pass_dossier d WHERE d.id=p_dossier AND gulgo_can_access_subject(d.subject_id))
 $$;

-- RLS is a defense-in-depth barrier. Application still must authorize EVERY action.
-- App connection role MUST be non-owner, without BYPASSRLS, and without CREATE rights.
ALTER TABLE economic_subject ENABLE ROW LEVEL SECURITY;
ALTER TABLE economic_subject FORCE ROW LEVEL SECURITY;
CREATE POLICY subject_select ON economic_subject FOR SELECT USING(gulgo_can_access_subject(id));
ALTER TABLE pass_dossier ENABLE ROW LEVEL SECURITY;
ALTER TABLE pass_dossier FORCE ROW LEVEL SECURITY;
CREATE POLICY dossier_select ON pass_dossier FOR SELECT USING(gulgo_can_access_subject(subject_id));
ALTER TABLE variable_observation ENABLE ROW LEVEL SECURITY;
ALTER TABLE variable_observation FORCE ROW LEVEL SECURITY;
CREATE POLICY observation_select ON variable_observation FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence FORCE ROW LEVEL SECURITY;
CREATE POLICY evidence_select ON evidence FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE evidence_link ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_link FORCE ROW LEVEL SECURITY;
CREATE POLICY evidence_link_select ON evidence_link FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE commercial_relationship ENABLE ROW LEVEL SECURITY;
ALTER TABLE commercial_relationship FORCE ROW LEVEL SECURITY;
CREATE POLICY relationship_select ON commercial_relationship FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE commitment ENABLE ROW LEVEL SECURITY;
ALTER TABLE commitment FORCE ROW LEVEL SECURITY;
CREATE POLICY commitment_select ON commitment FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE incident ENABLE ROW LEVEL SECURITY;
ALTER TABLE incident FORCE ROW LEVEL SECURITY;
CREATE POLICY incident_select ON incident FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE organization_practice ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_practice FORCE ROW LEVEL SECURITY;
CREATE POLICY practice_select ON organization_practice FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE economic_vulnerability ENABLE ROW LEVEL SECURITY;
ALTER TABLE economic_vulnerability FORCE ROW LEVEL SECURITY;
CREATE POLICY vulnerability_select ON economic_vulnerability FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE commitment_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE commitment_event FORCE ROW LEVEL SECURITY;
CREATE POLICY commitment_event_select ON commitment_event FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE control_finding ENABLE ROW LEVEL SECURITY;
ALTER TABLE control_finding FORCE ROW LEVEL SECURITY;
CREATE POLICY finding_select ON control_finding FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE applicability_decision ENABLE ROW LEVEL SECURITY;
ALTER TABLE applicability_decision FORCE ROW LEVEL SECURITY;
CREATE POLICY applicability_select ON applicability_decision FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE assessment_run ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_run FORCE ROW LEVEL SECURITY;
CREATE POLICY run_select ON assessment_run FOR SELECT USING(gulgo_can_access_dossier(dossier_id));
ALTER TABLE assessment_result ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_result FORCE ROW LEVEL SECURITY;
CREATE POLICY result_select ON assessment_result FOR SELECT USING (
 EXISTS(SELECT 1 FROM assessment_run r WHERE r.id=run_id AND gulgo_can_access_dossier(r.dossier_id))
);
ALTER TABLE evidence_assessment ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_assessment FORCE ROW LEVEL SECURITY;
CREATE POLICY evidence_assessment_select ON evidence_assessment FOR SELECT USING (
 EXISTS(SELECT 1 FROM variable_observation o WHERE o.id=observation_id AND gulgo_can_access_dossier(o.dossier_id))
);
-- No RLS INSERT/UPDATE/DELETE policies: default deny to application role.
-- Mutations must go through separately designed privileged service functions with authorization and audit.
-- Identity/representation/sharing tables intentionally have no app-facing policies yet.
-- Do NOT grant app role access to these tables before their policies are completed.
COMMIT;
