#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
BUILD_DIR="$ROOT/.build/release"
APP="$DIST_DIR/TC001 Bridge.app"
ZIP="$DIST_DIR/TC001-Bridge-macOS.zip"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
WIDGET_DEPLOYMENT_TARGET="${WIDGET_MACOSX_DEPLOYMENT_TARGET:-14.0}"
ARCHS_VALUE="${ARCHS:-$(uname -m)}"
architectures=(${=ARCHS_VALUE})
WIDGET="$APP/Contents/PlugIns/TC001 Bridge Widget.appex"

rm -rf "$BUILD_DIR" "$APP" "$ZIP" "$ZIP.sha256"
mkdir -p "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
mkdir -p "$WIDGET/Contents/MacOS" "$WIDGET/Contents/Resources"

swift_sources=("${(@f)$(find "$ROOT/Sources" -name '*.swift' -print | sort)}")
binaries=()
helper_binaries=()
widget_binaries=()

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
    -framework WidgetKit \
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

  widget_binary="$BUILD_DIR/TC001BridgeWidget-$architecture"
  swiftc \
    -swift-version 5 \
    -O \
    -parse-as-library \
    -application-extension \
    -target "$architecture-apple-macosx$WIDGET_DEPLOYMENT_TARGET" \
    "$ROOT/Sources/WidgetStatusSnapshot.swift" \
    "$ROOT/WidgetExtension/TC001BridgeWidget.swift" \
    -framework AppKit \
    -framework Foundation \
    -framework SwiftUI \
    -framework WidgetKit \
    -Xlinker -e \
    -Xlinker _NSExtensionMain \
    -o "$widget_binary"
  widget_binaries+=("$widget_binary")
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

if (( ${#widget_binaries[@]} == 1 )); then
  cp "${widget_binaries[1]}" "$WIDGET/Contents/MacOS/TC001BridgeWidget"
else
  xcrun lipo -create "${widget_binaries[@]}" -output "$WIDGET/Contents/MacOS/TC001BridgeWidget"
fi
chmod +x "$WIDGET/Contents/MacOS/TC001BridgeWidget"

for architecture in "${architectures[@]}"; do
  widget_executable="$WIDGET/Contents/MacOS/TC001BridgeWidget"
  text_vmaddr="$(
    otool -arch "$architecture" -l "$widget_executable" |
      awk '$1 == "segname" && $2 == "__TEXT" { in_text = 1; next }
           in_text && $1 == "vmaddr" { print $2; exit }'
  )"
  entryoff="$(
    otool -arch "$architecture" -l "$widget_executable" |
      awk '$1 == "cmd" && $2 == "LC_MAIN" { in_main = 1; next }
           in_main && $1 == "entryoff" { print $2; exit }'
  )"
  extension_main_address="$(
    otool -arch "$architecture" -Iv "$widget_executable" |
      awk '$NF == "_NSExtensionMain" { print $1; exit }'
  )"
  expected_entryoff=$(( extension_main_address - text_vmaddr ))
  if (( entryoff != expected_entryoff )); then
    echo "Widget entry point is not NSExtensionMain for $architecture" >&2
    exit 1
  fi
done

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/WidgetExtension/Info.plist" "$WIDGET/Contents/Info.plist"
cp "$ROOT/Assets/AppIcon.icns" "$WIDGET/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
plutil -lint "$WIDGET/Contents/Info.plist"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
sign_arguments=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  sign_arguments+=(--options runtime --timestamp)
fi
codesign "${sign_arguments[@]}" "$APP/Contents/Helpers/TC001UpdateHelper"
codesign \
  "${sign_arguments[@]}" \
  --entitlements "$ROOT/WidgetExtension/Widget.entitlements" \
  "$WIDGET"
codesign "${sign_arguments[@]}" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(
  cd "$DIST_DIR"
  shasum -a 256 "${ZIP:t}" > "${ZIP:t}.sha256"
)

echo "$APP"
echo "$ZIP"
echo "$ZIP.sha256"
