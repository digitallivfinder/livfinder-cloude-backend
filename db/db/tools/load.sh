#!/usr/bin/env bash
#
# Load Liv Finder migrations and/or seeds into MySQL or MariaDB.
#
# Files are applied in filename order. Everything is plain SQL — there is no
# generator step and no build tooling; what is in seeds/ is what loads.
#
# The load runs with FOREIGN_KEY_CHECKS on, deliberately. Bulk seeds are
# commonly loaded with checks disabled for speed; here the checks are the test —
# every file is ordered so its foreign keys already resolve, and a failure means
# the data is wrong rather than that the loader needs relaxing.
#
# Usage
#   tools/load.sh migrate                 apply migrations only
#   tools/load.sh seed                    apply seeds only
#   tools/load.sh all                     migrations then seeds
#   tools/load.sh verify                  re-run the seed assertions
#   tools/load.sh integrity               run the consistency suite
#
# Connection is read from the environment:
#   DB_HOST (localhost) DB_PORT (3306) DB_USER (root) DB_PASSWORD ('')
#   DB_NAME (livfinder)
#
# Options
#   --with-mysql8   also apply 0015_mysql8_optimizations.sql. Requires MySQL
#                   8.0.17+; it will fail on MariaDB, which is why it is opt-in.
#   --fresh         drop and recreate the database first.

set -euo pipefail

DB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Read db/.env if present. Values already in the environment win, so
# `DB_NAME=other tools/load.sh …` overrides the file.
if [ -f "$DB_DIR/.env" ]; then
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
    [ -n "${!key:-}" ] && continue
    export "$key=$value"
  done < <(grep -v '^[[:space:]]*#' "$DB_DIR/.env" | grep '=')
fi

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-livfinder}"
DB_SOCKET="${DB_SOCKET:-}"
WITH_MYSQL8=0
FRESH=0
COMMAND=""

for arg in "$@"; do
  case "$arg" in
    migrate|seed|all|verify|integrity) COMMAND="$arg" ;;
    --with-mysql8) WITH_MYSQL8=1 ;;
    --fresh) FRESH=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done
[ -n "$COMMAND" ] || { echo "usage: $0 {migrate|seed|all|verify|integrity} [--fresh] [--with-mysql8]" >&2; exit 2; }

# Connection arguments.
#
# For a local server, prefer the unix socket and do NOT pass --host/--port:
# passing an explicit port makes the client use TCP even for "localhost", which
# then fails against a root account authenticated by the unix_socket plugin — the
# default on Debian/Ubuntu MySQL and MariaDB packages.
#
# Every session runs in UTC, because the application does.
#
# `v_public_listings` decides visibility with `expires_at > now(3)`, and the API pins
# `time_zone = '+00:00'` on every pooled connection (livfinder-backend/src/db/pool.js).
# The client here inherited the host zone instead, so the same view returned different
# rows to the API and to this suite: three listings expiring at 09:00 UTC counted as
# expired five hours early, and the integrity run reported "projection contains a
# non-public listing" against a projection the API considered correct. Public has to
# mean one thing.
mysql_args=(--user="$DB_USER" --init-command="SET SESSION time_zone = '+00:00'")
if [ -n "$DB_SOCKET" ]; then
  mysql_args+=(--socket="$DB_SOCKET")
elif [ "$DB_HOST" != "localhost" ] && [ "$DB_HOST" != "" ]; then
  mysql_args+=(--host="$DB_HOST" --port="$DB_PORT")
fi
[ -n "$DB_PASSWORD" ] && mysql_args+=(--password="$DB_PASSWORD")

run_sql() { mysql "${mysql_args[@]}" "$@"; }

apply() {
  local file="$1" label
  label="$(basename "$file")"
  local start elapsed
  start=$(date +%s)

  local output
  output=$(run_sql "$DB_NAME" < "$file" 2>&1) || true

  if grep -qi '^ERROR' <<<"$output"; then
    printf '  %-40s FAILED\n' "$label"
    grep -i '^ERROR' <<<"$output" | head -3 | sed 's/^/      /'
    return 1
  fi
  elapsed=$(( $(date +%s) - start ))
  printf '  %-40s ok  %3ds\n' "$label" "$elapsed"
}

