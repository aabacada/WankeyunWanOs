#!/usr/bin/env bash
# Upload the 128 Release files for tag wanos-armv7-20261106 to aabacada/wankeyunwanos.
# Resumable: assets already present in the release are skipped; failed uploads
# are retried up to 3 times. Run from ~/workspace/wanos-market (relative paths
# in release-files.txt resolve from there). Progress goes to /tmp/wanos-release-upload.log.
set -u
REPO="aabacada/wankeyunwanos"
TAG="wanos-armv7-20261106"
MARKET="$HOME/workspace/wanos-market"
LIST="$MARKET/github-mirror/release-files.txt"
LOG="/tmp/wanos-release-upload.log"
cd "$MARKET"
: > "$LOG"
echo "$(date '+%F %T') starting release upload: $TAG (128 files, ~1.76 GiB)" | tee -a "$LOG"
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" --repo "$REPO" --title "WanOS armv7 2026-11-06 (offline mirror)" \
    --notes-file "$MARKET/github-mirror/README.md" >>"$LOG" 2>&1
  echo "$(date '+%F %T') release created" | tee -a "$LOG"
fi
n=0; total=$(wc -l < "$LIST")
while IFS= read -r f; do
  n=$((n+1))
  base=$(basename "$f")
  if gh release view "$TAG" --repo "$REPO" --json assets --jq ".assets[].name" 2>/dev/null | grep -qx "$base"; then
    echo "[$n/$total] SKIP (already present): $base" | tee -a "$LOG"
    continue
  fi
  ok=0
  for attempt in 1 2 3; do
    if gh release upload "$TAG" "$f" --repo "$REPO" --clobber >>"$LOG" 2>&1; then ok=1; break; fi
    echo "[$n/$total] retry $attempt failed: $base" | tee -a "$LOG"
    sleep 5
  done
  if [ $ok -eq 1 ]; then echo "[$n/$total] OK: $base" | tee -a "$LOG"; else echo "[$n/$total] FAILED: $base" | tee -a "$LOG"; fi
done < "$LIST"
echo "$(date '+%F %T') done: $(gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets | length') assets in release" | tee -a "$LOG"
