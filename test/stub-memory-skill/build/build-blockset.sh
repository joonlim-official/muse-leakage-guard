#!/usr/bin/env bash
# build-blockset.sh — (re)generate bin/blockset.txt, the stub detector's
# declared set of synthetic block-tier tokens (sha256, one per line).
#
# Sources: (1) every adversarial-corpus case with want=1, (2) the stub
# skill's own block-tier fixtures in bin/fixtures. Candidates are
# extracted with bin/patterns.sh — the SAME patterns the runtime
# detector uses, so the build and the verdict can never disagree about
# what a "token" is.
#
# Usage: build/build-blockset.sh [--check]
#   default: rewrite bin/blockset.txt (sorted, deduplicated)
#   --check: exit 0 if blockset.txt is current, 1 if it would change
#            (used by CI and the audit's fixture-purity check)
#
# Every token hashed here is a DECLARED SYNTHETIC fixture from the
# leakage-guard corpus — shaped to trip detectors, belonging to nobody.
set -u
STUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$STUB_DIR/bin/patterns.sh"
GUARD_DIR="$(cd "$STUB_DIR/../.." && pwd)"
CORPUS="$GUARD_DIR/bin/adversarial-corpus.txt"
FIXDIR="$STUB_DIR/bin/fixtures"
OUT="$STUB_DIR/bin/blockset.txt"

[ -f "$CORPUS" ] || { echo "build-blockset: corpus not found: $CORPUS" >&2; exit 2; }

tmp="$(mktemp)"; trap 'rm -f "$tmp" "$tmp.hashes"' EXIT
# 1) corpus want=1 cases (one per line — never concatenate two cases onto
#    the same line, or greedy shape patterns would fuse tokens across cases)
while IFS='|' read -r name want content; do
  case "$name" in ''|'#'*) continue;; esac
  [ "$want" = "1" ] || continue
  printf '%s\n' "$content"
done < "$CORPUS" >> "$tmp"
# 2) stub's own block-tier fixtures (newline-separated: a fixture missing its
#    trailing newline must not fuse tokens with the next file's first token)
for f in secret.txt secret2.txt ssn.txt card.txt; do
  [ -f "$FIXDIR/$f" ] && { cat "$FIXDIR/$f"; printf '\n'; } >> "$tmp"
done
# 3) the guard's own block-tier fixtures (suite B classifies these through
#    the target's gates, so the stub must know their exact tokens)
for f in secret.txt secret2.txt ssn.txt card.txt; do
  [ -f "$GUARD_DIR/bin/fixtures/$f" ] && { cat "$GUARD_DIR/bin/fixtures/$f"; printf '\n'; } >> "$tmp"
done

grep -oE "$STUB_SECRET_CAND" "$tmp" | sort -u | while IFS= read -r tok; do
  [ -n "$tok" ] && printf '%s' "$tok" | sha256sum | cut -d' ' -f1
done | sort -u > "$tmp.hashes"

n="$(wc -l < "$tmp.hashes" | tr -d ' ')"
if [ "$n" -eq 0 ]; then
  echo "build-blockset: no block-tier tokens extracted — refusing to write an empty set" >&2
  exit 2
fi

if [ "${1:-}" = "--check" ]; then
  if [ -f "$OUT" ] && cmp -s "$tmp.hashes" "$OUT"; then
    echo "build-blockset: blockset.txt is current ($n tokens)"
    exit 0
  fi
  echo "build-blockset: blockset.txt is STALE (would contain $n tokens)" >&2
  exit 1
fi

cp "$tmp.hashes" "$OUT"
echo "build-blockset: wrote $OUT ($n tokens)"
