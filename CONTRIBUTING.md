# Contributing

## Development setup

1. Use macOS 13 or later with the Xcode command-line tools installed.
2. Run `./run-tests.sh`.
3. Run `./build.sh` and open `dist/TC001 Bridge.app`.
4. Test Wi-Fi changes against normal AWTRIX 3 and BLE changes against the
   companion `awtrix3-ble` firmware.

## Pull requests

- Keep device transport, Codex provider, rendering, and UI changes separated
  where practical.
- Add focused tests for protocol, quota parsing, state arbitration, or matrix
  rendering changes.
- Do not commit `.codex` data, device flash dumps, Wi-Fi credentials, signing
  certificates, build outputs, or personal network addresses.
- Document changes to the BLE wire format in both companion repositories.

By contributing, you agree that your contribution is licensed under the MIT
License in this repository.
