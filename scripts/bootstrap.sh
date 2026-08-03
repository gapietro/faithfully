#!/bin/bash
# Installs the pinned build tools into .tools/ so a fresh checkout can run every
# quality check without anything preinstalled.
#
# The audit could not verify lint at all: swiftlint was simply not on the machine
# and nothing in the repository installed it. A check nobody can run is not a
# gate. Versions and checksums are pinned in scripts/versions.env, so CI and a
# laptop cannot disagree about whether the code passes.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/.tools"
# shellcheck source=versions.env
source "$REPO_ROOT/scripts/versions.env"

mkdir -p "$TOOLS_DIR"

# Downloads and verifies against the pinned checksum before unpacking. A tool
# fetched over the network without one is an unreviewed binary in the build.
fetch_and_unpack() {
  local name="$1" version="$2" expected_sha="$3" url="$4" dest="$5"

  echo "==> Installing $name $version"
  local tmp
  tmp="$(mktemp -d)"

  curl --fail --silent --show-error --location --retry 3 -o "$tmp/archive.zip" "$url"

  local actual_sha
  actual_sha="$(shasum -a 256 "$tmp/archive.zip" | awk '{print $1}')"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "ERROR: checksum mismatch for $name $version" >&2
    echo "  expected: $expected_sha" >&2
    echo "  actual:   $actual_sha" >&2
    rm -rf "$tmp"
    exit 1
  fi

  rm -rf "$dest"
  mkdir -p "$dest"
  unzip -q -o "$tmp/archive.zip" -d "$dest"
  rm -rf "$tmp"
}

already_installed() {
  local name="$1" version="$2"
  [[ -f "$TOOLS_DIR/.$name-$version" && -x "$TOOLS_DIR/$name" ]]
}

mark_installed() {
  local name="$1" version="$2"
  rm -f "$TOOLS_DIR/.$name-"*
  touch "$TOOLS_DIR/.$name-$version"
}

# SwiftLint's portable archive is a bare binary at the archive root.
if already_installed swiftlint "$SWIFTLINT_VERSION"; then
  echo "==> swiftlint $SWIFTLINT_VERSION already installed"
else
  fetch_and_unpack swiftlint "$SWIFTLINT_VERSION" "$SWIFTLINT_SHA256" \
    "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/portable_swiftlint.zip" \
    "$TOOLS_DIR/swiftlint-dist"
  install -m 0755 "$TOOLS_DIR/swiftlint-dist/swiftlint" "$TOOLS_DIR/swiftlint"
  mark_installed swiftlint "$SWIFTLINT_VERSION"
fi

# XcodeGen ships bin/ plus share/, and resolves its bundled settings relative to
# the executable — so the tree has to stay intact and the entry point is a
# wrapper rather than a copied binary.
if already_installed xcodegen "$XCODEGEN_VERSION"; then
  echo "==> xcodegen $XCODEGEN_VERSION already installed"
else
  fetch_and_unpack xcodegen "$XCODEGEN_VERSION" "$XCODEGEN_SHA256" \
    "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip" \
    "$TOOLS_DIR/xcodegen-dist"
  cat > "$TOOLS_DIR/xcodegen" <<'WRAPPER'
#!/bin/bash
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/xcodegen-dist/xcodegen/bin/xcodegen" "$@"
WRAPPER
  chmod +x "$TOOLS_DIR/xcodegen"
  mark_installed xcodegen "$XCODEGEN_VERSION"
fi

echo
echo "Installed into $TOOLS_DIR:"
echo "  $("$TOOLS_DIR/swiftlint" version | sed 's/^/swiftlint /')"
echo "  xcodegen $("$TOOLS_DIR/xcodegen" --version 2>&1 | tail -1)"
