import Foundation

@main
struct CodexMonitorTests {
    static func main() throws {
        try approvalLifecycleIsTracked()
        try desktopIPCFramesAndWaitingFlagsAreParsed()
        print("CodexMonitorTests: PASS")
    }

    private static func approvalLifecycleIsTracked() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let day = root
            .appendingPathComponent(String(format: "%04d", components.year!), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", components.month!), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", components.day!), isDirectory: true)
        try fileManager.createDirectory(at: day, withIntermediateDirectories: true)
        let session = day.appendingPathComponent("rollout-test.jsonl")

        let started = [
            #"{"type":"turn_context","payload":{"model":"gpt-test"}}"#,
            #"{"type":"event_msg","payload":{"type":"task_started","model_context_window":1000}}"#,
            #"{"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":100},"model_context_window":1000}}}"#
        ].joined(separator: "\n") + "\n"
        try started.write(to: session, atomically: true, encoding: .utf8)

        let monitor = CodexMonitor(rootURL: root, desktopMonitor: nil)
        let first = try require(monitor.snapshot(), "missing first snapshot")
        try check(first.activity == .working, "expected working")
        try check(first.contextRemainingPercent == 90, "expected 90 percent context remaining")
        try check(first.model == "gpt-test", "expected model")

        let approval = started
            + #"{"type":"event_msg","payload":{"type":"exec_approval_request","call_id":"call-1"}}"#
            + "\n"
        try approval.write(to: session, atomically: true, encoding: .utf8)
        let second = try require(monitor.snapshot(), "missing second snapshot")
        try check(second.activity == .waiting, "an explicit approval request should wait")

        let approved = approval
            + #"{"type":"event_msg","payload":{"type":"exec_approval_response","call_id":"call-1"}}"#
            + "\n"
        try approved.write(to: session, atomically: true, encoding: .utf8)
        let third = try require(monitor.snapshot(), "missing third snapshot")
        try check(third.activity == .working, "approval response should resume work")

        let escalatedCall = approved
            + #"{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"whoami\",\"sandbox_permissions\":\"require_escalated\"}","call_id":"call-2"}}"#
            + "\n"
        try escalatedCall.write(to: session, atomically: true, encoding: .utf8)
        let fourth = try require(monitor.snapshot(), "missing fourth snapshot")
        try check(fourth.activity == .waiting, "require_escalated should wait")

        let callOutput = escalatedCall
            + #"{"type":"response_item","payload":{"type":"function_call_output","call_id":"call-2","output":"ok"}}"#
            + "\n"
        try callOutput.write(to: session, atomically: true, encoding: .utf8)
        let fifth = try require(monitor.snapshot(), "missing fifth snapshot")
        try check(fifth.activity == .working, "matching function output should resume work")

        let userInput = callOutput
            + #"{"type":"response_item","payload":{"type":"function_call","name":"request_user_input","arguments":"{}","call_id":"call-3"}}"#
            + "\n"
        try userInput.write(to: session, atomically: true, encoding: .utf8)
        let sixth = try require(monitor.snapshot(), "missing sixth snapshot")
        try check(sixth.activity == .waiting, "request_user_input should wait")

        let completed = userInput
            + #"{"type":"event_msg","payload":{"type":"task_complete"}}"#
            + "\n"
        try completed.write(to: session, atomically: true, encoding: .utf8)
        let seventh = try require(monitor.snapshot(), "missing seventh snapshot")
        try check(seventh.activity == .idle, "task completion should clear pending requests")
    }

    private static func desktopIPCFramesAndWaitingFlagsAreParsed() throws {
        let waitingMessage: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "thread-stream-state-changed",
            "params": [
                "conversationId": "thread-1",
                "change": [
                    "threadSummary": [
                        "threadRuntimeStatus": [
                            "type": "active",
                            "activeFlags": ["waitingOnApproval"]
                        ]
                    ]
                ]
            ]
        ]
        let update = try require(
            CodexDesktopIPCMessageInterpreter.statusUpdate(from: waitingMessage),
            "missing IPC waiting update"
        )
        try check(update.conversationID == "thread-1", "IPC conversation id should be retained")
        try check(update.isWaiting, "waitingOnApproval should enter waiting")

        let activeMessage: [String: Any] = [
            "method": "thread/status/changed",
            "params": [
                "threadId": "thread-1",
                "status": ["type": "active", "activeFlags": []]
            ]
        ]
        let active = try require(
            CodexDesktopIPCMessageInterpreter.statusUpdate(from: activeMessage),
            "missing IPC active update"
        )
        try check(!active.isWaiting, "empty active flags should clear waiting")

        let payload = try JSONSerialization.data(withJSONObject: waitingMessage)
        let size = UInt32(payload.count)
        let header = Data([
            UInt8(size & 0xff),
            UInt8((size >> 8) & 0xff),
            UInt8((size >> 16) & 0xff),
            UInt8((size >> 24) & 0xff)
        ])
        let frame = header + payload
        var decoder = CodexDesktopIPCFrameDecoder()
        try check(decoder.append(frame.prefix(2)).isEmpty, "partial IPC header should be buffered")
        let decoded = decoder.append(frame.dropFirst(2))
        try check(decoded.count == 1, "one length-prefixed IPC message should decode")
        try check(decoded[0]["method"] as? String == "thread-stream-state-changed", "decoded IPC method mismatch")
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw TestFailure(message) }
        return value
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
