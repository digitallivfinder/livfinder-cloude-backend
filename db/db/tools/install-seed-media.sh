#!/usr/bin/env bash
#
# Copy the seed's images into the API's public storage.
#
# `db/seeds/051_demo_seed_images.sql` points the demo listings and developments at
# `/media/seed/<category>/<n>.jpg`. The API serves `/media/**` out of its local storage
# directory, and that directory is deliberately not in version control — it is where uploads
# land, and an environment's uploads are not the repo's business. So the files that the seed
# *does* own travel with the seed, and this puts them where the API can serve them.
#
# Idempotent: copies over whatever is already there and touches nothing else in storage.
#
# Usage
#   tools/install-seed-media.sh                     # ../../livfinder-backend/storage
#   STORAGE_DIR=/srv/livfinder/storage tools/install-seed-media.sh
#
# Run it once per environment, after `tools/load.sh seed` (order does not matter — the SQL
# writes paths, this writes files).

set -euo pipefail

DB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$DB_DIR/seeds/media"

# The API reads LOCAL_STORAGE_PATH relative to its own working directory, so the default here
# mirrors a checkout's layout: <repo>/livfinder-backend/storage.
DEFAULT_STORAGE="$(cd "$DB_DIR/../.." && pwd)/livfinder-backend/storage"
STORAGE_DIR="${STORAGE_DIR:-$DEFAULT_STORAGE}"
TARGET="$STORAGE_DIR/public/seed"

[ -d "$SOURCE" ] || { echo "no seed media at $SOURCE" >&2; exit 1; }

# The storage root must already exist.
#
# It is a deployment artifact — a bind mount, a volume, a directory someone created for the
# service — and never something this script should invent. Creating it means the target resolved
# somewhere the API cannot read, and the most likely place for that is inside a container that
# has no storage mount: `db_loader` in docker-compose.test.yml mounts only `./db/db:/db:ro`, so a
# `mkdir -p` there would write the images into a throwaway filesystem and report success while
# the running API went on serving placeholders. Refusing is what makes that visible.
if [ ! -d "$STORAGE_DIR" ]; then
  cat >&2 <<MSG
storage directory not found: $STORAGE_DIR

Nothing was copied. Run this on the host that owns the API's storage, and point it there:

  STORAGE_DIR=/path/to/livfinder-backend/storage $0

In Docker, that is the host side of the api service's storage bind mount, not a path inside the
database loader container.
MSG
  exit 1
fi

mkdir -p "$TARGET"
copied=0
for dir in "$SOURCE"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  mkdir -p "$TARGET/$name"
  for file in "$dir"*; do
    [ -f "$file" ] || continue
    cp -f "$file" "$TARGET/$name/"
    copied=$(( copied + 1 ))
  done
  printf '  %-16s %s file(s)\n' "$name" "$(ls -1 "$TARGET/$name" | wc -l | tr -d ' ')"
done

echo
echo "Installed $copied file(s) into $TARGET"
echo "The API serves these as \${STORAGE_PUBLIC_BASE_URL}/seed/<category>/<n>.jpg"
