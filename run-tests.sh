#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tc001-bridge-tests.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/Core/AIEvent.swift" \
  "$ROOT/Sources/Core/ActivityArbiter.swift" \
  "$ROOT/Tests/ActivityArbiterTests.swift" \
  -o "$BUILD_DIR/activity-arbiter-tests"
"$BUILD_DIR/activity-arbiter-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/Core/AIEvent.swift" \
  "$ROOT/Sources/Models.swift" \
  "$ROOT/Sources/CodexDesktopIPCMonitor.swift" \
  "$ROOT/Sources/CodexMonitor.swift" \
  "$ROOT/Tests/CodexMonitorTests.swift" \
  -framework SwiftUI \
  -o "$BUILD_DIR/codex-monitor-tests"
"$BUILD_DIR/codex-monitor-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/Core/AIEvent.swift" \
  "$ROOT/Sources/Providers/CodexRateLimitsClient.swift" \
  "$ROOT/Tests/CodexRateLimitsClientTests.swift" \
  -o "$BUILD_DIR/codex-rate-limits-client-tests"
"$BUILD_DIR/codex-rate-limits-client-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/Core/AIEvent.swift" \
  "$ROOT/Sources/Models.swift" \
  "$ROOT/Tests/LampTestSessionTests.swift" \
  -framework SwiftUI \
  -o "$BUILD_DIR/lamp-test-session-tests"
"$BUILD_DIR/lamp-test-session-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/UpdateCore.swift" \
  "$ROOT/Tests/UpdateCoreTests.swift" \
  -o "$BUILD_DIR/update-core-tests"
"$BUILD_DIR/update-core-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/UpdaterHelper/TC001UpdateHelper.swift" \
  -framework Foundation \
  -o "$BUILD_DIR/tc001-update-helper"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Tests/UpdaterHelperIntegrationTests.swift" \
  -framework Foundation \
  -o "$BUILD_DIR/updater-helper-tests"
"$BUILD_DIR/updater-helper-tests" "$BUILD_DIR/tc001-update-helper"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/UpdateRelaunchCoordinator.swift" \
  "$ROOT/Tests/UpdateRelaunchCoordinatorTests.swift" \
  -framework AppKit \
  -o "$BUILD_DIR/update-relaunch-coordinator-tests"
"$BUILD_DIR/update-relaunch-coordinator-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/UpdateCore.swift" \
  "$ROOT/Sources/UpdateRelaunchCoordinator.swift" \
  "$ROOT/Sources/AppUpdateManager.swift" \
  "$ROOT/Tests/AppUpdateManagerTests.swift" \
  -framework AppKit \
  -framework Combine \
  -framework CryptoKit \
  -framework Foundation \
  -o "$BUILD_DIR/app-update-manager-tests"
"$BUILD_DIR/app-update-manager-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/Core/AIEvent.swift" \
  "$ROOT/Sources/Models.swift" \
  "$ROOT/Sources/AWTRIXClient.swift" \
  "$ROOT/Tests/AWTRIXRendererTests.swift" \
  -framework SwiftUI \
  -o "$BUILD_DIR/awtrix-renderer-tests"
"$BUILD_DIR/awtrix-renderer-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/BLEProtocol.swift" \
  "$ROOT/Tests/BLEProtocolTests.swift" \
  -o "$BUILD_DIR/ble-protocol-tests"
"$BUILD_DIR/ble-protocol-tests"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT/Sources/LocalBridgeServer.swift" \
  "$ROOT/Tests/LocalBridgeServerTests.swift" \
  -framework Network \
  -o "$BUILD_DIR/local-bridge-server-tests"
"$BUILD_DIR/local-bridge-server-tests"
