from uuid import uuid4
from fastapi.testclient import TestClient
from src.api import main
import os, jwt
from datetime import datetime, timedelta, timezone
from uuid import UUID
os.environ["GULGO_JWT_SECRET"]="s"*48
def token():
    now=datetime.now(timezone.utc)
    return jwt.encode({"sub":str(uuid4()),"iat":now,"exp":now+timedelta(minutes=5),"iss":"gulgo-auth","aud":"gulgo-api"},"s"*48,algorithm="HS256")

client = TestClient(main.app)

def test_write_requires_token():
    assert client.post('/api/v1/pass/dossiers', json={'subject_id':str(uuid4())}).status_code==401

def test_create_dossier_actor_is_verified(monkeypatch):
    actor=uuid4(); seen=[]
    def fake_query(a,sql,args=()):
        seen.append((a,sql,args));return [(str(uuid4()),)]
    monkeypatch.setattr(main,'query_as_actor',fake_query)
    r=client.post('/api/v1/pass/dossiers',json={'subject_id':str(actor)},headers={'Authorization':'Bearer '+token()})
    assert r.status_code==201 and 'gulgo_create_dossier' in seen[0][1]
    assert seen[0][2][0]==actor

def test_observation_requires_token():
    assert client.post(f'/api/v1/pass/dossiers/{uuid4()}/observations',json={'variable_code':'ECO-002','data_status':'missing'}).status_code==401

def test_observation_parameterized(monkeypatch):
    seen=[]
    def fake_query(a,sql,args=()):
        seen.append((sql,args));return [(str(uuid4()),)]
    monkeypatch.setattr(main,'query_as_actor',fake_query)
    dossier=uuid4()
    r=client.post(f'/api/v1/pass/dossiers/{dossier}/observations',json={'variable_code':'ECO-002','data_status':'available','value':12},headers={'Authorization':'Bearer '+token()})
    assert r.status_code==201
    assert '%s' in seen[0][0] and '12' in seen[0][1][2]

def test_bad_uuid_rejected():
    assert client.post('/api/v1/pass/dossiers',json={'subject_id':'bad'},headers={'Authorization':'Bearer '+token()}).status_code==422
