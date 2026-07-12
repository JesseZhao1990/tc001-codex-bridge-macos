import Darwin
import Foundation

struct CodexDesktopActivitySignal: Equatable, Sendable {
    let isWaiting: Bool
    let conversationID: String?
    let updatedAt: Date
}

struct CodexDesktopThreadStatusUpdate: Equatable, Sendable {
    let conversationID: String
    let isWaiting: Bool
}

enum CodexDesktopIPCMessageInterpreter {
    static func statusUpdate(from message: [String: Any]) -> CodexDesktopThreadStatusUpdate? {
        let method = message["method"] as? String
        let params = message["params"] as? [String: Any] ?? message
        guard let conversationID = conversationID(in: params) else { return nil }

        if let runtimeStatus = runtimeStatus(in: params) {
            let type = runtimeStatus["type"] as? String
            let flags = runtimeStatus["activeFlags"] as? [String] ?? []
            let isWaiting = type == "active"
                && (flags.contains("waitingOnApproval") || flags.contains("waitingOnUserInput"))
            return CodexDesktopThreadStatusUpdate(
                conversationID: conversationID,
                isWaiting: isWaiting
            )
        }

        if let method,
           method.contains("requestApproval") || method.contains("requestUserInput") {
            return CodexDesktopThreadStatusUpdate(
                conversationID: conversationID,
                isWaiting: true
            )
        }
        return nil
    }

    private static func runtimeStatus(in value: Any) -> [String: Any]? {
        if let object = value as? [String: Any] {
            if let status = object["threadRuntimeStatus"] as? [String: Any] {
                return status
            }
            if pathReferencesRuntimeStatus(object["path"]) {
                if let status = object["value"] as? [String: Any] {
                    return status
                }
                if pathReferencesActiveFlags(object["path"]),
                   let flags = object["value"] as? [String] {
                    return ["type": "active", "activeFlags": flags]
                }
            }
            if let status = object["status"] as? [String: Any],
               status["type"] is String,
               status["activeFlags"] != nil {
                return status
            }
            if object["type"] is String, object["activeFlags"] != nil {
                return object
            }
            for nested in object.values {
                if let status = runtimeStatus(in: nested) { return status }
            }
        } else if let array = value as? [Any] {
            for nested in array {
                if let status = runtimeStatus(in: nested) { return status }
            }
        }
        return nil
    }

    private static func pathReferencesRuntimeStatus(_ value: Any?) -> Bool {
        if let path = value as? String {
            return path.contains("threadRuntimeStatus")
        }
        if let path = value as? [String] {
            return path.contains("threadRuntimeStatus")
        }
        return false
    }

    private static func pathReferencesActiveFlags(_ value: Any?) -> Bool {
        if let path = value as? String {
            return path.contains("activeFlags")
        }
        if let path = value as? [String] {
            return path.contains("activeFlags")
        }
        return false
    }

    private static func conversationID(in value: Any) -> String? {
        if let object = value as? [String: Any] {
            for key in ["conversationId", "threadId", "conversation_id", "thread_id"] {
                if let value = object[key] as? String, !value.isEmpty { return value }
            }
            for nested in object.values {
                if let value = conversationID(in: nested) { return value }
            }
        } else if let array = value as? [Any] {
            for nested in array {
                if let value = conversationID(in: nested) { return value }
            }
        }
        return nil
    }
}

struct CodexDesktopIPCFrameDecoder {
    private var buffer = Data()

    mutating func append(_ data: Data) -> [[String: Any]] {
        buffer.append(data)
        var messages: [[String: Any]] = []

        while buffer.count >= 4 {
            let header = Array(buffer.prefix(4))
            let length = Int(header[0])
                | (Int(header[1]) << 8)
                | (Int(header[2]) << 16)
                | (Int(header[3]) << 24)
            // Codex snapshots include loaded turn history and can exceed 10 MB.
            // Match the desktop router's 256 MB frame ceiling.
            guard length <= 256 * 1024 * 1024 else {
                buffer.removeAll(keepingCapacity: true)
                break
            }
            guard buffer.count >= 4 + length else { break }

            let payloadStart = buffer.index(buffer.startIndex, offsetBy: 4)
            let payloadEnd = buffer.index(payloadStart, offsetBy: length)
            let payload = buffer.subdata(in: payloadStart..<payloadEnd)
            buffer = buffer.subdata(in: payloadEnd..<buffer.endIndex)

            if let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] {
                messages.append(object)
            }
        }
        return messages
    }
}

final class CodexDesktopIPCMonitor: @unchecked Sendable {
    private let socketPath: String
    private let queue = DispatchQueue(label: "local.tc001.bridge.codex-ipc", qos: .utility)
    private let lock = NSLock()
    private var running = true
    private var activeSocket: Int32 = -1
    private var waitingThreads: [String: Date] = [:]
    private var lastStatusAt: Date?

