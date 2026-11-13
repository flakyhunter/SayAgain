#!/bin/zsh
# Captures App Store screenshots (6.9", iPhone 17 Pro Max) into AppStore/screenshots.
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-SayAgain iPhone 17 Pro Max}"
OUT="AppStore/screenshots"
RESULT=".build/screenshots.xcresult"

UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularMode active --cellularBars 4 --dataNetwork wifi

xcodegen generate --quiet
rm -rf "$RESULT"
TEST_RUNNER_SAYAGAIN_SCREENSHOTS=1 xcodebuild test -project SayAgain.xcodeproj -scheme SayAgain \
  -destination "id=$UDID" -derivedDataPath .build/dd -resultBundlePath "$RESULT" \
  -only-testing:SayAgainUITests/AppStoreScreenshots CODE_SIGNING_ALLOWED=NO -quiet

rm -rf "$OUT" .build/attachments && mkdir -p "$OUT" .build/attachments
xcrun xcresulttool export attachments --path "$RESULT" --output-path .build/attachments
python3 - "$OUT" <<'PY'
import json, shutil, sys, pathlib
out = pathlib.Path(sys.argv[1]); src = pathlib.Path(".build/attachments")
for test in json.load(open(src / "manifest.json")):
    for a in test["attachments"]:
        name = a.get("suggestedHumanReadableName", a["exportedFileName"]).split("_")[0]
        shutil.copy(src / a["exportedFileName"], out / f"{name}.png")
        print("saved", out / f"{name}.png")
PY
xcrun simctl status_bar "$UDID" clear
