# GULGO PASS V0.5 — Read-only authenticated API (experimental)

## Scope
Adds FastAPI endpoints: `/health`, `GET /api/v1/subjects`, `GET /api/v1/pass/dossiers`, `GET /api/v1/pass/dossiers/{uuid}`. JWT HS256 validation requires issuer `gulgo-auth`, audience `gulgo-api`, subject UUID, issued-at and expiry. Subject IDs are taken ONLY from validated token, never from request headers/body. PostgreSQL context is transaction-local (`set_config(..., true)`). SQL queries are parameterized.

**Important: V0.5 is read-only.** No write endpoints, no production authentication provider, no scoring. JWT signing is an integration-test/dev contract only; production should use an external OIDC issuer, asymmetric signature verification and key rotation. Do not expose SQL connections to clients; PostgreSQL custom GUC alone is NOT a cryptographic trust boundary.

## Running tests
From the `gulgo_pass_backend` directory: `pip install -r requirements-v05.txt`; `PYTHONPATH=. pytest -q`. API: `GULGO_JWT_SECRET=<strong-unique-32+-character-secret> GULGO_DATABASE_URL=<restricted-role-DSN> uvicorn src.api.main:app --reload` (development only).

## Critical unresolved prerequisite
Earlier SQL roles define `gulgo_api` as NOLOGIN and do not create a credentialed non-owner login. A production-ready DB connection role and grants must be provisioned and independently verified. **Do not connect the API as `gulgo_owner`**; that bypasses the intended least-privilege boundary. Earlier SQL migrations have not been executed against a real PostgreSQL instance here; run `integration/run_postgres_tests.sh` in an isolated environment and review results. Docker Compose is supplied by V0.4 but not run here.

## Next engineering gate
1. Execute all migrations in disposable PostgreSQL; 2. fix RLS recursion/policy issues if found; 3. provision dedicated restricted DB login; 4. execute two-user access and denied-access tests; 5. implement SECURITY DEFINER write functions with explicit authorization and transactional audit; 6. add API POST endpoints and tests. Never use real client data until those checks pass.
