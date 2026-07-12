import Foundation

protocol CodexRateLimitsFetching: Sendable {
    func fetch() throws -> AIQuota
}

enum CodexRateLimitsClientError: LocalizedError {
    case executableNotFound
    case requestTimedOut
    case invalidResponse
    case accountLimitMissing

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "未找到 Codex 可执行文件"
        case .requestTimedOut:
            return "读取 Codex 账户额度超时"
        case .invalidResponse:
            return "Codex 返回了无法识别的额度数据"
        case .accountLimitMissing:
            return "Codex 未返回账户级额度"
        }
    }
}

final class CodexRateLimitsClient: CodexRateLimitsFetching, @unchecked Sendable {
    private let executableURL: URL?
    private let timeout: TimeInterval

    init(executableURL: URL? = nil, timeout: TimeInterval = 8) {
        self.executableURL = executableURL ?? Self.findExecutable()
        self.timeout = timeout
    }

    func fetch() throws -> AIQuota {
        guard let executableURL else {
            throw CodexRateLimitsClientError.executableNotFound
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        try process.run()
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
        }

        try write(
            #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"tc001-bridge","title":"TC001 Bridge","version":"1.0"},"capabilities":{"experimentalApi":true}}}"#,
            to: input.fileHandleForWriting
        )
        _ = try readResponse(id: 1, from: output.fileHandleForReading)

        try write(#"{"method":"initialized"}"#, to: input.fileHandleForWriting)
        try write(
            #"{"method":"account/read","id":2,"params":{"refreshToken":false}}"#,
            to: input.fileHandleForWriting
        )
        _ = try readResponse(id: 2, from: output.fileHandleForReading)

        try write(
            #"{"method":"account/rateLimits/read","id":3,"params":null}"#,
            to: input.fileHandleForWriting
        )
        let line = try readResponse(id: 3, from: output.fileHandleForReading)
        return try Self.decodeQuota(from: line)
    }

    private func write(_ message: String, to handle: FileHandle) throws {
        try handle.write(contentsOf: Data((message + "\n").utf8))
    }

    private func readResponse(id: Int, from handle: FileHandle) throws -> Data {
        let response = LockedResponse()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            var buffer = Data()
            while true {
                let chunk = handle.availableData
                guard !chunk.isEmpty else { break }
                buffer.append(chunk)

                while let newline = buffer.firstRange(of: Data([0x0A])) {
                    let line = Data(buffer[..<newline.lowerBound])
                    buffer.removeSubrange(..<newline.upperBound)
                    if Self.isResponse(line, id: id) {
                        response.set(line)
                        readGroup.leave()
                        return
                    }
                }
            }
            readGroup.leave()
        }

        guard readGroup.wait(timeout: .now() + timeout) == .success else {
            throw CodexRateLimitsClientError.requestTimedOut
        }
        guard let line = response.get() else {
            throw CodexRateLimitsClientError.invalidResponse
        }
        return line
    }

    static func decodeQuota(from data: Data) throws -> AIQuota {
        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard envelope.id == 3, let result = envelope.result else {
            throw CodexRateLimitsClientError.invalidResponse
        }

        let snapshot = result.rateLimitsByLimitId?["codex"]
            ?? (result.rateLimits.limitId == "codex" ? result.rateLimits : nil)
        guard let snapshot else {
            throw CodexRateLimitsClientError.accountLimitMissing
        }

        let windows = [
            quotaWindow(id: "primary", from: snapshot.primary),
            quotaWindow(id: "secondary", from: snapshot.secondary)
        ].compactMap { $0 }
        guard !windows.isEmpty else {
            throw CodexRateLimitsClientError.accountLimitMissing
        }

        return AIQuota(
            limitID: snapshot.limitId,
            limitName: snapshot.limitName,
            windows: windows
        )
    }

    private static func quotaWindow(id: String, from window: RateLimitWindow?) -> AIQuotaWindow? {
        guard let window else { return nil }
        return AIQuotaWindow(
            id: id,
            windowMinutes: window.windowDurationMins,
            remainingPercent: 100 - window.usedPercent,
            resetsAt: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    private static func isResponse(_ data: Data, id expectedID: Int) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = object["id"] as? NSNumber else { return false }
        return id.intValue == expectedID
    }

    private static func findExecutable() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(home)/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/.local/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }
}

private final class LockedResponse: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    func set(_ data: Data) {
        lock.lock()
        self.data = data
        lock.unlock()
    }

    func get() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

private struct ResponseEnvelope: Decodable {
    let id: Int
    let result: RateLimitsResponse?
}

private struct RateLimitsResponse: Decodable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
}

private struct RateLimitSnapshot: Decodable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
}

private struct RateLimitWindow: Decodable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Int?
}
