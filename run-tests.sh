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
