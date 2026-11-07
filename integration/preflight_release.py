"""Checks the completeness of a source release without a PostgreSQL server."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
required = [
    ROOT / '.github/workflows/postgresql-integration.yml',
    ROOT / 'docker-compose.yml',
    ROOT / 'integration/run_postgres_tests.sh',
    ROOT / 'RELEASE_POSTGRESQL.md',
    *[ROOT / f'sql/{i:03d}_{name}.sql' for i, name in [
        (1, 'init'), (2, 'integrity_security'), (3, 'access_roles'),
        (4, 'controlled_writes'), (5, 'integrity_hardening'),
        (6, 'rls_owner_compatibility')]],
]
missing = [str(p.relative_to(ROOT)) for p in required if not p.is_file()]
workflow = (ROOT / '.github/workflows/postgresql-integration.yml').read_text()
compose = (ROOT / 'docker-compose.yml').read_text()
for i in range(1, 7):
    filename = required[i + 3].name
    if filename not in compose:
        missing.append('docker-compose.yml: ' + filename)
if 'run_postgres_tests.sh' not in workflow:
    missing.append('workflow: integration runner')
if missing:
    print('PRE-FLIGHT FAILED:', *missing, sep='\n - ')
    sys.exit(1)
print('PRE-FLIGHT OK: required release files and migration mounts present')
