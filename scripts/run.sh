#!/bin/zsh
# Builds the app and launches it in the simulator (default: SayAgain iPhone 17 Pro).
# Usage: ./scripts/run.sh            build, install, launch
#        ./scripts/run.sh --no-build launch what is already installed
#        DEVICE="SayAgain iPhone 17 Pro Max" ./scripts/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-SayAgain iPhone 17 Pro}"
BUNDLE_ID="dev.flakyhunter.sayagain"
APP=".build/dd/Build/Products/Debug-iphonesimulator/SayAgain.app"

UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[[ -n "$UDID" ]] || { echo "Simulator \"$DEVICE\" not found"; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

if [[ "${1:-}" != "--no-build" ]]; then
  xcodegen generate --quiet
  xcodebuild build -project SayAgain.xcodeproj -scheme SayAgain \
    -destination "id=$UDID" -derivedDataPath .build/dd -quiet
  xcrun simctl install "$UDID" "$APP"
fi

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID"
