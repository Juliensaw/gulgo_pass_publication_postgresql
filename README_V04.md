# GULGO PASS — V0.4 security integration harness

## Goal
Run existing 001–003 SQL migrations on a disposable PostgreSQL 16 instance and execute isolation assertions for two users. **No production use.**

## Requirements
Docker with Docker Compose, Python 3.11+, pytest. PostgreSQL binaries and Docker are **not available in the authoring environment**, so live SQL execution has NOT been claimed.

## Run
1. `cp .env.example .env` and set a local test password.
2. `docker compose up -d --wait postgres`.
3. `docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test < integration/004_security_assertions.sql`.
4. `python -m pytest -q`.
5. `docker compose down`.

**Important:** SQL migrations in `/docker-entrypoint-initdb.d/` run only when the database initializes. The service uses a tmpfs for test-only storage, so a fresh container is required after changing migrations. Never point this setup at a production database.

## Blocking security design issue
`app.current_user_id` is a PostgreSQL custom setting, not an authentication mechanism. Any direct SQL client able to execute `set_config` can impersonate another user. **Do not expose the `gulgo_api` connection to browsers, partners, or untrusted clients.** A server-side verified identity and trusted transaction boundary are mandatory before an API is deployed. Current RLS tests prove only database isolation under an *assumed trustworthy actor context*.

## Additional limits
- The role `gulgo_api` has no direct write grants; safe write functions are not yet implemented.
- The existing migrations have not been run against live PostgreSQL here.
- The security test suite is a starter set, not a full penetration test.
- Scoring remains disabled.
- PostgreSQL initialization SQL is applied in filename order; review every migration and any errors in container logs.

## Next milestone
Resolve trusted identity propagation and write-authorization design; add transactional write operations, audit logging and integration tests, then expose authenticated API endpoints.
