#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
commit="${1:?Usage: build-macos.sh FULL_COMMIT_SHA}"
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid commit SHA' >&2; exit 1; }
[[ "$(git rev-parse HEAD)" == "$commit" ]] || { echo 'Checkout does not match build SHA' >&2; exit 1; }
python3 scripts/download-models.py
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
xcodebuild -project azooKeyMac.xcodeproj -scheme azooKeyMac \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$work/archive.xcarchive" -derivedDataPath "$work/derived" \
  -clonedSourcePackagesDirPath "$work/packages" \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO archive
app="$work/archive.xcarchive/Products/Applications/azooKeyMac.app"
test -d "$app"
# Development installer. Distribution signing/notarization requires Apple credentials.
codesign --force --deep --sign - "$app"
mkdir -p installer
pkgbuild --component "$app" --install-location '/Library/Input Methods' \
  --identifier dev.ensan.inputmethod.azooKeyMac --version 0.1.0 \
  "installer/azooKey-wooden-structure-$commit.pkg"
