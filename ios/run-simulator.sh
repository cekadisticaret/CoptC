#!/usr/bin/env bash
# Mac'te CoptC'yi iOS Simulator'da derle + kur + aç.
set -euo pipefail
[[ "$(uname -s)" == "Darwin" ]] || { echo "Bu script yalnızca Mac'te çalışır."; exit 1; }

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
BUNDLE_ID="tr.deadella.coptc"
DD="/tmp/coptc-ios-dd"
APP="$DD/Build/Products/Debug-iphonesimulator/CoptC.app"

command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate

UDID="$(xcrun simctl list devices booted -j | python3 -c "import json,sys; d=json.load(sys.stdin);
devs=[x for xs in d.get('devices',{}).values() for x in xs if 'iPhone' in x.get('name','')];
print(devs[0]['udid'] if devs else '')")"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin);
xs=[x for xs in d.get('devices',{}).values() for x in xs
    if x.get('isAvailable') and 'iPhone' in x.get('name','')];
xs.sort(key=lambda x: x.get('name',''), reverse=True);
print(xs[0]['udid'] if xs else '')")"
fi
[[ -n "$UDID" ]] || { echo "iPhone simülatörü yok. Xcode → Settings → Platforms."; exit 1; }

xcodebuild -project CoptC.xcodeproj -scheme CoptC -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO build

open -a Simulator
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID"
echo "CoptC Simulator'da açıldı ($UDID)"
