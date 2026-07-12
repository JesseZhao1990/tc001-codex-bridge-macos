import Darwin
import Foundation

enum UpdateHelperError: Error {
    case invalidArguments
    case applicationDidNotExit
    case invalidSourceApplication
    case targetDirectoryNotWritable
}

@main
struct TC001UpdateHelper {
    static func main() {
        do {
            try run()
        } catch {
            writeLog("Update failed: \(error)")
            exit(EXIT_FAILURE)
        }
    }

    private static func run() throws {
        let arguments = CommandLine.arguments
        guard (arguments.count == 5 || arguments.count == 6),
              let processID = Int32(arguments[1]) else {
            throw UpdateHelperError.invalidArguments
        }

        let source = URL(fileURLWithPath: arguments[2], isDirectory: true).standardizedFileURL
        let target = URL(fileURLWithPath: arguments[3], isDirectory: true).standardizedFileURL
        let expectedBundleIdentifier = arguments[4]
        let shouldLaunch = arguments.count == 5 || arguments[5] != "--no-launch"
        let fileManager = FileManager.default

        guard source.pathExtension == "app",
              target.pathExtension == "app",
              let sourceBundle = Bundle(url: source),
              sourceBundle.bundleIdentifier == expectedBundleIdentifier else {
            throw UpdateHelperError.invalidSourceApplication
        }

        let parent = target.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parent.path) else {
            throw UpdateHelperError.targetDirectoryNotWritable
        }

        for _ in 0..<300 {
            if kill(processID, 0) != 0 { break }
            usleep(100_000)
        }
        guard kill(processID, 0) != 0 else {
            throw UpdateHelperError.applicationDidNotExit
        }

        let backup = parent.appendingPathComponent(
            ".TC001 Bridge.previous-\(UUID().uuidString).app",
            isDirectory: true
        )
        var movedOriginal = false
        do {
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.moveItem(at: target, to: backup)
                movedOriginal = true
            }
            try fileManager.moveItem(at: source, to: target)
        } catch {
            if movedOriginal,
               !fileManager.fileExists(atPath: target.path),
               fileManager.fileExists(atPath: backup.path) {
                try? fileManager.moveItem(at: backup, to: target)
            }
            throw error
        }

        if shouldLaunch {
            let open = Process()
            open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            open.arguments = [target.path]
            do {
                try open.run()
                open.waitUntilExit()
                guard open.terminationStatus == 0 else {
                    throw UpdateHelperError.invalidSourceApplication
                }
            } catch {
                try? fileManager.removeItem(at: target)
                if movedOriginal, fileManager.fileExists(atPath: backup.path) {
                    try? fileManager.moveItem(at: backup, to: target)
                }
                throw error
            }
        }

        if movedOriginal {
            try? fileManager.removeItem(at: backup)
        }
        writeLog("Updated successfully: \(target.path)")
    }

    private static func writeLog(_ message: String) {
        let fileManager = FileManager.default
        let directory = ProcessInfo.processInfo.environment["TC001_UPDATE_LOG_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/TC001 Bridge", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let logURL = directory.appendingPathComponent("update.log")

        if fileManager.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
}
