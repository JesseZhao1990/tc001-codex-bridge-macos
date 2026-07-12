# Privacy

TC001 Codex Bridge is local-first and has no project-operated backend,
analytics, advertising, or telemetry.

## Data read by the app

- Recent files under `~/.codex/sessions` are inspected to derive model activity
  and status. The app does not copy complete session files elsewhere.
- Local Codex desktop IPC status is observed when available so approval and
  waiting states can be detected.
- The locally installed Codex executable is launched as `app-server --stdio`
  to request account rate-limit windows using the user's existing Codex sign-in.
- The TC001 address, transport selection, display mode, and page toggles are
  stored in macOS `UserDefaults` for this application.

## Data sent by the app

- A rendered 32 x 8 pixel frame and page-setting bit mask are sent directly to
  the selected TC001 over the local network or Bluetooth.
- The application does not send Codex prompt or response text to the TC001.
- The application does not send data to a project-owned server.

Codex itself may communicate with OpenAI while the local executable is running,
according to the Codex product's own behavior and privacy terms. That traffic
is not proxied through this project.

## Local HTTP bridge

The optional bridge binds to `127.0.0.1:8765`. Request bodies are handled in
memory and are not logged or retained. Browser-origin requests are rejected.

Do not attach Codex session files, complete device flash dumps, or diagnostic
logs containing account or device information to public issues.
