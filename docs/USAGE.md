# TC001 Codex Bridge usage guide

## Install from source

1. Use macOS 13 or later and install the Xcode command-line tools.
2. Clone this repository.
3. Run the tests and build the application:

   ```bash
   ./run-tests.sh
   ./build.sh
   ```

4. Open `dist/TC001 Bridge.app`.
5. Grant Bluetooth and local-network permissions when macOS asks.

The default development build is ad-hoc signed. Public downloads should use a
Developer ID signature and Apple notarization.

## Connect a TC001

1. Open the settings window.
2. Choose `Automatic`, `Wi-Fi`, or `Bluetooth`.
3. For Wi-Fi, enter the TC001 IP address or `awtrix.local` and test the
   connection.
4. For Bluetooth, install the companion `awtrix3-ble` firmware first. Keep the
   TC001 nearby and accept the macOS pairing request.
5. Automatic mode tries Wi-Fi and falls back to BLE.

## Codex quota and status

- `5H` quota is shown for 7 seconds and `7D` quota for 3 seconds.
- The left 1 x 8 bar is the five-hour remaining quota.
- The right 1 x 8 bar is the seven-day remaining quota.
- Yellow means idle, green means working, blue means waiting for confirmation,
  and red means an error.
- Automatic monitoring reads local Codex state. Manual mode accepts a quota
  value through the loopback API.

## Built-in AWTRIX pages

The time, date, temperature, humidity, and battery switches can be changed in
the app. Wi-Fi mode applies normal AWTRIX settings and may reboot the device.
BLE mode applies the five flags immediately without a reboot.

## Troubleshooting

- No BLE device: confirm firmware `0.98-ble.4`, enable Bluetooth permission,
  move the Mac closer, and remove an obsolete pairing before retrying.
- No Wi-Fi connection: verify the address from the AWTRIX web interface and
  confirm the Mac and TC001 are on the same reachable network.
- No quota: confirm Codex desktop or CLI is installed and signed in, then wait
  for the next refresh.
- Wrong status: leave automatic monitoring enabled and make sure only one copy
  of TC001 Bridge is running.

## Privacy and security

The app has no project-operated server or telemetry. It reads local Codex state
and sends only rendered pixels and page flags to the selected TC001. The local
bridge binds to `127.0.0.1` and rejects browser-origin requests. See
[PRIVACY.md](../PRIVACY.md) and [SECURITY.md](../SECURITY.md).
