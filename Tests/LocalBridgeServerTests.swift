import Foundation

@main
struct LocalBridgeServerTests {
    static func main() throws {
        let port = UInt16(20_000 + Int(ProcessInfo.processInfo.processIdentifier) % 20_000)
        let ready = DispatchSemaphore(value: 0)
        let commandReceived = DispatchSemaphore(value: 0)
        let tokenReceived = DispatchSemaphore(value: 0)

        let server = LocalBridgeServer(
            port: port,
            onCommand: { command in
                if case .modelStart = command {
                    commandReceived.signal()
                }
                if case let .tokens(percent) = command, percent == 73 {
                    tokenReceived.signal()
                }
            },
            onState: { isReady, error in
                if let error {
                    fputs("Local bridge failed: \(error)\n", stderr)
                }
                if isReady {
                    ready.signal()
                }
            }
        )
        server.start()
        defer { server.stop() }

        try check(
            ready.wait(timeout: .now() + 3) == .success,
            "local bridge should start"
        )

        let health = try request(port: port, method: "GET", path: "/health")
        try check(health.status == 200, "health endpoint should accept a native client")

        let blocked = try request(
            port: port,
            method: "GET",
            path: "/health",
            headers: ["Origin": "https://example.invalid"]
        )
        try check(
            blocked.status == 403,
            "browser-origin requests should be rejected, got \(blocked.status)"
        )

        let start = try request(port: port, method: "POST", path: "/model/start")
        try check(start.status == 200, "model start should succeed")
        try check(
            commandReceived.wait(timeout: .now() + 2) == .success,
            "model start should reach the command handler"
        )

        let tokens = try request(
            port: port,
            method: "POST",
            path: "/tokens",
            headers: ["Content-Type": "application/json"],
            body: #"{"percent":73}"#
        )
        try check(tokens.status == 200, "token update should accept a JSON body")
        try check(
            tokenReceived.wait(timeout: .now() + 2) == .success,
            "token update should reach the command handler"
        )

        print("LocalBridgeServerTests: PASS")
    }

    private static func request(
        port: UInt16,
        method: String,
        path: String,
        headers: [String: String] = [:],
        body: String? = nil
    ) throws -> (status: Int, body: Data) {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        var arguments = [
            "--silent",
            "--show-error",
            "--max-time", "3",
            "--output", "/dev/null",
            "--write-out", "%{http_code}",
            "--request", method
        ]
        for (name, value) in headers {
            arguments.append(contentsOf: ["--header", "\(name): \(value)"])
        }
        if let body {
            arguments.append(contentsOf: ["--data", body])
        }
        arguments.append("http://127.0.0.1:\(port)\(path)")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(
                decoding: errors.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            )
            throw TestFailure("curl failed: \(message)")
        }
        let statusText = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        guard let responseStatus = Int(statusText) else {
            throw TestFailure("response did not include an HTTP status")
        }
        return (responseStatus, Data())
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
