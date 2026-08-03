#!/bin/bash
# Builds under complete concurrency checking and fails on any project-owned
# warning.
#
# xcodebuild exits 0 on warnings, so "the build succeeded" says nothing about
# whether Swift 6 data-race diagnostics appeared. Every warning under this
# repository's own path counts, not only concurrency ones — a warning the team
# has decided to live with is a warning nobody reads. SDK and toolchain noise is
# excluded because it is not ours to fix.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/versions.env"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

set +e
xcodebuild -project "$REPO_ROOT/Faithfully.xcodeproj" -scheme Faithfully \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  SWIFT_STRICT_CONCURRENCY=complete build > "$LOG" 2>&1
BUILD_STATUS=$?
set -e

if [[ $BUILD_STATUS -ne 0 ]]; then
  echo "ERROR: strict-concurrency build failed" >&2
  grep -E "error:" "$LOG" | sort -u | head -40 >&2
  exit 1
fi

FINDINGS="$(grep -E "^${REPO_ROOT}/(Faithfully|FaithfullyTests|FaithfullyUITests)/.*warning:" "$LOG" | sort -u || true)"

if [[ -n "$FINDINGS" ]]; then
  COUNT="$(wc -l <<< "$FINDINGS" | tr -d ' ')"
  echo "ERROR: $COUNT project-owned warning(s) under complete concurrency checking:" >&2
  sed "s|$REPO_ROOT/||" <<< "$FINDINGS" >&2
  exit 1
fi

echo "OK: no project-owned warnings under complete concurrency checking"
