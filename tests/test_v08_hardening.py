from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def test_migration_is_mounted():
    assert '005_integrity_hardening.sql:/docker-entrypoint-initdb.d/005_integrity_hardening.sql' in (ROOT/'docker-compose.yml').read_text()
def test_correction_uniqueness():
    s=(ROOT/'sql/005_integrity_hardening.sql').read_text()
    assert 'UNIQUE INDEX' in s and 'supersedes_id' in s
    assert 'ck_no_self_supersession' in s
def test_runner_includes_hardening():
    assert '006_hardening_assertions.sql' in (ROOT/'integration/run_postgres_tests.sh').read_text()
def test_sql_assertions_check_privileges():
    s=(ROOT/'integration/006_hardening_assertions.sql').read_text()
    assert 'has_schema_privilege' in s and 'has_function_privilege' in s
    assert 'ROLLBACK;' in s
