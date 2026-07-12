import Foundation
import Network

enum LocalBridgeCommand {
    case modelStart
    case modelEnd
    case modelError
    case tokens(Int)
    case refresh
}

final class LocalBridgeServer {
    typealias CommandHandler = (LocalBridgeCommand) -> Void
    typealias StateHandler = (Bool, String?) -> Void

    private let portNumber: UInt16
    private let queue = DispatchQueue(label: "com.tc001bridge.http")
    private let onCommand: CommandHandler
    private let onState: StateHandler
    private var listener: NWListener?

    init(port: UInt16 = 8765, onCommand: @escaping CommandHandler, onState: @escaping StateHandler) {
        self.portNumber = port
        self.onCommand = onCommand
        self.onState = onState
    }

    func start() {
        guard listener == nil, let port = NWEndpoint.Port(rawValue: portNumber) else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host("127.0.0.1"), port: port)
            let listener = try NWListener(using: parameters)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.onState(true, nil)
                case let .failed(error):
                    self.onState(false, error.localizedDescription)
                    listener.cancel()
                    self.listener = nil
                case .cancelled:
                    self.onState(false, nil)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                HTTPConnection(connection: connection, onCommand: self.onCommand).start(on: self.queue)
            }
            listener.start(queue: queue)
        } catch {
            onState(false, error.localizedDescription)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}

private final class HTTPConnection {
    private let connection: NWConnection
    private let onCommand: (LocalBridgeCommand) -> Void
    private var received = Data()

    init(connection: NWConnection, onCommand: @escaping (LocalBridgeCommand) -> Void) {
        self.connection = connection
        self.onCommand = onCommand
    }

    func start(on queue: DispatchQueue) {
        connection.start(queue: queue)
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [self] data, _, complete, error in
            if let data { self.received.append(data) }

            if self.requestIsComplete() {
                self.handleRequest()
            } else if complete || error != nil || self.received.count > 128 * 1024 {
                self.respond(status: 400, json: ["ok": false, "error": "bad request"])
            } else {
                self.receive()
            }
        }
    }

    private func requestIsComplete() -> Bool {
        guard let delimiter = received.range(of: Data("\r\n\r\n".utf8)) else { return false }
        let headerData = received[..<delimiter.lowerBound]
        let headers = String(decoding: headerData, as: UTF8.self)
        let contentLength = headers
            .components(separatedBy: "\r\n")
            .first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") }
            ?? 0
        let bodyStart = delimiter.upperBound
        return received.count >= bodyStart + contentLength
    }

    private func handleRequest() {
        guard let delimiter = received.range(of: Data("\r\n\r\n".utf8)) else {
            respond(status: 400, json: ["ok": false])
            return
        }

        let headerText = String(decoding: received[..<delimiter.lowerBound], as: UTF8.self)
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            respond(status: 400, json: ["ok": false])
            return
        }
        let parts = requestLine.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard parts.count >= 2 else {
            respond(status: 400, json: ["ok": false])
            return
        }

        let method = String(parts[0])
        let path = String(parts[1]).split(separator: "?").first.map(String.init) ?? "/"
        let body = received[delimiter.upperBound...]

        // Native local clients do not send Origin. Reject browser-initiated
        // requests so an unrelated website cannot control the display.
        let hasBrowserOrigin = lines.dropFirst().contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .hasPrefix("origin:")
        }
        if hasBrowserOrigin {
            respond(status: 403, json: ["ok": false, "error": "browser origins are not allowed"])
            return
        }
        if method == "OPTIONS" {
            respond(status: 403, json: ["ok": false, "error": "browser origins are not allowed"])
            return
        }
        if method == "GET", path == "/health" {
            respond(status: 200, json: ["ok": true, "service": "TC001 Bridge"])
            return
        }
        guard method == "POST" else {
            respond(status: 405, json: ["ok": false, "error": "method not allowed"])
            return
        }

        switch path {
        case "/model/start":
            onCommand(.modelStart)
        case "/model/end":
            onCommand(.modelEnd)
        case "/model/error":
            onCommand(.modelError)
        case "/refresh":
            onCommand(.refresh)
        case "/tokens":
            guard let object = try? JSONSerialization.jsonObject(with: Data(body)) as? [String: Any],
                  let number = object["percent"] as? NSNumber,
                  (0...100).contains(number.intValue) else {
                respond(status: 422, json: ["ok": false, "error": "percent must be 0...100"])
                return
            }
            onCommand(.tokens(number.intValue))
        default:
            respond(status: 404, json: ["ok": false, "error": "not found"])
            return
        }

        respond(status: 200, json: ["ok": true])
    }

    private func respond(status: Int, json: [String: Any]?) {
        let body = json.flatMap { try? JSONSerialization.data(withJSONObject: $0) } ?? Data()
        let reason: String
        switch status {
        case 200: reason = "OK"
        case 204: reason = "No Content"
        case 400: reason = "Bad Request"
        case 403: reason = "Forbidden"
        case 404: reason = "Not Found"
        case 405: reason = "Method Not Allowed"
        case 422: reason = "Unprocessable Entity"
        default: reason = "Error"
        }
        let headers = "HTTP/1.1 \(status) \(reason)\r\n" +
            "Content-Type: application/json; charset=utf-8\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "Cache-Control: no-store\r\n" +
            "Connection: close\r\n\r\n"
        var response = Data(headers.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            self?.connection.cancel()
        })
    }
}
