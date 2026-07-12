import Foundation

@main
struct UpdateCoreTests {
    static func main() throws {
        try semanticVersionsAreOrdered()
        try newestUsableReleaseIsSelected()
        try digestsAreValidated()
        print("UpdateCoreTests: PASS")
    }

    private static func semanticVersionsAreOrdered() throws {
        let older = try require(SemanticVersion("v1.6.9"), "missing older version")
        let newer = try require(SemanticVersion("1.7.0"), "missing newer version")
        try check(older < newer, "semantic version ordering failed")
        try check(SemanticVersion("v1.7") == SemanticVersion("1.7.0"), "version padding failed")
        try check(SemanticVersion("not-a-version") == nil, "invalid version should be rejected")
    }

    private static func newestUsableReleaseIsSelected() throws {
        let json = #"""
        [
          {"tag_name":"v1.8.0","name":"Draft","html_url":"https://github.com/example/releases/v1.8.0","draft":true,"prerelease":false,"assets":[{"name":"TC001-Bridge-macOS.zip","browser_download_url":"https://github.com/example/v1.8.0.zip","size":10,"digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]},
          {"tag_name":"v1.7.1","name":"Current","html_url":"https://github.com/example/releases/v1.7.1","draft":false,"prerelease":true,"assets":[{"name":"TC001-Bridge-macOS.zip","browser_download_url":"https://github.com/example/v1.7.1.zip","size":10,"digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]},
          {"tag_name":"v1.7.0","name":"Older","html_url":"https://github.com/example/releases/v1.7.0","draft":false,"prerelease":true,"assets":[{"name":"TC001-Bridge-macOS.zip","browser_download_url":"https://github.com/example/v1.7.0.zip","size":10,"digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}]}
        ]
        """#
        let releases = try AppUpdateResolver.decodeReleases(Data(json.utf8))
        let update = AppUpdateResolver.newestUpdate(in: releases, newerThan: "1.6.1")
        try check(update?.tagName == "v1.7.1", "newest non-draft release should be selected")
        try check(
            AppUpdateResolver.newestUpdate(in: releases, newerThan: "1.7.1") == nil,
            "current version should not update to itself"
        )
    }

    private static func digestsAreValidated() throws {
        let digest = String(repeating: "a", count: 64)
        try check(
            AppUpdateResolver.sha256Digest(from: "sha256:\(digest)") == digest,
            "valid SHA-256 digest should be accepted"
        )
        try check(
            AppUpdateResolver.sha256Digest(from: "sha1:\(digest)") == nil,
            "non-SHA-256 digest should be rejected"
        )
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
