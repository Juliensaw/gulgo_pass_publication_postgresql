from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def test_migration_order():
    compose = (ROOT / "docker-compose.yml").read_text()
    assert compose.index("001_init.sql") < compose.index("002_integrity_security.sql") < compose.index("003_access_roles.sql")

def test_assertions_rollback():
    sql = (ROOT / "integration/004_security_assertions.sql").read_text()
    assert "ROLLBACK;" in sql and "SET LOCAL ROLE gulgo_api" in sql

def test_two_identities_and_no_actor():
    sql = (ROOT / "integration/004_security_assertions.sql").read_text()
    assert "security-test-a" in sql and "security-test-b" in sql
    assert "No-actor access leak" in sql

def test_no_direct_writes_asserted():
    sql = (ROOT / "integration/004_security_assertions.sql").read_text()
    assert "INSERT privilege leaked" in sql and "UPDATE privilege leaked" in sql
