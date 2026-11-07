from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL = (ROOT / 'sql/003_access_roles.sql').read_text()
TEST = (ROOT / 'integration/rls_isolation.sql').read_text()


def test_api_role_cannot_bypass_rls():
    assert 'NOBYPASSRLS' in SQL
    assert 'NOLOGIN' in SQL


def test_representation_is_row_filtered():
    assert 'ALTER TABLE subject_representation ENABLE ROW LEVEL SECURITY' in SQL
    assert 'user_id = gulgo_actor_id()' in SQL


def test_no_api_mutation_grants():
    assert 'GRANT INSERT' not in SQL
    assert 'GRANT UPDATE' not in SQL
    assert 'GRANT DELETE' not in SQL


def test_integration_harness_checks_both_tenants_and_missing_actor():
    assert 'A dossier isolation failed' in TEST
    assert 'B dossier isolation failed' in TEST
    assert 'Unset actor leaked dossiers' in TEST


def test_integration_harness_is_rolled_back():
    assert TEST.rstrip().endswith('ROLLBACK;')
