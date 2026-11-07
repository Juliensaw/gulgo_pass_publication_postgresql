from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def test_compose_initializes_controlled_writes():
    s = (ROOT/'docker-compose.yml').read_text()
    assert '004_controlled_writes.sql:/docker-entrypoint-initdb.d/004_controlled_writes.sql' in s

def test_runner_runs_both_integration_suites():
    s = (ROOT/'integration/run_postgres_tests.sh').read_text()
    assert '004_security_assertions.sql' in s
    assert '005_write_assertions.sql' in s
    assert 'ON_ERROR_STOP=1' in s

def test_write_suite_covers_isolation_and_audit():
    s = (ROOT/'integration/005_write_assertions.sql').read_text()
    for x in ['gulgo_create_dossier','gulgo_append_observation','Cross-tenant write','Cross-tenant observation','Missing dossier audit','ROLLBACK;']:
        assert x in s
