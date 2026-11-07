"""Catalogue endpoint contract tests; DB isolation also needs SQL integration."""
from datetime import datetime, timedelta, timezone
from uuid import uuid4
import jwt
from fastapi.testclient import TestClient
from src.api import main

client = TestClient(main.app)
SECRET = "test-catalog-signing-secret-" + "c" * 40


def headers(actor):
    now = datetime.now(timezone.utc)
    claims = {"sub":str(actor),"iat":now,"exp":now+timedelta(minutes=5),
              "aud":"gulgo-api","iss":"gulgo-auth"}
    return {"Authorization":"Bearer "+jwt.encode(claims,SECRET,algorithm="HS256")}


def test_catalogue_requires_valid_identity(monkeypatch):
    monkeypatch.setenv("GULGO_JWT_SECRET",SECRET)
    monkeypatch.setattr(main,"query_as_actor",lambda *a,**kw: (_ for _ in ()).throw(AssertionError("DB called")))
    assert client.get(f"/api/v1/pass/dossiers/{uuid4()}/catalog").status_code == 401


def test_catalogue_hidden_when_dossier_not_visible(monkeypatch):
    monkeypatch.setenv("GULGO_JWT_SECRET",SECRET)
    actor, dossier = uuid4(), uuid4()
    calls=[]
    def fake(actor_id,sql,args=()):
        calls.append((actor_id,sql,args))
        return []
    monkeypatch.setattr(main,"query_as_actor",fake)
    result=client.get(f"/api/v1/pass/dossiers/{dossier}/catalog",headers=headers(actor))
    assert result.status_code==404
    assert len(calls)==1 and calls[0][0]==actor and calls[0][2]==(dossier,)


def test_unconfigured_catalogue_is_explicit_and_has_six_dimensions(monkeypatch):
    monkeypatch.setenv("GULGO_JWT_SECRET",SECRET)
    actor,dossier=uuid4(),uuid4()
    calls=[]
    def fake(who,sql,args=()):
        calls.append((who,sql,args))
        return [("GULGO_PASS_V1_PILOT",)] if "SELECT methodology_id FROM pass_dossier" in sql else []
    monkeypatch.setattr(main,"query_as_actor",fake)
    response=client.get(f"/api/v1/pass/dossiers/{dossier}/catalog",headers={**headers(actor),"X-User-ID":str(uuid4())})
    assert response.status_code==200
    body=response.json()
    assert body["catalogue_status"]=="not_configured"
    assert body["scoring_enabled"] is False
    assert [d["code"] for d in body["dimensions"]]==["D1","D2","D3","D4","D5","D6"]
    assert all(d["indicators"]==[] for d in body["dimensions"])
    assert len(calls)==2
    assert all(who==actor for who,_,_ in calls)
    assert calls[1][2]==("GULGO_PASS_V1_PILOT",)


def test_catalogue_groups_registered_variables_without_inventing_definitions(monkeypatch):
    monkeypatch.setenv("GULGO_JWT_SECRET",SECRET)
    def fake(who,sql,args=()):
        if "SELECT methodology_id FROM pass_dossier" in sql:
            return [("GULGO_PASS_V1_PILOT",)]
        return [
            ("D1","IND_A","Existence", "identity_evidence","Pièce d'existence","text",True),
            ("D1","IND_A","Existence", "activity_started","Date début","date",False),
            ("D2","IND_B","Traçabilité", None,None,None,None),
        ]
    monkeypatch.setattr(main,"query_as_actor",fake)
    response=client.get(f"/api/v1/pass/dossiers/{uuid4()}/catalog",headers=headers(uuid4()))
    assert response.status_code==200
    body=response.json()
    assert body["catalogue_status"]=="configured"
    d1=body["dimensions"][0]["indicators"]
    assert len(d1)==1 and len(d1[0]["variables"])==2
    assert d1[0]["variables"][0]["critical"] is True
    assert body["dimensions"][1]["indicators"][0]["variables"]==[]
    assert body["dimensions"][2]["indicators"]==[]
