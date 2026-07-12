#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
BUILD_DIR="$ROOT/.build/release"
APP="$DIST_DIR/TC001 Bridge.app"
ZIP="$DIST_DIR/TC001-Bridge-macOS.zip"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
ARCHS_VALUE="${ARCHS:-$(uname -m)}"
architectures=(${=ARCHS_VALUE})

rm -rf "$BUILD_DIR" "$APP" "$ZIP" "$ZIP.sha256"
mkdir -p "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"

swift_sources=("${(@f)$(find "$ROOT/Sources" -name '*.swift' -print | sort)}")
binaries=()
helper_binaries=()

for architecture in "${architectures[@]}"; do
  binary="$BUILD_DIR/TC001Bridge-$architecture"
  swiftc \
    -swift-version 5 \
    -O \
    -parse-as-library \
    -target "$architecture-apple-macosx$DEPLOYMENT_TARGET" \
    "${swift_sources[@]}" \
    -framework AppKit \
    -framework Combine \
    -framework CoreBluetooth \
    -framework Foundation \
    -framework Network \
    -framework SwiftUI \
    -o "$binary"
  binaries+=("$binary")

  helper_binary="$BUILD_DIR/TC001UpdateHelper-$architecture"
  swiftc \
    -swift-version 5 \
    -O \
    -parse-as-library \
    -target "$architecture-apple-macosx$DEPLOYMENT_TARGET" \
    "$ROOT/UpdaterHelper/TC001UpdateHelper.swift" \
    -framework Foundation \
    -o "$helper_binary"
  helper_binaries+=("$helper_binary")
done

if (( ${#binaries[@]} == 1 )); then
  cp "${binaries[1]}" "$APP/Contents/MacOS/TC001Bridge"
else
  xcrun lipo -create "${binaries[@]}" -output "$APP/Contents/MacOS/TC001Bridge"
fi

if (( ${#helper_binaries[@]} == 1 )); then
  cp "${helper_binaries[1]}" "$APP/Contents/Helpers/TC001UpdateHelper"
else
  xcrun lipo -create "${helper_binaries[@]}" -output "$APP/Contents/Helpers/TC001UpdateHelper"
fi
chmod +x "$APP/Contents/Helpers/TC001UpdateHelper"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
sign_arguments=(--force --deep --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  sign_arguments+=(--options runtime --timestamp)
fi
codesign "${sign_arguments[@]}" "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(
  cd "$DIST_DIR"
  shasum -a 256 "${ZIP:t}" > "${ZIP:t}.sha256"
)

echo "$APP"
echo "$ZIP"
echo "$ZIP.sha256"
