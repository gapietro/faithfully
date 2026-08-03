#!/bin/bash
# Prints an xcodebuild destination for an available iPhone simulator.
#
# Naming a device that the installed runtime does not have makes xcodebuild fail
# with a destination error that reads like a build failure. Preferring the pinned
# device and falling back to any available iPhone — while saying which — keeps a
# runner image update from looking like a code regression.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=versions.env
source "$REPO_ROOT/scripts/versions.env"

AVAILABLE="$(xcrun simctl list devices available)"

if grep -qE "^\s+${SIMULATOR_NAME} \(" <<< "$AVAILABLE"; then
  echo "platform=iOS Simulator,name=$SIMULATOR_NAME"
  echo "Using pinned simulator: $SIMULATOR_NAME" >&2
  exit 0
fi

FALLBACK="$(grep -oE "^\s+iPhone [^(]+" <<< "$AVAILABLE" | sed 's/^ *//;s/ *$//' | head -1)"
if [[ -z "$FALLBACK" ]]; then
  echo "ERROR: no iPhone simulator is available" >&2
  echo "$AVAILABLE" >&2
  exit 1
fi

echo "platform=iOS Simulator,name=$FALLBACK"
echo "Pinned simulator '$SIMULATOR_NAME' unavailable; using '$FALLBACK'" >&2
