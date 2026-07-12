# Release guide

## 1. Verify source

```bash
./run-tests.sh
git status --short
```

Run a secret scan and confirm that no device backup, `.codex` data, personal IP
address, signing material, or build output is tracked.

## 2. Build a universal application

```bash
ARCHS="arm64 x86_64" \
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./build.sh
```

Verify both architectures and the signature:

```bash
lipo -archs "dist/TC001 Bridge.app/Contents/MacOS/TC001Bridge"
codesign --verify --deep --strict --verbose=2 "dist/TC001 Bridge.app"
```

## 3. Notarize

Store Apple credentials in a Keychain profile, then submit the ZIP:

```bash
xcrun notarytool submit dist/TC001-Bridge-macOS.zip \
  --keychain-profile TC001_NOTARY --wait
xcrun stapler staple "dist/TC001 Bridge.app"
```

Rebuild the ZIP after stapling, regenerate its SHA-256 checksum, and verify the
final artifact on a Mac that does not have the development build installed.

## 4. Publish

- Tag the exact tested commit.
- Attach the notarized ZIP and matching `.sha256` file.
- Include the changelog, minimum macOS version, supported firmware version, and
  any known security limitations in the release notes.
