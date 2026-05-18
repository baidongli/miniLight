#!/usr/bin/env bash
# Guards against forgetting to bump the app version. Compares the marketing
# version in pubspec.yaml against the highest released `v<semver>` git tag.
#
#   - new version is higher        -> OK
#   - no release tags yet          -> OK (first release)
#   - version not bumped:
#       * on main (real releases)  -> FAIL the build
#       * on a branch              -> warning only (dev iterations)
set -euo pipefail

V=$(grep -E '^version:' pubspec.yaml \
  | sed -E 's/version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
if [[ -z "$V" ]]; then
  echo "::error::Could not parse 'version:' from pubspec.yaml"
  exit 1
fi

git fetch --tags --quiet || true
LAST=$(git tag --list 'v*' \
  | sed 's/^v//' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -1 || true)

echo "pubspec version: $V"
echo "last released:   ${LAST:-<none>}"

if [[ -z "$LAST" ]]; then
  echo "No release tags yet — OK."
  exit 0
fi

if dpkg --compare-versions "$V" gt "$LAST"; then
  echo "Version bumped ($LAST -> $V) — OK."
  exit 0
fi

MSG="App version not bumped: pubspec is $V but $LAST is already released. \
Edit 'version:' in pubspec.yaml (e.g. to a higher x.y.z) before shipping — \
the stores reject re-used version numbers."

if [[ "${GITHUB_REF_NAME:-}" == "main" ]]; then
  echo "::error::$MSG"
  exit 1
else
  echo "::warning::$MSG"
  exit 0
fi
