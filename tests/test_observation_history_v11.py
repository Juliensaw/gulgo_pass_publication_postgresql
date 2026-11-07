"""Read-only observation history contract tests: mocked DB, not a DB/RLS proof."""
from datetime import date, datetime, timedelta, timezone
from uuid import uuid4

import jwt
import pytest
from fastapi.testclient import TestClient
from src.api import main

client = TestClient(main.app)
SECRET = "observation-list-contract-secret-" + "z" * 40


@pytest.fixture(autouse=True)
def configured_secret(monkeypatch):
    monkeypatch.setenv("GULGO_JWT_SECRET", SECRET)


def auth(actor):
    now = datetime.now(timezone.utc)
    payload = {"sub": str(actor), "iat": now,
               "exp": now + timedelta(minutes=5),
               "iss": "gulgo-auth", "aud": "gulgo-api"}
    return {"Authorization": "Bearer " + jwt.encode(payload, SECRET, algorithm="HS256")}


def test_observation_history_requires_auth(monkeypatch):
    monkeypatch.setattr(main, "query_as_actor", lambda *a, **k: pytest.fail("DB called"))
    assert client.get(f"/api/v1/pass/dossiers/{uuid4()}/observations").status_code == 401


def test_observation_history_preserves_values_and_supersession(monkeypatch):
    actor, dossier, old_id, new_id = uuid4(), uuid4(), uuid4(), uuid4()
    seen = []

    def fake_query(who, sql, args=()):
        seen.append((who, sql, args))
        return [
            (str(new_id), "staff_count", "available", 4,
             date(2026, 1, 1), date(2026, 1, 31), "self_reported",
             datetime(2026, 2, 1, tzinfo=timezone.utc), str(old_id)),
            (str(old_id), "staff_count", "missing", None,
             None, None, None, datetime(2026, 1, 10, tzinfo=timezone.utc), None),
        ]

    monkeypatch.setattr(main, "query_as_actor", fake_query)
    response = client.get(f"/api/v1/pass/dossiers/{dossier}/observations", headers=auth(actor))
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["dossier_id"] == str(dossier)
    assert body["scoring_enabled"] is False
    assert body["observations"][0]["value"] == 4
    assert body["observations"][0]["supersedes_id"] == str(old_id)
    assert body["observations"][0]["period_start"] == "2026-01-01"
    assert body["observations"][1]["data_status"] == "missing"
    assert body["observations"][1]["value"] is None
    assert len(seen) == 1
    assert seen[0][0] == actor and seen[0][2] == (dossier,)
    assert "WHERE o.dossier_id = %s" in seen[0][1]


def test_empty_accessible_dossier_returns_empty_list(monkeypatch):
    actor, dossier = uuid4(), uuid4()
    calls = []

    def fake_query(who, sql, args=()):
        calls.append((who, sql, args))
        return [(1,)] if "SELECT 1 FROM pass_dossier" in sql else []

    monkeypatch.setattr(main, "query_as_actor", fake_query)
    response = client.get(f"/api/v1/pass/dossiers/{dossier}/observations", headers=auth(actor))
    assert response.status_code == 200
    assert response.json()["observations"] == []
    assert len(calls) == 2
    assert all(c[0] == actor and c[2] == (dossier,) for c in calls)


def test_inaccessible_dossier_is_not_disclosed(monkeypatch):
    actor, dossier = uuid4(), uuid4()
    monkeypatch.setattr(main, "query_as_actor", lambda *a, **k: [])
    response = client.get(f"/api/v1/pass/dossiers/{dossier}/observations", headers=auth(actor))
    assert response.status_code == 404
    assert response.json() == {"detail": "Dossier not found"}


def test_observation_list_query_param_cannot_change_actor(monkeypatch):
    actor, attacker, dossier = uuid4(), uuid4(), uuid4()
    seen = []

    def fake_query(who, sql, args=()):
        seen.append((who, sql, args))
        return [(1,)] if "SELECT 1 FROM pass_dossier" in sql else []

    monkeypatch.setattr(main, "query_as_actor", fake_query)
    response = client.get(
        f"/api/v1/pass/dossiers/{dossier}/observations?user_id={attacker}",
        headers={**auth(actor), "X-User-ID": str(attacker)},
    )
    assert response.status_code == 200
    assert all(who == actor for who, _, _ in seen)
