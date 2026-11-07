#!/usr/bin/env sh
# V1.2 security acceptance: run ONLY against disposable gulgo_test database.
# Tests MUST succeed after the fix. They are expected to fail on V1.1.
set -eu
: "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD for disposable database}"
# Provision synthetic key in disposable DB before the signed actor tests.
docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
  psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test \
  -c "INSERT INTO public.gulgo_identity_secret(id,secret) VALUES(TRUE,decode(repeat('ab',32),'hex')) ON CONFLICT (id) DO NOTHING;"
for test in integration/019_identity_spoofing_must_fail_v12.sql integration/020_identity_spoofed_write_must_fail_v12.sql integration/021_signed_actor_positive_and_spoof_negative_v12.sql; do
  printf '\nRunning %s\n' "$test"
  docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres \
    psql -X -v ON_ERROR_STOP=1 -U gulgo_owner -d gulgo_test < "$test"
done
printf '\nV1.2 identity security acceptance tests passed.\n'
