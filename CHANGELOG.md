# Changelog

## 1.9.0

- Added live five-hour and seven-day quota text to the macOS menu bar.
- Added a polished, draggable desktop status card for quota, model activity,
  model source, device connection, battery, and last-sync state.
- Added persistent controls for menu-bar quota text, desktop-card visibility,
  and always-on-top behavior.
- Kept the TC001 display, menu popover, menu-bar title, settings summary, and
  desktop card synchronized with the same quota visibility switches.

## 1.8.0

- Added independent five-hour and seven-day quota display switches.
- Added persistent five-hour-only, seven-day-only, and combined display modes.
- Stopped page rotation when only one quota is enabled.
- Hid disabled quota rails and kept enabled quota positions consistent across Wi-Fi and BLE.
- Updated the menu bar and model-status summaries to follow the selected quotas.

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
