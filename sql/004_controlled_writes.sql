-- V0.6 experimental controlled writes. Run after 001,002,003 as trusted owner.
-- Security definer functions MUST be owned by the trusted schema owner, never gulgo_api.
BEGIN;
CREATE OR REPLACE FUNCTION gulgo_create_dossier(p_subject UUID, p_methodology TEXT)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor UUID; v_id UUID;
BEGIN
 v_actor := gulgo_actor_id();
 IF v_actor IS NULL OR NOT EXISTS (
  SELECT 1 FROM subject_representation r WHERE r.subject_id=p_subject AND r.user_id=v_actor
    AND r.role IN ('owner','representative') AND r.valid_from<=CURRENT_DATE
    AND (r.valid_until IS NULL OR r.valid_until>=CURRENT_DATE)
 ) THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS (SELECT 1 FROM methodology_release WHERE id=p_methodology AND scoring_enabled=FALSE)
 THEN RAISE EXCEPTION 'Unsupported methodology' USING ERRCODE='22023'; END IF;
 INSERT INTO pass_dossier(subject_id,methodology_id) VALUES(p_subject,p_methodology) RETURNING id INTO v_id;
 INSERT INTO audit_event(actor_id,object_type,object_id,action,detail)
 VALUES(v_actor,'pass_dossier',v_id,'created',jsonb_build_object('subject_id',p_subject));
 RETURN v_id;
END $$;
CREATE OR REPLACE FUNCTION gulgo_append_observation(
 p_dossier UUID, p_variable TEXT, p_value JSONB, p_status TEXT,
 p_period_start DATE DEFAULT NULL, p_period_end DATE DEFAULT NULL,
 p_source TEXT DEFAULT NULL, p_supersedes UUID DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor UUID; v_method TEXT; v_id UUID; v_type TEXT; v_old UUID;
BEGIN
 v_actor := gulgo_actor_id();
 IF v_actor IS NULL THEN RAISE EXCEPTION 'Not authorized' USING ERRCODE='42501'; END IF;
 SELECT d.methodology_id INTO v_method FROM pass_dossier d
 JOIN subject_representation r ON r.subject_id=d.subject_id
 WHERE d.id=p_dossier AND d.status='draft' AND r.user_id=v_actor
 AND r.role IN ('owner','representative') AND r.valid_from<=CURRENT_DATE
 AND (r.valid_until IS NULL OR r.valid_until>=CURRENT_DATE);
 IF v_method IS NULL THEN RAISE EXCEPTION 'Not authorized or dossier not editable' USING ERRCODE='42501'; END IF;
 SELECT value_type INTO v_type FROM variable_definition WHERE methodology_id=v_method AND code=p_variable;
 IF v_type IS NULL THEN RAISE EXCEPTION 'Unknown variable' USING ERRCODE='22023'; END IF;
 IF p_status NOT IN ('available','missing','refused','temporarily_unavailable','under_verification') OR p_status IS NULL
 OR (p_status='available' AND p_value IS NULL) OR (p_status<>'available' AND p_value IS NOT NULL)
 OR (p_period_start IS NOT NULL AND p_period_end IS NOT NULL AND p_period_end<p_period_start)
 THEN RAISE EXCEPTION 'Invalid observation' USING ERRCODE='22023'; END IF;
 IF p_status='available' AND NOT (
  (v_type='number' AND jsonb_typeof(p_value)='number') OR
  (v_type='text' AND jsonb_typeof(p_value)='string') OR
  (v_type='enum' AND jsonb_typeof(p_value)='string') OR
  (v_type='boolean' AND jsonb_typeof(p_value)='boolean') OR
  (v_type='date' AND jsonb_typeof(p_value)='string' AND (p_value#>>'{}') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') OR
  (v_type='json' AND jsonb_typeof(p_value) IN ('object','array'))
 ) THEN RAISE EXCEPTION 'Value type mismatch' USING ERRCODE='22023'; END IF;
 IF p_supersedes IS NOT NULL THEN
  SELECT id INTO v_old FROM variable_observation WHERE id=p_supersedes
    AND dossier_id=p_dossier AND variable_code=p_variable;
  IF v_old IS NULL THEN RAISE EXCEPTION 'Invalid superseded observation' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM variable_observation WHERE supersedes_id=p_supersedes)
  THEN RAISE EXCEPTION 'Observation already superseded' USING ERRCODE='23505'; END IF;
 END IF;
 INSERT INTO variable_observation(dossier_id,methodology_id,variable_code,value_json,data_status,
 period_start,period_end,source_type,recorded_by,supersedes_id)
 VALUES(p_dossier,v_method,p_variable,p_value,p_status,p_period_start,p_period_end,p_source,v_actor,p_supersedes)
 RETURNING id INTO v_id;
 INSERT INTO audit_event(actor_id,object_type,object_id,action,detail)
 VALUES(v_actor,'variable_observation',v_id,'appended',jsonb_build_object('dossier_id',p_dossier,'variable_code',p_variable,'supersedes_id',p_supersedes));
 RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION gulgo_create_dossier(UUID,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION gulgo_append_observation(UUID,TEXT,JSONB,TEXT,DATE,DATE,TEXT,UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gulgo_create_dossier(UUID,TEXT) TO gulgo_api;
GRANT EXECUTE ON FUNCTION gulgo_append_observation(UUID,TEXT,JSONB,TEXT,DATE,DATE,TEXT,UUID) TO gulgo_api;
COMMIT;
