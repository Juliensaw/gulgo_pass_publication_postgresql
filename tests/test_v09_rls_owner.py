from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def test_owner_rls_migration_exists_and_retains_rls():
 s=(ROOT/'sql/006_rls_owner_compatibility.sql').read_text()
 assert s.count('NO FORCE ROW LEVEL SECURITY')>=17
 assert 'DISABLE ROW LEVEL SECURITY' not in s

def test_docker_and_runner_include_v09():
 assert '006_rls_owner_compatibility.sql' in (ROOT/'docker-compose.yml').read_text()
 assert '007_rls_owner_assertions.sql' in (ROOT/'integration/run_postgres_tests.sh').read_text()

def test_assertions_enforce_role_separation():
 s=(ROOT/'integration/007_rls_owner_assertions.sql').read_text()
 assert 'rolbypassrls' in s and 'rolcanlogin' in s and 'rolsuper' in s
 assert 'relrowsecurity' in s and 'relowner' in s
