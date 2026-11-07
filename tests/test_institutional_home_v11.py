"""Institutional landing page: audience, honest CTA, security boundaries."""
from fastapi.testclient import TestClient
from src.api.main import app

client = TestClient(app)


def test_homepage_prioritizes_entrepreneurs_and_pre_evaluation():
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    page = response.text
    for text in (
        "GULGO", "La confiance devient un actif.",
        "Travailleurs indépendants", "TPE et PME",
        "Découvrir la pré-évaluation", "Pré-évaluation en préparation",
        "PASS", "TRUST", "STRATEGY", "DIASPORA", "MARKET",
    ):
        assert text in page
    assert 'href="#preevaluation"' in page


def test_homepage_does_not_falsely_offer_scoring_or_collect_data():
    page = client.get("/").text
    assert "Aucun score ou avis d'admissibilité" in page
    assert "Aucun questionnaire décisionnel" in page
    assert "<form" not in page
    assert "<script" not in page
    assert "api/v1/" not in page
    assert 'type="password"' not in page


def test_homepage_restrictive_response_headers():
    response = client.get("/")
    assert response.headers["cache-control"] == "no-store"
    assert "default-src 'none'" in response.headers["content-security-policy"]
    assert "form-action 'none'" in response.headers["content-security-policy"]
    assert "frame-ancestors 'none'" in response.headers["content-security-policy"]
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["referrer-policy"] == "no-referrer"
