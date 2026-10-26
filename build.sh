#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/build/AirPlayKeys.app"
CONTENTS="$APP/Contents"

command -v xcrun >/dev/null || { echo 'Xcode Command Line Tools fehlen: xcode-select --install' >&2; exit 1; }
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

xcrun swiftc -O -swift-version 5 \
  -framework AppKit -framework ApplicationServices \
  "$ROOT/AirPlayKeys.swift" -o "$CONTENTS/MacOS/AirPlayKeys"

xcrun swift "$ROOT/Tools/GenerateIcon.swift" "$CONTENTS/Resources"
codesign --force --sign - "$APP"

printf '\nBuild erfolgreich: %s\n' "$APP"
printf 'Starten: open "%s"\n' "$APP"
