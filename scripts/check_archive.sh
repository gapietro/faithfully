#!/bin/bash
# Asserts the archive declares what the product actually supports.
#
# The archive building is not the interesting part; what it *declares* is. The
# audit found UIDeviceFamily [1,2] with only iPhone portrait configured, which
# warns at archive time and risks App Store validation (CLEAN-010). Checking the
# built Info.plist catches a regression that a green build would hide.
set -euo pipefail

ARCHIVE="${1:?usage: check_archive.sh <archive-path>}"
PLIST="$ARCHIVE/Products/Applications/Faithfully.app/Info.plist"

if [[ ! -f "$PLIST" ]]; then
  echo "ERROR: no Info.plist at $PLIST" >&2
  exit 1
fi

# plutil emits JSON, which is unambiguous. PlistBuddy's "Array { 1 }" needs
# text munging that is easy to get subtly wrong in either direction.
FAMILY="$(plutil -extract UIDeviceFamily json -o - "$PLIST")"
if [[ "$FAMILY" != "[1]" ]]; then
  echo "ERROR: expected UIDeviceFamily [1] (iPhone only), got: $FAMILY" >&2
  exit 1
fi

if /usr/libexec/PlistBuddy -c "Print :UISupportedInterfaceOrientations~ipad" "$PLIST" >/dev/null 2>&1; then
  echo "ERROR: archive declares iPad orientations for an iPhone-only app" >&2
  exit 1
fi

ORIENTATIONS="$(/usr/libexec/PlistBuddy -c "Print :UISupportedInterfaceOrientations~iphone" "$PLIST")"
if ! grep -q "UIInterfaceOrientationPortrait" <<< "$ORIENTATIONS"; then
  echo "ERROR: iPhone portrait is not declared" >&2
  exit 1
fi

echo "OK: archive declares iPhone-only, portrait, with no iPad orientations"
