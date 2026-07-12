# Local bridge API

The optional bridge listens on `127.0.0.1:8765`. It is intended for native local
scripts and integrations. Browser-origin requests and CORS preflights are
rejected.

## Health

```text
GET /health
```

## Activity

```text
POST /model/start
POST /model/end
POST /model/error
POST /refresh
```

`/model/start` increments the external active-request count. `/model/end`
decrements it. Integrations should balance the two calls. `/model/error` clears
the count and displays an error state temporarily.

## Manual quota

```text
POST /tokens
Content-Type: application/json

{"percent": 73}
```

`percent` must be an integer from 0 through 100. Select the manual/bridge quota
mode in the application before relying on this value.

## Example

```bash
curl -X POST http://127.0.0.1:8765/model/start
curl -X POST http://127.0.0.1:8765/tokens \
  -H 'Content-Type: application/json' \
  -d '{"percent":73}'
curl -X POST http://127.0.0.1:8765/model/end
```
