#!/bin/bash
# SmartPause.app paketini üretir: swift build → .app iskeleti → ad-hoc imza.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/SmartPause.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SmartPause "$APP/Contents/MacOS/SmartPause"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Ad-hoc imza: Accessibility/Automation izinleri imzalı bundle kimliğine bağlanır, her derlemede sıfırlanmaz.
codesign --force --sign - --identifier dev.smartpause.app "$APP"
echo "Hazır: $APP"
