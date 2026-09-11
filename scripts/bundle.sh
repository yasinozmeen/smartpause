#!/bin/bash
# SmartPause.app paketini üretir: swift build → .app iskeleti → ad-hoc imza.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/SmartPause.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SmartPause "$APP/Contents/MacOS/SmartPause"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# İmza: TCC (Erişilebilirlik/Otomasyon) izinleri imza kimliğine bağlıdır. Ad-hoc imza her derlemede
# değiştiği için izin düşer; "Apple Development" sertifikası varsa onu kullan (kimlik sabit kalır).
# Aynı adda birden fazla sertifika olabilir → isim yerine SHA-1 hash kullan.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 'Apple Development' | awk '{print $2}' || true)}"
if [ -n "$IDENTITY" ]; then
  codesign --force --sign "$IDENTITY" --identifier dev.smartpause.app "$APP"
  echo "İmza: $IDENTITY"
else
  codesign --force --sign - --identifier dev.smartpause.app "$APP"
  echo "İmza: ad-hoc (izinler her derlemede yeniden istenebilir)"
fi
echo "Hazır: $APP"
