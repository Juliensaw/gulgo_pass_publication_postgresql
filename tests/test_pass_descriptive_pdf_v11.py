"""Descriptive PDF report: HTTP isolation and rendering contract tests."""
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt
from fastapi.testclient import TestClient
from src.api import main
from src.api.pass_report import generate_descriptive_report

client = TestClient(main.app)
SECRET = "pdf-descriptive-report-secret-" + "z" * 40


def token(actor):
    now = datetime.now(timezone.utc)
    claims = {
        "sub": str(actor), "iat": now, "exp": now + timedelta(minutes=5),
        "aud": "gulgo-api", "iss": "gulgo-auth",
    }
    return {"Authorization": "Bearer " + jwt.encode(claims, SECRET, algorithm="HS256")}


def _fixture(dossier_id, subject_id):
    details = {"id": str(dossier_id), "subject_id": str(subject_id),
               "status": "draft", "revision": 1}
    catalogue = {
        "methodology_id": "GULGO_PASS_V1_PILOT",
        "dimensions": [
            {"code": "D"+str(n), "label": name, "indicators":
             [{"code": "IND1", "label": "Donnée", "variables":
               [{"code": "trade_name", "label": "Nom commercial",
                 "value_type": "text", "critical": False}]}] if n == 1 else []}
            for n, name in enumerate(main.PASS_DIMENSIONS.values(), 1)
        ],
        "scoring_enabled": False, "catalogue_status": "configured",
    }
    obs = {
        "dossier_id": str(dossier_id), "limit": 100,
        "scoring_enabled": False, "observations": [{
            "id": str(uuid4()), "variable_code": "trade_name",
            "data_status": "available", "value": "Activité fictive & tests",
            "period_start": None, "period_end": None,
            "recorded_at": "2026-11-07T12:00:00+00:00",
            "source_type": "auto-declaration", "supersedes_id": None,
        }],
    }
    return details, catalogue, obs


def test_pdf_requires_token_without_database_access(monkeypatch):
    monkeypatch.setenv("GULGO_JWT_SECRET", SECRET)
    monkeypatch.setattr(main, "query_as_actor",
                        lambda *a, **kw: (_ for _ in ()).throw(AssertionError("DB called")))
    resp = client.get(f"/api/v1/pass/dossiers/{uuid4()}/report.pdf")
    assert resp.status_code == 401


def test_inaccessible_report_yields_404_not_pdf(monkeypatch):
    monkeypatch.setenv("GULGO_JWT_SECRET", SECRET)
    actor, dossier_id = uuid4(), uuid4()
    seen = []
    def fake_query(who, sql, args=()):
        seen.append((who, args))
        return []
    monkeypatch.setattr(main, "query_as_actor", fake_query)
    resp = client.get(f"/api/v1/pass/dossiers/{dossier_id}/report.pdf",
                      headers=token(actor))
    assert resp.status_code == 404
    assert "application/pdf" not in resp.headers["content-type"]
    assert seen == [(actor, (dossier_id,))]


def test_pdf_endpoint_uses_only_authenticated_scoped_inputs(monkeypatch):
    monkeypatch.setenv("GULGO_JWT_SECRET", SECRET)
    actor, intruder, dossier_id, subject_id = uuid4(), uuid4(), uuid4(), uuid4()
    details, catalogue, observations = _fixture(dossier_id, subject_id)
    calls = []
    def scoped_query(who, sql, args=()):
        calls.append((who, sql, args))
        if "SELECT id::text, subject_id::text, status, revision" in sql:
            return [(details["id"], details["subject_id"], "draft", 1)]
        if "SELECT methodology_id FROM pass_dossier" in sql:
            return [(catalogue["methodology_id"],)]
        if "FROM indicator_definition AS i" in sql:
            return [("D1", "IND1", "Donnée", "trade_name", "Nom commercial",
                     "text", False)]
        if "FROM variable_observation AS o" in sql:
            o = observations["observations"][0]
            return [(o["id"], o["variable_code"], o["data_status"], o["value"],
                     None, None, o["source_type"], datetime.now(timezone.utc), None)]
        raise AssertionError("Unexpected SQL: "+sql)
    monkeypatch.setattr(main, "query_as_actor", scoped_query)
    resp = client.get(f"/api/v1/pass/dossiers/{dossier_id}/report.pdf"
                      f"?user_id={intruder}", headers={
                          **token(actor), "X-User-ID": str(intruder),
                      })
    assert resp.status_code == 200, resp.text[:120]
    assert resp.content.startswith(b"%PDF-")
    assert len(resp.content) > 1500
    assert resp.headers["content-type"] == "application/pdf"
    assert resp.headers["cache-control"] == "no-store, private"
    assert "attachment" in resp.headers["content-disposition"]
    assert len(calls) == 4
    assert all(who == actor for who, _, _ in calls)
    assert all(str(intruder) not in sql for _, sql, _ in calls)


def test_empty_and_unmapped_observations_render_without_scoring():
    dossier_id, subject_id = uuid4(), uuid4()
    details, catalogue, data = _fixture(dossier_id, subject_id)
    data["observations"].append({
        "id": str(uuid4()), "variable_code": "unmapped",
        "data_status": "missing", "value": None, "period_start": None,
        "period_end": None, "source_type": None, "supersedes_id": None,
        "recorded_at": datetime.now(timezone.utc),
    })
    first = generate_descriptive_report(details, catalogue, data)
    assert first.startswith(b"%PDF-") and len(first) > 1500
    data["observations"] = []
    second = generate_descriptive_report(details, catalogue, data)
    assert second.startswith(b"%PDF-") and len(second) > 1500


def test_report_escapes_untrusted_markup_without_crashing():
    dossier_id, subject_id = uuid4(), uuid4()
    details, catalogue, data = _fixture(dossier_id, subject_id)
    data["observations"][0]["value"] = "<script>alert(1)</script> & " + "x"*10000
    result = generate_descriptive_report(details, catalogue, data)
    assert result.startswith(b"%PDF-")
