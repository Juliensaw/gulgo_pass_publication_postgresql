#!/usr/bin/env sh
set -eu
: "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD}"
# Dedicated disposable database only.
docker compose up -d --wait postgres
docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
  psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test \
  -c "SELECT 'public.gulgo_append_observation'::regproc, 'public.gulgo_create_dossier'::regproc, 'public.variable_observation'::regclass;"
# Synthetic signing key for disposable CI only. Not a production secret.
docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
  psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test \
  -c "INSERT INTO public.gulgo_identity_secret(id,secret) VALUES(TRUE,decode(repeat('ab',32),'hex')) ON CONFLICT (id) DO NOTHING;"
for script in integration/004_security_assertions.sql integration/005_write_assertions.sql integration/006_hardening_assertions.sql integration/007_rls_owner_assertions.sql integration/008_runtime_role_assertions.sql integration/009_runtime_login_assertions.sql integration/019_identity_spoofing_must_fail_v12.sql integration/020_identity_spoofed_write_must_fail_v12.sql integration/021_signed_actor_positive_and_spoof_negative_v12.sql integration/012_definer_hardening_assertions.sql integration/013_catalog_permissions_assertions.sql; do
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
# Committed synthetic fixtures exist only in the disposable database.
# Three separate REAL runtime login sessions must preserve tenant separation.
docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
  psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test \
  < integration/014_two_actor_fixture_setup.sql
for script in integration/015_real_actor_a.sql integration/016_real_actor_b.sql integration/017_real_actor_a_verify.sql; do
  docker compose exec -T -e PGPASSWORD="ci-only-runtime-disposable" postgres \
    psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U gulgo_runtime -d gulgo_test \
    < "$script"
done
printf '\nPostgreSQL integration assertions completed.\n'
