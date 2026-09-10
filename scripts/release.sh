#!/bin/bash
# Sürüm paketi: bundle → zip → sha256 → cask güncelle. GitHub'a yükleme elle/`gh release` ile yapılır.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
./scripts/bundle.sh
ZIP="build/SmartPause-$VERSION.zip"
rm -f "$ZIP"; (cd build && ditto -c -k --keepParent SmartPause.app "SmartPause-$VERSION.zip")
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
sed -i '' "s/^  sha256 .*/  sha256 \"$SHA\"/" Casks/smartpause.rb
sed -i '' "s/^  version .*/  version \"$VERSION\"/" Casks/smartpause.rb
echo "Paket: $ZIP"; echo "sha256: $SHA"
echo "Yükleme: gh release create v$VERSION $ZIP --title \"SmartPause $VERSION\""