if [ "$FRESH" -eq 1 ]; then
  echo "Recreating database ${DB_NAME}…"
  run_sql -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;
              CREATE DATABASE \`${DB_NAME}\`
                CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
fi

# Make sure the database exists before anything else touches it.
run_sql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
              CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

failed=0

is_post_seed_migration() {
  case "$(basename "$1")" in
    0031_admin_permission_catalog.sql|0032_permission_model.sql|0034_drop_category_encoded_permissions.sql)
      return 0 ;;
    # 0040 backfills account_category_access from the seeded organisation grants,
    # so on a fresh `all` load it must run after the identity seeds.
    0040_account_category_access.sql)
      return 0 ;;
    # 0041's category_features rows reference the categories seeded in 030.
    0041_car_watch_features.sql)
      return 0 ;;
    # 0043's category_features rows reference categories 4, 5 and 7 (seeded in 030).
    0043_aviation_development_features.sql)
      return 0 ;;
    # 0046's backfill UPDATEs reference the aircraft brand slugs seeded in 031_brands.sql.
    0046_aircraft_brand_segment.sql)
      return 0 ;;
    # 0048's backfill reads the seeded listings/organizations to grant category access.
    0048_category_access_backfill.sql)
      return 0 ;;
    # 0051's backfill reads the seeded projects/organizations to grant developments access.
    0051_developments_access_backfill.sql)
      return 0 ;;
    # 0052 recomputes allowance usage from the seeded listings and category grants.
    0052_listing_usage_recompute.sql)
      return 0 ;;
    # 0053 redefines the counter rollup and recomputes counters from the seeded rows.
    0053_entity_counters_slot_rule.sql)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

if [ "$COMMAND" = "migrate" ] || [ "$COMMAND" = "all" ]; then
  echo "Applying migrations…"
  for file in "$DB_DIR"/migrations/*.sql; do
    base="$(basename "$file")"
    # 0031, 0032 and 0034 upgrade the original seeded permission catalogue and roles.
    # Existing databases already contain that data, so `migrate` applies them
    # normally. A fresh `all` load must seed the legacy catalogue first, then
    # run these data migrations; applying them before 032_access_and_plans.sql
    # creates conflicting permission ids and makes every identity seed cascade.
    if [ "$COMMAND" = "all" ] && is_post_seed_migration "$file"; then
      continue
    fi
    if [[ "$base" == 0015_* ]] && [ "$WITH_MYSQL8" -eq 0 ]; then
      printf '  %-40s skipped (pass --with-mysql8)\n' "$base"
      continue
    fi
    apply "$file" || failed=1
  done
fi

if [ "$COMMAND" = "seed" ] || [ "$COMMAND" = "all" ]; then
  echo "Applying seeds…"
  # Order is load-bearing: seeds are numbered so each file's foreign keys already
  # resolve when it runs. The glob sorts lexically, which is why every file is
  # numbered with a fixed-width prefix.
  for file in "$DB_DIR"/seeds/*.sql; do
    apply "$file" || failed=1
  done

  # `051_demo_seed_images.sql` writes `/media/seed/...` paths; the files those name travel with
  # the seeds and have to be copied into the API's storage directory, which is not in version
  # control. Without this the demo catalogue seeds correctly and renders grey placeholders.
  #
  # Skipped, not failed, when that directory is not reachable from here. The loader legitimately
  # runs somewhere the storage mount does not exist — `db_loader` in docker-compose.test.yml sees
  # only `./db/db:/db:ro` — and the seeding itself is complete and correct in that case. Saying so
  # and moving on beats failing a good load, as long as it says it loudly enough to act on.
  media_storage="${STORAGE_DIR:-$(cd "$DB_DIR/../.." 2>/dev/null && pwd)/livfinder-backend/storage}"
  if [ ! -x "$DB_DIR/tools/install-seed-media.sh" ]; then
    :
  elif [ -d "$media_storage" ]; then
    echo "Installing seed media…"
    STORAGE_DIR="$media_storage" "$DB_DIR/tools/install-seed-media.sh" || failed=1
  else
    echo "Seed media NOT installed — no storage directory at $media_storage"
    echo "  The catalogue will render placeholders until you run, on the API's own host:"
    echo "    STORAGE_DIR=/path/to/livfinder-backend/storage $DB_DIR/tools/install-seed-media.sh"
  fi
fi

if [ "$COMMAND" = "all" ]; then
  echo "Applying post-seed data migrations…"
  for file in "$DB_DIR"/migrations/*.sql; do
    is_post_seed_migration "$file" || continue
    apply "$file" || failed=1
  done
fi

if [ "$COMMAND" = "verify" ] || [ "$COMMAND" = "all" ]; then
  echo "Verifying…"

  # Guard against a false green. Nearly every assertion is "count the rows that
  # disagree", which is trivially 0 on an empty table — so an empty database
  # would otherwise report all-PASS. Check the core tables are populated first.
  for check in "locations:100000" "listings:100" "users:50" "inquiries:100" \
               "listing_search:50" "categories:20" "brands:50" \
               "leads:50" "media_assets:100" "url_inventory:100" \
               "property_units:50" "credit_transactions:20" "kpi_values:20"; do
    table="${check%%:*}"; minimum="${check##*:}"
    actual=$(run_sql --batch --skip-column-names "$DB_NAME" \
               -e "SELECT COUNT(*) FROM \`$table\`;" 2>/dev/null || echo 0)
    if [ "${actual:-0}" -lt "$minimum" ]; then
      printf '  %-66s FAIL (%s rows, expected >= %s)\n' \
             "$table is populated" "${actual:-0}" "$minimum"
      failed=1
    fi
  done

  # The finalise files both derive the counters and assert they agree with
  # their sources. Every assertion must report 0.
  for finalise in "$DB_DIR/seeds/049_demo_finalise.sql" \
                  "$DB_DIR/seeds/099_platform_finalise.sql"; do
    [ -f "$finalise" ] || continue
    results=$(run_sql --batch --skip-column-names "$DB_NAME" < "$finalise" 2>&1)
    if grep -qi '^ERROR' <<<"$results"; then
      grep -i '^ERROR' <<<"$results" | head -3 | sed 's/^/      /'
      failed=1
      continue
    fi
    while IFS=$'\t' read -r assertion count; do
      [ -n "${assertion:-}" ] || continue
      [ -n "${count:-}" ] || continue
      if [ "$count" = "0" ]; then
        printf '  %-66s PASS\n' "$assertion"
      else
        printf '  %-66s FAIL (%s)\n' "$assertion" "$count"
        failed=1
      fi
    done <<<"$results"
  done
fi

# The consistency suite. This used to live in the Makefile as a bare
# `mysql $(DB_NAME)` with no host, port, user or password, piped straight into
# awk. Against this environment — MySQL on 3307 with a password — the client
# could not connect at all, awk received nothing, and the target printed
# "0 check(s) failed" and exited 0. A connection failure reported success.
#
# Running it here means it uses the same connection resolution as every other
# command, and the checks below make silence an error rather than a pass.
if [ "$COMMAND" = "integrity" ]; then
  echo "Checking integrity…"
  integrity_sql="$DB_DIR/tools/integrity_check.sql"
  [ -f "$integrity_sql" ] || { echo "missing $integrity_sql" >&2; exit 1; }

  # Capture the client's own exit status rather than letting the pipeline hide it.
  set +e
  output=$(run_sql --batch --skip-column-names "$DB_NAME" < "$integrity_sql" 2>&1)
  mysql_status=$?
  set -e

  if [ "$mysql_status" -ne 0 ]; then
    echo "  mysql exited $mysql_status — the integrity suite did not run." >&2
    printf '%s\n' "$output" | head -5 | sed 's/^/      /' >&2
    exit 1
  fi
  if grep -qi '^ERROR' <<<"$output"; then
    echo "  the integrity suite reported an error:" >&2
    grep -i '^ERROR' <<<"$output" | head -5 | sed 's/^/      /' >&2
    exit 1
  fi

  checks=0
  bad=0
  while IFS=$'\t' read -r name count; do
    [ -n "${name:-}" ] || continue
    if [ -z "${count:-}" ]; then
      # A single-column row is a group heading in the suite's output.
      printf '\n%s\n' "$name"
      continue
    fi
    checks=$(( checks + 1 ))
    if [ "$count" = "0" ]; then
      printf '  %-54s PASS\n' "$name"
    else
      printf '  %-54s FAIL (%s)\n' "$name" "$count"
      bad=$(( bad + 1 ))
    fi
  done <<<"$output"

  echo
  # No checks at all means the suite never ran — the exact failure the old target
  # reported as success.
  if [ "$checks" -eq 0 ]; then
    echo "no checks were received — the integrity suite did not run." >&2
    exit 1
  fi
  if [ "$checks" -lt "${INTEGRITY_MIN_CHECKS:-90}" ]; then
    echo "only $checks checks ran, expected at least ${INTEGRITY_MIN_CHECKS:-90}." >&2
    exit 1
  fi
  printf '%d check(s) run, %d failed\n' "$checks" "$bad"
  [ "$bad" -eq 0 ] || exit 1
fi

if [ "$failed" -ne 0 ]; then
  echo
  echo "One or more steps failed." >&2
  exit 1
fi

echo
echo "Done."
