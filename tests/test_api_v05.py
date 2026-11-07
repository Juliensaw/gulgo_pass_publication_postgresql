import os
from datetime import datetime, timedelta, timezone
from uuid import uuid4
import jwt
from fastapi.testclient import TestClient
from src.api import main

client = TestClient(main.app)
USER = uuid4()

def token(secret="s"*48, **override):
    now=datetime.now(timezone.utc)
    claims={"sub":str(USER),"iat":now,"exp":now+timedelta(minutes=5),
            "iss":"gulgo-auth","aud":"gulgo-api"}
    claims.update(override)
    return jwt.encode(claims,secret,algorithm="HS256")

def setup_module(module):
    os.environ["GULGO_JWT_SECRET"]="s"*48

def test_health():
    assert client.get('/health').json()['database_checked'] is False

def test_no_token():
    assert client.get('/api/v1/subjects').status_code==401

def test_invalid_token():
    assert client.get('/api/v1/subjects',headers={'Authorization':'Bearer bad'}).status_code==401

def test_expired_token():
    t=token(exp=datetime.now(timezone.utc)-timedelta(minutes=1))
    assert client.get('/api/v1/subjects',headers={'Authorization':'Bearer '+t}).status_code==401

def test_wrong_audience():
    assert client.get('/api/v1/subjects',headers={'Authorization':'Bearer '+token(aud='other')}).status_code==401

def test_valid_actor_is_from_signed_token(monkeypatch):
    seen=[]
    def fake_query(actor,sql,args=()):
        seen.append(actor)
        return [(str(uuid4()),'individual','Sujet test')]
    monkeypatch.setattr(main,'query_as_actor',fake_query)
    r=client.get('/api/v1/subjects',headers={'Authorization':'Bearer '+token()})
    assert r.status_code==200 and seen==[USER]

def test_dossier_not_found(monkeypatch):
    monkeypatch.setattr(main,'query_as_actor',lambda *args,**kwargs:[])
    r=client.get(f'/api/v1/pass/dossiers/{uuid4()}',headers={'Authorization':'Bearer '+token()})
    assert r.status_code==404

def test_malformed_dossier_id():
    r=client.get('/api/v1/pass/dossiers/not-a-uuid',headers={'Authorization':'Bearer '+token()})
    assert r.status_code==422

def test_no_database_config(monkeypatch):
    monkeypatch.delenv('GULGO_DATABASE_URL',raising=False)
    from fastapi import HTTPException
    try:main.query_as_actor(USER,'SELECT 1')
    except HTTPException as e:assert e.status_code==503
    else:assert False
