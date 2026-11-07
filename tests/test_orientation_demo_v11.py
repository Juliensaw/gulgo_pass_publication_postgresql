"""Orientation demo contract: no server submission, no eligibility verdict."""
from fastapi.testclient import TestClient
from src.api.main import app

client = TestClient(app)


def test_orientation_page_is_available_from_home():
    home = client.get("/")
    assert 'href="/demo/pre-evaluation"' in home.text
    page = client.get("/demo/pre-evaluation")
    assert page.status_code == 200
    assert "text/html" in page.headers["content-type"]
    for label in (
        "Votre activité existe-t-elle déjà",
        "Pouvez-vous décrire les biens ou services",
        "Disposez-vous d'informations",
        "prêt à faire vérifier les informations",
        "Compatible", "Partiellement compatible", "Non compatible",
    ):
        assert label in page.text


def test_orientation_does_not_store_or_submit_information():
    page = client.get("/demo/pre-evaluation").text
    assert 'id="orientation"' in page
    assert 'event.preventDefault()' in page
    assert "fetch(" not in page
    assert "XMLHttpRequest" not in page
    assert "localStorage" not in page
    assert "sessionStorage" not in page
    assert "navigator.sendBeacon" not in page
    assert "<input type=\"text\"" not in page
    assert "aucune décision d'admissibilité" not in page.lower() or "pas une décision d'admissibilité" in page
    assert "Aucune catégorie de compatibilité n'a été attribuée." in page


def test_orientation_response_security():
    response = client.get("/demo/pre-evaluation")
    assert response.headers["cache-control"] == "no-store"
    csp = response.headers["content-security-policy"]
    assert "default-src 'none'" in csp
    assert "form-action 'none'" in csp
    assert "frame-ancestors 'none'" in csp
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["referrer-policy"] == "no-referrer"
