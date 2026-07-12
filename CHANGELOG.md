# Changelog

## 1.7.2

- Fixed in-app updates hanging because the open update sheet blocked application termination.
- Dismissed attached sheets before requesting a graceful restart.
- Added a forced-exit fallback so the update helper cannot wait indefinitely.

## 1.7.1

- Fixed status-lamp test buttons being overwritten by background synchronization.
- Kept test states visible for four seconds after confirmed delivery to TC001.
- Added animated waiting and error previews through the normal display queue.

## 1.7.0

- Added a clickable version row and native update panel.
- Added user-selectable automatic and manual update modes.
- Added GitHub Release discovery with semantic-version selection.
- Added SHA-256, bundle identifier, version, and code-signature verification before installation.
- Added a bundled helper that safely replaces and relaunches the application with rollback on replacement failure.

## 1.6.1

- Fixed Codex Desktop IPC activity mapping so active tasks show as working even when session logs are unavailable.
- Added idle, waiting, error, and multi-thread activity aggregation for Codex Desktop.
- Added quota discovery for the Codex executable bundled inside `ChatGPT.app`.

## 1.6.0

- Added Wi-Fi, BLE, and automatic transport modes.
- Added five-hour and seven-day Codex quota display scheduling.
- Added yellow idle, green working, blue waiting, and red error lamp states.
- Added local Codex desktop approval/waiting-state detection.
- Added BLE control for time, date, temperature, humidity, and battery pages.
- Added a native SwiftUI settings window and application icon.
- Added browser-origin rejection to the loopback bridge for public release.
