import Foundation

@main
struct UpdaterHelperIntegrationTests {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw TestFailure("helper path is required")
        }
        let helper = URL(fileURLWithPath: CommandLine.arguments[1])
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("tc001-helper-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let target = root.appendingPathComponent("TC001 Bridge.app", isDirectory: true)
        let source = root.appendingPathComponent("staged/TC001 Bridge.app", isDirectory: true)
        try makeApplication(at: target, bundleIdentifier: "io.github.tc001bridge.macos", marker: "old")
        try makeApplication(at: source, bundleIdentifier: "io.github.tc001bridge.macos", marker: "new")

        let sleeper = Process()
        sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleeper.arguments = ["0.2"]
        try sleeper.run()

        let updater = Process()
        updater.executableURL = helper
        updater.arguments = [
            String(sleeper.processIdentifier),
            source.path,
            target.path,
            "io.github.tc001bridge.macos",
            "--no-launch"
        ]
        updater.environment = ["TC001_UPDATE_LOG_DIR": root.appendingPathComponent("logs").path]
        try updater.run()
        updater.waitUntilExit()

        try check(updater.terminationStatus == 0, "helper should replace the application")
        let marker = try String(contentsOf: target.appendingPathComponent("marker"), encoding: .utf8)
        try check(marker == "new", "new application was not installed")
        try check(!fileManager.fileExists(atPath: source.path), "staged application should be moved")
        let leftovers = try fileManager.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasPrefix(".TC001 Bridge.previous-") }
        try check(leftovers.isEmpty, "backup should be removed after a successful update")
        print("UpdaterHelperIntegrationTests: PASS")
    }

    private static func makeApplication(
        at url: URL,
        bundleIdentifier: String,
        marker: String
    ) throws {
        let fileManager = FileManager.default
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        let executableDirectory = contents.appendingPathComponent("MacOS", isDirectory: true)
        try fileManager.createDirectory(at: executableDirectory, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleExecutable": "TC001Bridge",
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        try Data().write(to: executableDirectory.appendingPathComponent("TC001Bridge"))
        try marker.write(to: url.appendingPathComponent("marker"), atomically: true, encoding: .utf8)
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
