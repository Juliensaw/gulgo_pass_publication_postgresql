from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def test_ci_invokes_postgres_integration():
    ci=(ROOT/'.github/workflows/postgresql-integration.yml').read_text()
    assert 'run_postgres_tests.sh' in ci
    assert 'pytest -q tests' in ci
    assert 'docker compose down -v' in ci
def test_runner_checks_migration_objects_before_assertions():
    runner=(ROOT/'integration/run_postgres_tests.sh').read_text()
    assert "'public.gulgo_append_observation'::regproc" in runner
    assert 'ON_ERROR_STOP=1' in runner
