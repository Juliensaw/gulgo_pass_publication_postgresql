# GULGO PASS Backend V0.6 — controlled writes prototype

Adds `sql/004_controlled_writes.sql` and two authenticated POST endpoints. Run migrations 001, 002, 003, then 004 on a **disposable database** using a trusted schema owner. Configure a separate login inheriting `gulgo_api` permissions; never use the owner for API traffic. Ensure `gulgo_api` has no BYPASSRLS or arbitrary SQL exposure.

## Endpoints
- `POST /api/v1/pass/dossiers` `{ "subject_id": "UUID", "methodology_id": "GULGO_PASS_V1_PILOT" }`
- `POST /api/v1/pass/dossiers/{id}/observations` `{ "variable_code": "ECO-002", "value": 12, "data_status": "available" }`

Both invoke audited SQL `SECURITY DEFINER` functions; these check the signed actor against an active subject representation, draft-only observations, methodology, variable type, and same-dossier supersession. SQL inserts and audit events share a transaction. No client may set evidence N4 or scoring. Existing users/subjects/representations must be provisioned by a separate trusted administrative workflow; self-registration is deliberately **not** implemented.

## Known gaps and security warnings
- No PostgreSQL binary/Docker in build environment: SQL migrations and RLS isolation have **not** been executed against PostgreSQL. Do not deploy with real business data.
- The `app.current_user_id` session GUC is spoofable by a caller with arbitrary SQL execution. API SQL must remain fixed and parameterized; database role must not be exposed externally.
- `SECURITY DEFINER` owner must be reviewed; privilege and RLS behavior require live database tests.
- JWT HS256 is prototype only; identity provisioning and external_auth_id mapping are not production ready.
- Input validation is incomplete: enum catalogs, monetary constraints, date parsing, optimistic concurrency, idempotency, rate limiting, audit integrity, full business lifecycle, proof uploads and error mapping remain to implement.
- SQL exceptions currently surface to API clients as generic 503, including permission errors. Map safely to 403/422/409 after integration tests.
- `sourceObservationIds` and the Score Pass remain disabled.

## Tests
`python -m pytest -q tests`
