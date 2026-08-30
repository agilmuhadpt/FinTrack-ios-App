#!/bin/bash
# Build FinTrack for the iOS simulator. Prints only errors + the final status line.
# Serialised with an atomic mkdir mutex: several agents share one derived-data path,
# and concurrent xcodebuild runs against it corrupt the build database.
set -o pipefail
# Repo-local by default so the script works on any machine; override with
# FINTRACK_DERIVED_DATA to share one derived-data dir between build.sh and test.sh.
BASE="${FINTRACK_DERIVED_DATA:-$(cd "$(dirname "$0")" && pwd)/.build}"
DD="$BASE/DerivedData"
LOCK="$BASE/build.lock"
mkdir -p "$BASE"
cd "$(dirname "$0")" || exit 1

# Acquire the mutex, waiting up to 15 min. A lock older than 20 min is stale -> reclaim.
for _ in $(seq 1 900); do
  if mkdir "$LOCK" 2>/dev/null; then LOCKED=1; break; fi
  if [ -d "$LOCK" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || date +%s) ))
    [ "$AGE" -gt 1200 ] && rm -rf "$LOCK"
  fi
  sleep 1
done
[ -z "$LOCKED" ] && { echo "error: could not acquire build lock"; exit 1; }
trap 'rm -rf "$LOCK"' EXIT INT TERM

xcodebuild -project FinTrack.xcodeproj -scheme FinTrack -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath "$DD" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" \
  | sed "s|$PWD/||g" | sort -u | head -60