    init(socketPath: String? = nil, startsAutomatically: Bool = true) {
        self.socketPath = socketPath ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("codex-ipc", isDirectory: true)
            .appendingPathComponent("ipc-\(getuid()).sock")
            .path

        if startsAutomatically {
            queue.async { [weak self] in
                self?.listenLoop()
            }
        }
    }

    func activitySignal(now: Date = Date()) -> CodexDesktopActivitySignal? {
        lock.lock()
        defer { lock.unlock() }

        let maximumAge: TimeInterval = 6 * 60 * 60
        waitingThreads = waitingThreads.filter { now.timeIntervalSince($0.value) <= maximumAge }
        guard let lastStatusAt, now.timeIntervalSince(lastStatusAt) <= maximumAge else { return nil }
        let newestWaiting = waitingThreads.max { $0.value < $1.value }
        return CodexDesktopActivitySignal(
            isWaiting: newestWaiting != nil,
            conversationID: newestWaiting?.key,
            updatedAt: lastStatusAt
        )
    }

    func stop() {
        lock.lock()
        running = false
        let socket = activeSocket
        activeSocket = -1
        lock.unlock()
        if socket >= 0 {
            Darwin.shutdown(socket, SHUT_RDWR)
        }
    }

    private func listenLoop() {
        while shouldContinue {
            guard let socket = connectSocket() else {
                Thread.sleep(forTimeInterval: 1.5)
                continue
            }
            setActiveSocket(socket)
            if sendInitialize(to: socket) {
                readMessages(from: socket)
            }
            Darwin.close(socket)
            clearActiveSocket(socket)
            markDisconnected()
            if shouldContinue {
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }

    private var shouldContinue: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    private func connectSocket() -> Int32? {
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return nil }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let maximumPathLength = MemoryLayout.size(ofValue: address.sun_path)
        guard socketPath.utf8.count < maximumPathLength else {
            Darwin.close(socket)
            return nil
        }

        _ = withUnsafeMutableBytes(of: &address.sun_path) { destination in
            socketPath.withCString { source in
                strncpy(
                    destination.baseAddress!.assumingMemoryBound(to: CChar.self),
                    source,
                    destination.count - 1
                )
            }
        }

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(socket)
            return nil
        }
        return socket
    }

    private func sendInitialize(to socket: Int32) -> Bool {
        let message: [String: Any] = [
            "type": "request",
            "requestId": UUID().uuidString,
            "sourceClientId": "initializing-client",
            "version": 0,
            "method": "initialize",
            "params": ["clientType": "tc001-bridge"],
            "timeoutMs": 5_000
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: message) else { return false }
        let size = UInt32(payload.count)
        var frame = Data([
            UInt8(size & 0xff),
            UInt8((size >> 8) & 0xff),
            UInt8((size >> 16) & 0xff),
            UInt8((size >> 24) & 0xff)
        ])
        frame.append(payload)

        return frame.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            var written = 0
            while written < buffer.count {
                let count = Darwin.write(
                    socket,
                    baseAddress.advanced(by: written),
                    buffer.count - written
                )
                guard count > 0 else { return false }
                written += count
            }
            return true
        }
    }

    private func readMessages(from socket: Int32) {
        var decoder = CodexDesktopIPCFrameDecoder()
        var bytes = [UInt8](repeating: 0, count: 64 * 1024)

        while shouldContinue {
            let count = bytes.withUnsafeMutableBytes { buffer in
                Darwin.read(socket, buffer.baseAddress, buffer.count)
            }
            guard count > 0 else { return }
            let data = Data(bytes.prefix(count))
            for message in decoder.append(data) {
                guard let update = CodexDesktopIPCMessageInterpreter.statusUpdate(from: message) else {
                    continue
                }
                ingest(update, at: Date())
            }
        }
    }

    private func ingest(_ update: CodexDesktopThreadStatusUpdate, at date: Date) {
        lock.lock()
        if update.isWaiting {
            waitingThreads[update.conversationID] = date
        } else {
            waitingThreads.removeValue(forKey: update.conversationID)
        }
        lastStatusAt = date
        lock.unlock()
    }

    private func markDisconnected() {
        lock.lock()
        if !waitingThreads.isEmpty {
            waitingThreads.removeAll()
            lastStatusAt = Date()
        }
        lock.unlock()
    }

    private func setActiveSocket(_ socket: Int32) {
        lock.lock()
        activeSocket = socket
        lock.unlock()
    }

    private func clearActiveSocket(_ socket: Int32) {
        lock.lock()
        if activeSocket == socket { activeSocket = -1 }
        lock.unlock()
    }
}
