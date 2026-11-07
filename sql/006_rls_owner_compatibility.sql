-- V0.9: Compatibility fix for trusted-owner SECURITY DEFINER writes.
-- IMPORTANT: The owner BYPASSES RLS after this migration. Only gulgo_api
-- (a distinct, non-owner, NOBYPASSRLS role) may serve application requests.
-- The database owner must NEVER be used as the API connection account.
-- This is NOT a substitute for an independent security audit.
BEGIN;
ALTER TABLE public.economic_subject NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pass_dossier NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.variable_observation NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.evidence NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_link NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.commercial_relationship NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.commitment NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.incident NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.organization_practice NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.economic_vulnerability NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.commitment_event NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.control_finding NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.applicability_decision NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.assessment_run NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.assessment_result NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_assessment NO FORCE ROW LEVEL SECURITY;
ALTER TABLE public.subject_representation NO FORCE ROW LEVEL SECURITY;
COMMIT;
