#!/bin/bash
# Prints the developer directory to use, and fails if nothing new enough exists.
#
# `xcode-select -switch /Applications/Xcode_26.6.app` looks like pinning but is
# really a bet that a specific bundle exists on the machine. It does not on every
# runner image, and when the image is updated it stops existing on the one it did
# — the first version of this workflow died in 20 seconds for exactly that reason.
#
# Pinning a *minimum* and reporting what was chosen is reproducible in the way
# that matters: the build fails if the toolchain is too old, and the log always
# says which one ran.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=versions.env
source "$REPO_ROOT/scripts/versions.env"

version_of() {
  local app="$1"
  /usr/bin/defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "0"
}

# Sorts versions numerically rather than lexically, so 26.10 beats 26.9.
version_at_least() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

PREFERRED="/Applications/Xcode_${XCODE_PREFERRED_VERSION}.app"
if [[ -d "$PREFERRED" ]]; then
  echo "$PREFERRED/Contents/Developer"
  echo "Using preferred Xcode $XCODE_PREFERRED_VERSION" >&2
  exit 0
fi

BEST=""
BEST_VERSION="0"
for app in /Applications/Xcode*.app; do
  [[ -d "$app" ]] || continue
  candidate="$(version_of "$app")"
  if version_at_least "$candidate" "$BEST_VERSION"; then
    BEST="$app"
    BEST_VERSION="$candidate"
  fi
done

if [[ -z "$BEST" ]]; then
  echo "ERROR: no Xcode found in /Applications" >&2
  exit 1
fi

if ! version_at_least "$BEST_VERSION" "$XCODE_MIN_VERSION"; then
  echo "ERROR: newest Xcode is $BEST_VERSION, below the required minimum $XCODE_MIN_VERSION" >&2
  exit 1
fi

echo "$BEST/Contents/Developer"
echo "Preferred Xcode $XCODE_PREFERRED_VERSION not present; using $BEST_VERSION" >&2
