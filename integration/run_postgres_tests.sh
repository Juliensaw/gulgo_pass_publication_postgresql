#!/usr/bin/env sh
set -eu
: "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD}"
# Dedicated disposable database only.
docker compose up -d --wait postgres
docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
  psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test \
  -c "SELECT 'public.gulgo_append_observation'::regproc, 'public.gulgo_create_dossier'::regproc, 'public.variable_observation'::regclass;"
for script in integration/004_security_assertions.sql integration/005_write_assertions.sql integration/006_hardening_assertions.sql integration/007_rls_owner_assertions.sql integration/008_runtime_role_assertions.sql integration/009_runtime_login_assertions.sql integration/011_guc_spoofing_demonstration.sql integration/012_definer_hardening_assertions.sql; do
  docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
    psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test < "$script"
done
# Disposable CI database only: provision a temporary password for the real login test.
# Never reuse this credential outside the isolated test container.
docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
  psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test \
  -c "ALTER ROLE gulgo_runtime PASSWORD 'ci-only-runtime-disposable';"
docker compose exec -T -e PGPASSWORD="ci-only-runtime-disposable" postgres \
  psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U gulgo_runtime -d gulgo_test \
  < integration/010_real_login_assertions.sql
printf '\nPostgreSQL integration assertions completed.\n'
