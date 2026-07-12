import Foundation

enum AppUpdateMode: String, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动更新"
        case .manual: return "手动更新"
        }
    }
}

struct GitHubReleaseAsset: Decodable, Equatable {
    let name: String
    let downloadURL: URL
    let size: Int
    let digest: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
        case size
        case digest
    }
}

struct GitHubRelease: Decodable, Equatable {
    let tagName: String
    let name: String?
    let pageURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case pageURL = "html_url"
        case draft
        case prerelease
        case assets
    }

    var version: SemanticVersion? { SemanticVersion(tagName) }

    var archiveAsset: GitHubReleaseAsset? {
        assets.first { $0.name == "TC001-Bridge-macOS.zip" }
    }

    var checksumAsset: GitHubReleaseAsset? {
        assets.first { $0.name == "TC001-Bridge-macOS.zip.sha256" }
    }
}

struct SemanticVersion: Comparable, Equatable, CustomStringConvertible {
    private let components: [Int]

    init?(_ value: String) {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.first == "v" || normalized.first == "V" {
            normalized.removeFirst()
        }
        guard let core = normalized.split(separator: "-", maxSplits: 1).first else { return nil }
        normalized = String(core)
        let values = normalized.split(separator: ".").compactMap { Int($0) }
        guard values.count >= 2, values.count == normalized.split(separator: ".").count else {
            return nil
        }
        components = values + Array(repeating: 0, count: max(0, 3 - values.count))
    }

    var description: String {
        components.prefix(3).map(String.init).joined(separator: ".")
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}

enum AppUpdateResolver {
    static func decodeReleases(_ data: Data) throws -> [GitHubRelease] {
        try JSONDecoder().decode([GitHubRelease].self, from: data)
    }

    static func newestUpdate(
        in releases: [GitHubRelease],
        newerThan currentVersion: String
    ) -> GitHubRelease? {
        guard let current = SemanticVersion(currentVersion) else { return nil }
        return releases
            .filter { !$0.draft && $0.archiveAsset != nil }
            .compactMap { release -> (release: GitHubRelease, version: SemanticVersion)? in
                guard let version = release.version, version > current else { return nil }
                return (release, version)
            }
            .max { $0.version < $1.version }?
            .release
    }

    static func sha256Digest(from value: String?) -> String? {
        guard let value else { return nil }
        let parts = value.lowercased().split(separator: ":", maxSplits: 1)
        guard parts.count == 2, parts[0] == "sha256", parts[1].count == 64 else { return nil }
        return String(parts[1])
    }
}
