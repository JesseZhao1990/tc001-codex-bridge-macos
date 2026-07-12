import Foundation

final class CodexMonitor: @unchecked Sendable {
    private let rootURL: URL
    private let fileManager: FileManager
    private let desktopMonitor: CodexDesktopIPCMonitor?
    private var currentSessionURL: URL?
    private var lastDiscoveryAt = Date.distantPast
    private var cachedFileSize: UInt64 = 0
    private var cachedModifiedAt = Date.distantPast
    private var cachedSnapshot: CodexSnapshot?

    init(
        rootURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true),
        fileManager: FileManager = .default,
        desktopMonitor: CodexDesktopIPCMonitor? = CodexDesktopIPCMonitor()
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.desktopMonitor = desktopMonitor
    }

    deinit {
        desktopMonitor?.stop()
    }

    func snapshot(now: Date = Date()) -> CodexSnapshot? {
        discoverNewestSessionIfNeeded(now: now)
        guard let sessionURL = currentSessionURL else {
            return desktopFallbackSnapshot(now: now)
        }

        guard let attributes = try? fileManager.attributesOfItem(atPath: sessionURL.path) else {
            currentSessionURL = nil
            return desktopFallbackSnapshot(now: now)
        }

        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let modifiedAt = attributes[.modificationDate] as? Date ?? .distantPast
        if fileSize == cachedFileSize, modifiedAt == cachedModifiedAt, var cachedSnapshot {
            if cachedSnapshot.activity == .working,
               now.timeIntervalSince(cachedSnapshot.updatedAt) > 30 * 60 {
                cachedSnapshot.activity = .idle
                self.cachedSnapshot = cachedSnapshot
            }
            return applyingDesktopSignal(to: cachedSnapshot, now: now)
        }

        let previous = cachedSnapshot
        guard let parsed = parseTail(
            of: sessionURL,
            modifiedAt: modifiedAt,
            previousActivity: previous?.activity
        ) else {
            return previous.map { applyingDesktopSignal(to: $0, now: now) }
        }

        cachedFileSize = fileSize
        cachedModifiedAt = modifiedAt
        cachedSnapshot = parsed
        return applyingDesktopSignal(to: parsed, now: now)
    }

    private func discoverNewestSessionIfNeeded(now: Date) {
        let discoveryInterval: TimeInterval = 2
        guard now.timeIntervalSince(lastDiscoveryAt) >= discoveryInterval || currentSessionURL == nil else { return }
        lastDiscoveryAt = now

        var candidates: [URL] = []
        let calendar = Calendar.current
        for dayOffset in 0...2 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year, let month = components.month, let day = components.day else { continue }
            let dayDirectory = rootURL
                .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", day), isDirectory: true)

            let files = (try? fileManager.contentsOfDirectory(
                at: dayDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            candidates.append(contentsOf: files.filter { $0.pathExtension == "jsonl" })
        }

        if let currentSessionURL, fileManager.fileExists(atPath: currentSessionURL.path) {
            candidates.append(currentSessionURL)
        }

        let newest = candidates.max { lhs, rhs in
            let left = ((try? fileManager.attributesOfItem(atPath: lhs.path))?[.modificationDate] as? Date) ?? .distantPast
            let right = ((try? fileManager.attributesOfItem(atPath: rhs.path))?[.modificationDate] as? Date) ?? .distantPast
            return left < right
        }

        guard newest != currentSessionURL else { return }
        currentSessionURL = newest
        cachedFileSize = 0
        cachedModifiedAt = .distantPast
        cachedSnapshot = nil
    }

    private func parseTail(
        of url: URL,
        modifiedAt: Date,
        previousActivity: ActivityState?
    ) -> CodexSnapshot? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let fileSize = handle.seekToEndOfFile()
        let maxTailBytes: UInt64 = 4 * 1024 * 1024
        let offset = fileSize > maxTailBytes ? fileSize - maxTailBytes : 0
        handle.seek(toFileOffset: offset)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return nil }

        let text = String(decoding: data, as: UTF8.self)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        if offset > 0, !lines.isEmpty {
            lines.removeFirst()
        }

        var activity = previousActivity ?? .idle
        var remainingPercent: Int?
        var usedTokens: Int?
        var contextWindow: Int?
        var model: String?
        var pendingApprovalCallIDs = Set<String>()
        var hasUnidentifiedApproval = false

        for line in lines {
            guard line.contains("\"event_msg\"")
                    || line.contains("\"turn_context\"")
                    || line.contains("\"response_item\"") else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
            let envelopeType = json["type"] as? String
            guard let payload = json["payload"] as? [String: Any] else { continue }

            if envelopeType == "turn_context" {
                model = payload["model"] as? String ?? model
                continue
            }

            if envelopeType == "response_item" {
                let itemType = payload["type"] as? String
                switch itemType {
                case "function_call", "custom_tool_call":
                    if isApprovalCall(payload) {
                        if let callID = callID(in: payload) {
                            pendingApprovalCallIDs.insert(callID)
                        } else {
                            hasUnidentifiedApproval = true
                        }
                        activity = .waiting
                    }
                case "function_call_output", "custom_tool_call_output":
                    if let callID = callID(in: payload) {
                        pendingApprovalCallIDs.remove(callID)
                    }
                    hasUnidentifiedApproval = false
                    if pendingApprovalCallIDs.isEmpty, activity == .waiting {
                        activity = .working
                    }
                default:
                    break
                }
                continue
            }

            guard envelopeType == "event_msg", let eventType = payload["type"] as? String else { continue }
            switch eventType {
            case "task_started":
                activity = .working
                pendingApprovalCallIDs.removeAll()
                hasUnidentifiedApproval = false
                contextWindow = integer(payload["model_context_window"]) ?? contextWindow
            case "task_complete", "turn_aborted", "task_cancelled", "task_canceled":
                activity = .idle
                pendingApprovalCallIDs.removeAll()
                hasUnidentifiedApproval = false
            case "task_failed", "task_error":
                activity = .error
                pendingApprovalCallIDs.removeAll()
                hasUnidentifiedApproval = false
            case "exec_approval_request", "apply_patch_approval_request",
                 "request_user_input", "elicitation_request", "permissions_request":
                if let callID = callID(in: payload) {
                    pendingApprovalCallIDs.insert(callID)
                } else {
                    hasUnidentifiedApproval = true
                }
                activity = .waiting
            case "exec_approval_response", "apply_patch_approval_response",
                 "request_user_input_response", "elicitation_response", "permissions_response":
                if let callID = callID(in: payload) {
                    pendingApprovalCallIDs.remove(callID)
                } else {
                    pendingApprovalCallIDs.removeAll()
                }
                hasUnidentifiedApproval = false
                if pendingApprovalCallIDs.isEmpty, activity == .waiting {
                    activity = .working
                }
            case "token_count":
                if let info = payload["info"] as? [String: Any] {
                    contextWindow = integer(info["model_context_window"]) ?? contextWindow
                    if let lastUsage = info["last_token_usage"] as? [String: Any] {
                        usedTokens = integer(lastUsage["total_tokens"])
                            ?? integer(lastUsage["input_tokens"])
                            ?? usedTokens
                    }
                    if let usedTokens, let contextWindow, contextWindow > 0 {
                        let remaining = max(contextWindow - usedTokens, 0)
                        remainingPercent = min(100, max(0, Int((Double(remaining) / Double(contextWindow) * 100).rounded())))
                    }
                }
            default:
                break
            }
        }

        if !pendingApprovalCallIDs.isEmpty || hasUnidentifiedApproval {
            activity = .waiting
        }

        if activity == .working, Date().timeIntervalSince(modifiedAt) > 30 * 60 {
            activity = .idle
        }

        return CodexSnapshot(
            activity: activity,
            contextRemainingPercent: remainingPercent,
            usedTokens: usedTokens,
            contextWindow: contextWindow,
            model: model,
            sessionName: url.deletingPathExtension().lastPathComponent,
            updatedAt: modifiedAt
        )
    }

    private func isApprovalCall(_ payload: [String: Any]) -> Bool {
        let name = (payload["name"] as? String ?? "").lowercased()
        if name == "request_user_input" || name == "elicitation_request" {
            return true
        }
        guard name == "exec_command" else { return false }

        let encodedArguments = payload["arguments"] as? String ?? payload["input"] as? String
        guard let encodedArguments,
              let data = encodedArguments.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return arguments["sandbox_permissions"] as? String == "require_escalated"
    }

    private func callID(in payload: [String: Any]) -> String? {
        for key in ["call_id", "callId", "request_id", "requestId", "id"] {
            if let value = payload[key] as? String, !value.isEmpty { return value }
        }
        return nil
    }

    private func applyingDesktopSignal(to snapshot: CodexSnapshot, now: Date) -> CodexSnapshot {
        guard let signal = desktopMonitor?.activitySignal(now: now) else { return snapshot }
        var result = snapshot
        result.activity = signal.activity
        result.updatedAt = max(result.updatedAt, signal.updatedAt)
        return result
    }

    private func desktopFallbackSnapshot(now: Date) -> CodexSnapshot? {
        guard let signal = desktopMonitor?.activitySignal(now: now) else { return nil }
        return CodexSnapshot(
            activity: signal.activity,
            contextRemainingPercent: nil,
            usedTokens: nil,
            contextWindow: nil,
            model: nil,
            sessionName: signal.conversationID ?? "codex-desktop",
            updatedAt: signal.updatedAt
        )
    }

    private func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

}
