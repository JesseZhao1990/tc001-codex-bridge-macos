# Architecture

```mermaid
flowchart LR
    S["Codex session files"] --> P["Codex provider"]
    I["Codex desktop IPC"] --> P
    C["Local Codex app-server"] --> P
    H["Loopback bridge"] --> A["Activity arbiter"]
    P --> A
    A --> R["32 x 8 frame renderer"]
    R --> W["AWTRIX HTTP client"]
    R --> B["AWTRIX BLE client"]
    W --> T["TC001"]
    B --> T
    U["SwiftUI settings"] --> W
    U --> B
```

## Ownership boundaries

- Providers convert source-specific events and rate limits into shared models.
- `ActivityArbiter` decides idle, working, waiting, and error precedence.
- `AWTRIXClient` owns rendering and the normal HTTP transport.
- `AWTRIXBLEClient` and `BLEProtocol` own GATT discovery and frame transfer.
- `BridgeStore` coordinates state, display timing, settings, and transport
  fallback for the SwiftUI views.

The firmware receives already-rendered pixels. It does not parse Codex data or
make network requests to OpenAI.
