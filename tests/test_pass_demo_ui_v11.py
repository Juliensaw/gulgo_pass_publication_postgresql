"""Checks for the non-production same-origin PASS demonstrator."""
from fastapi.testclient import TestClient
from src.api.main import app

client = TestClient(app)


def test_demo_served_without_private_data_or_embedded_credentials():
    response = client.get("/demo/pass")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "GULGO PASS" in response.text
    assert "D1 · Identité et existence" in response.text
    assert "D6 · Formalisation et gouvernance" in response.text
    assert "Formulaire métier à connecter" in response.text
    assert "/api/v1/pass/dossiers" in response.text
    assert "localStorage" not in response.text
    assert "sessionStorage" not in response.text
    assert "GULGO_JWT_SECRET" not in response.text


def test_demo_response_disables_caching_and_iframe_embedding():
    response = client.get("/demo/pass")
    assert response.headers["cache-control"] == "no-store"
    csp = response.headers["content-security-policy"]
    assert "default-src 'none'" in csp
    assert "connect-src 'self'" in csp
    assert "frame-ancestors 'none'" in csp
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["referrer-policy"] == "no-referrer"


def test_demo_editor_is_catalogue_driven_and_draft_only():
    page = client.get("/demo/pass").text
    assert 'id="editor"' in page
    assert 'function buildEditor(catalogue,id)' in page
    assert 'catalogue.catalogue_status!=="configured"' in page
    assert 'selectedStatus!=="draft"' in page
    assert '["text","number","boolean","date"]' in page
    assert 'data_status:status.value' in page
    assert 'variable_code:variable.code' in page
    assert '"/observations",{method:"POST"' in page
    assert "aucun score" in page.lower()
    assert "innerHTML" not in page
    assert "eval(" not in page
    assert "localStorage" not in page
