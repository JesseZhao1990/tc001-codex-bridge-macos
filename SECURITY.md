# Security policy

## Supported version

Only the latest release and the current `main` branch are supported.

## Reporting a vulnerability

Use GitHub private vulnerability reporting after publication. Do not open a
public issue containing credentials, Codex session data, BLE bond information,
device identifiers, or a TC001 full-flash backup.

## Security boundaries

- The local bridge listens only on loopback. It has no authentication for
  native local processes, but rejects requests carrying a browser `Origin`
  header and does not enable CORS.
- AWTRIX HTTP traffic is unencrypted on the local network. Use BLE or a trusted
  LAN when the displayed data or device control is sensitive.
- The companion firmware currently uses encrypted BLE "Just Works" pairing.
  It does not provide passkey-based MITM protection or physical confirmation.
- Ad-hoc application signatures are intended for local development only.
  Public binaries should use Developer ID signing, hardened runtime, and Apple
  notarization.
- The updater accepts archives only from this repository's GitHub Releases,
  verifies the release SHA-256 digest, bundle identifier, version, and code
  signature, and does not remove macOS quarantine attributes or bypass
  Gatekeeper.

The app intentionally displays quota percentages and coarse activity state; it
does not need prompt or response text. Changes that transmit content should be
treated as a separate privacy and security design decision.
