#!/usr/bin/env sh
set -eu
: "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD}"
# Dedicated disposable database only.
docker compose up -d --wait postgres
docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
  psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test \
  -c "SELECT 'public.gulgo_append_observation'::regproc, 'public.gulgo_create_dossier'::regproc, 'public.variable_observation'::regclass;"
for script in integration/004_security_assertions.sql integration/005_write_assertions.sql integration/006_hardening_assertions.sql integration/007_rls_owner_assertions.sql integration/008_runtime_role_assertions.sql; do
  docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
    psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test < "$script"
done
printf '\nPostgreSQL integration assertions completed.\n'
