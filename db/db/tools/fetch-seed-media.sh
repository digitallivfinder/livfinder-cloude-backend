#!/usr/bin/env bash
#
# Download the seed photographs listed in db/seeds/media/SOURCES.tsv.
#
# The files are committed, so a normal checkout never needs this. It exists so the set can be
# rebuilt or extended reproducibly: add a row to SOURCES.tsv, run this, and the new file lands
# as <category>/<pool>-NN.jpg with NN following the row's position inside its pool.
#
# Every image is cropped to 3:2 at 1280×853 — the ratio the listing cards and galleries render
# at — so a portrait original never letterboxes a card.
#
# Usage
#   tools/fetch-seed-media.sh           # download only what is missing
#   FORCE=1 tools/fetch-seed-media.sh   # re-download everything

set -euo pipefail

DB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEDIA="$DB_DIR/seeds/media"
MANIFEST="$MEDIA/SOURCES.tsv"
PARAMS="w=1280&h=853&fit=crop&crop=center&q=62&fm=jpg"

[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 1; }

# awk numbers each row within its pool; the shell stays bash 3 (macOS) compatible.
fetched=0; kept=0; failed=0
while IFS=$'\t' read -r name id; do
  file="$MEDIA/$name"
  mkdir -p "$(dirname "$file")"
  if [ -s "$file" ] && [ -z "${FORCE:-}" ]; then kept=$(( kept + 1 )); continue; fi
  if curl -fsSL --retry 3 -o "$file.part" "https://images.unsplash.com/$id?$PARAMS" \
     && file "$file.part" | grep -q 'JPEG'; then
    mv "$file.part" "$file"; fetched=$(( fetched + 1 ))
  else
    rm -f "$file.part"; echo "  failed: $name $id" >&2; failed=$(( failed + 1 ))
  fi
done < <(awk -F'\t' '!/^#/ && NF >= 3 { n[$1 "/" $2]++; printf "%s/%s-%02d.jpg\t%s\n", $1, $2, n[$1 "/" $2], $3 }' "$MANIFEST")

echo "fetched $fetched, already present $kept, failed $failed"
[ "$failed" -eq 0 ]
