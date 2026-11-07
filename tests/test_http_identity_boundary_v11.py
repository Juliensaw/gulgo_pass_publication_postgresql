"""HTTP boundary checks. These tests do NOT establish SQL-level isolation.

They verify that actor identity is sourced from signed JWT claims and that
untrusted HTTP parameters cannot become an SQL identity selector.
"""
import os
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt
import pytest
from fastapi.testclient import TestClient
from src.api import main

client = TestClient(main.app)
SECRET = "integration-http-test-secret-" + "x" * 40


@pytest.fixture(autouse=True)
def jwt_secret(monkeypatch):
    monkeypatch.setenv("GULGO_JWT_SECRET", SECRET)


def bearer(subject):
    now = datetime.now(timezone.utc)
    claims = {
        "sub": str(subject), "iat": now,
        "exp": now + timedelta(minutes=5),
        "iss": "gulgo-auth", "aud": "gulgo-api",
    }
    return {"Authorization": "Bearer " + jwt.encode(claims, SECRET, algorithm="HS256")}


def test_all_protected_routes_reject_missing_token(monkeypatch):
    monkeypatch.setattr(main, "query_as_actor", lambda *a, **k: pytest.fail("DB called without token"))
    dossier = uuid4()
    requests = [
        ("get", "/api/v1/subjects", None),
        ("get", "/api/v1/pass/dossiers", None),
        ("get", f"/api/v1/pass/dossiers/{dossier}", None),
        ("post", "/api/v1/pass/dossiers", {"subject_id": str(uuid4())}),
        ("post", f"/api/v1/pass/dossiers/{dossier}/observations",
         {"variable_code": "identity_verified", "data_status": "observed", "value": True}),
    ]
    for method, path, payload in requests:
        resp = getattr(client, method)(path, json=payload) if payload else getattr(client, method)(path)
        assert resp.status_code == 401, (method, path, resp.status_code)


def test_http_actor_spoofing_cannot_override_signed_identity(monkeypatch):
    user_a, user_b = uuid4(), uuid4()
    target_dossier, target_subject = uuid4(), uuid4()
    seen = []

    def fake_query(actor, sql, args=()):
        seen.append((actor, sql, args))
        if "gulgo_create_dossier" in sql or "gulgo_append_observation" in sql:
            return [(str(uuid4()),)]
        if "FROM economic_subject" in sql:
            return [(str(target_subject), "individual", "Test")]
        if "FROM pass_dossier" in sql:
            return [(str(target_dossier), str(target_subject), "draft", 1)]
        raise AssertionError("unexpected SQL")

    monkeypatch.setattr(main, "query_as_actor", fake_query)
    headers = {**bearer(user_a), "X-User-ID": str(user_b)}
    queries = f"?user_id={user_b}&actor_id={user_b}"
    routes = [
        client.get("/api/v1/subjects" + queries, headers=headers),
        client.get("/api/v1/pass/dossiers" + queries, headers=headers),
        client.get(f"/api/v1/pass/dossiers/{target_dossier}" + queries, headers=headers),
        client.post("/api/v1/pass/dossiers" + queries,
                    json={"subject_id": str(target_subject), "methodology_id": "PILOT"},
                    headers=headers),
        client.post(f"/api/v1/pass/dossiers/{target_dossier}/observations" + queries,
                    json={"variable_code": "test", "value": True,
                          "data_status": "observed", "source_type": "self_reported"},
                    headers=headers),
    ]
    assert all(r.status_code in (200, 201) for r in routes), [(r.status_code, r.text) for r in routes]
    assert len(seen) == len(routes)
    assert all(actor == user_a for actor, _, _ in seen)
    assert all(str(user_b) not in sql for _, sql, _ in seen)


def test_observation_value_is_parameterized_not_executable_sql(monkeypatch):
    user_id, dossier_id = uuid4(), uuid4()
    malicious = "'); SELECT set_config('app.current_user_id','arbitrary',true); --"
    seen = []

    def fake_query(actor, sql, args=()):
        seen.append((actor, sql, args))
        return [(str(uuid4()),)]

    monkeypatch.setattr(main, "query_as_actor", fake_query)
    response = client.post(
        f"/api/v1/pass/dossiers/{dossier_id}/observations",
        headers=bearer(user_id),
        json={"variable_code": malicious, "value": {"text": malicious},
              "data_status": "observed", "source_type": malicious},
    )
    assert response.status_code == 201
    assert len(seen) == 1
    actor, sql, args = seen[0]
    assert actor == user_id
    assert malicious not in sql
    assert malicious in args[1]
    assert malicious in args[2]
    assert malicious in args[6]


def test_forged_bearer_token_rejected_even_with_spoofed_header(monkeypatch):
    victim = uuid4()
    monkeypatch.setattr(main, "query_as_actor", lambda *a, **k: pytest.fail("DB called with forged JWT"))
    forged = jwt.encode({
        "sub": str(victim),
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(minutes=5),
        "iss": "gulgo-auth", "aud": "gulgo-api",
    }, "wrong-signing-secret" * 3, algorithm="HS256")
    r = client.get("/api/v1/pass/dossiers",
                   headers={"Authorization": "Bearer " + forged, "X-User-ID": str(victim)})
    assert r.status_code == 401
