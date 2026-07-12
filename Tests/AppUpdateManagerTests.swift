import Foundation

@main
@MainActor
struct AppUpdateManagerTests {
    static func main() async throws {
        let manager = AppUpdateManager()
        try check(manager.currentVersion == "0.0.0", "test bundle should use the fallback version")

        if ProcessInfo.processInfo.environment["TC001_LIVE_UPDATE"] == "1" {
            try await liveReleaseIsDownloadedAndVerified(manager: manager)
        }
        print("AppUpdateManagerTests: PASS")
    }

    private static func liveReleaseIsDownloadedAndVerified(
        manager: AppUpdateManager
    ) async throws {
        let url = URL(
            string: "https://api.github.com/repos/JesseZhao1990/tc001-codex-bridge-macos/releases?per_page=20"
        )!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TC001BridgeTests/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        try check((response as? HTTPURLResponse)?.statusCode == 200, "GitHub releases request failed")
        let releases = try AppUpdateResolver.decodeReleases(data)
        guard let release = releases.first(where: { $0.tagName == "v1.6.1" }) else {
            throw TestFailure("v1.6.1 release was not found")
        }

        let application = try await manager.prepareApplication(from: release)
        defer {
            let updateRoot = application
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            try? FileManager.default.removeItem(at: updateRoot)
        }
        let bundle = try require(Bundle(url: application), "downloaded application is not a bundle")
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        try check(version == "1.6.1", "downloaded release version mismatch")
        print("Live update package verified: \(version ?? "--")")
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
