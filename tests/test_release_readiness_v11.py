from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_private_material_ignored():
    ignore = (ROOT / '.gitignore').read_text()
    assert '.env' in ignore and '*.pem' in ignore and '*.key' in ignore


def test_ci_minimum_permissions():
    ci = (ROOT / '.github/workflows/postgresql-integration.yml').read_text()
    assert 'permissions:' in ci and 'contents: read' in ci
    assert 'run_postgres_tests.sh' in ci


def test_release_discloses_unvalidated_sql():
    notes = (ROOT / 'README_V11.md').read_text()
    assert 'Aucun test PostgreSQL' in notes
    assert 'NOLOGIN' in notes
    assert 'scoring_enabled=false' in notes
