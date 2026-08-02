#!/bin/bash
# Enforces a line-coverage floor for Services and ViewModels.
#
# Deliberately not whole-app coverage: most of the remaining code is SwiftUI view
# bodies, whose coverage number is dominated by how much of the tree a UI test
# happened to walk. A floor over the logic is a claim that can actually hold.
set -euo pipefail

RESULT_BUNDLE="${1:?usage: check_coverage.sh <result-bundle> <minimum-percent>}"
MINIMUM="${2:?usage: check_coverage.sh <result-bundle> <minimum-percent>}"

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "ERROR: no result bundle at $RESULT_BUNDLE — run 'make test' first" >&2
  exit 1
fi

JSON="$(xcrun xccov view --report --json "$RESULT_BUNDLE")"

read -r COVERED EXECUTABLE < <(
  python3 -c '
import json, sys
report = json.load(sys.stdin)
covered = executable = 0
for target in report.get("targets", []):
    if target.get("name", "").startswith("Faithfully.app"):
        for f in target.get("files", []):
            path = f.get("path", "")
            if "/Services/" in path or "/ViewModels/" in path:
                covered += f.get("coveredLines", 0)
                executable += f.get("executableLines", 0)
print(covered, executable)
' <<< "$JSON"
)

if [[ "$EXECUTABLE" -eq 0 ]]; then
  echo "ERROR: no Services/ViewModels lines found in the coverage report." >&2
  echo "       Either the report is empty or the paths changed — failing rather" >&2
  echo "       than reporting a vacuous 100%." >&2
  exit 1
fi

PERCENT="$(python3 -c "print(f'{100 * $COVERED / $EXECUTABLE:.2f}')")"
echo "Services/ViewModels line coverage: $PERCENT% ($COVERED/$EXECUTABLE lines)"

if python3 -c "import sys; sys.exit(0 if $PERCENT >= $MINIMUM else 1)"; then
  echo "OK: at or above the $MINIMUM% floor"
else
  echo "ERROR: below the $MINIMUM% floor" >&2
  exit 1
fi
