import AppKit
import Combine
import CryptoKit
import Foundation

enum AppUpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available
    case downloading
    case preparing
    case installing
    case failed(String)
}

enum AppUpdateError: LocalizedError {
    case invalidResponse
    case missingArchive
    case missingChecksum
    case checksumMismatch
    case invalidApplication
    case invalidSignature
    case helperMissing
    case translocatedApplication
    case applicationDirectoryNotWritable
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "GitHub 返回了无法识别的更新信息"
        case .missingArchive: return "新版 Release 中没有 macOS 安装包"
        case .missingChecksum: return "新版 Release 中没有可验证的 SHA-256"
        case .checksumMismatch: return "更新包 SHA-256 校验失败"
        case .invalidApplication: return "更新包中的应用标识或版本不正确"
        case .invalidSignature: return "更新包代码签名校验失败"
        case .helperMissing: return "应用内缺少更新辅助程序"
        case .translocatedApplication: return "请先将 TC001 Bridge 移到“应用程序”文件夹再自动更新"
        case .applicationDirectoryNotWritable: return "当前应用目录不可写，请使用手动更新"
        case let .processFailed(message): return message
        }
    }
}

@MainActor
final class AppUpdateManager: ObservableObject {
    private enum DefaultsKey {
        static let mode = "appUpdateMode"
    }

    @Published private(set) var mode: AppUpdateMode
    @Published private(set) var status: AppUpdateStatus = .idle
    @Published private(set) var latestRelease: GitHubRelease?

    let currentVersion: String
    let currentBuild: String

    private let defaults: UserDefaults
    private let session: URLSession
    private let fileManager: FileManager
    private let applicationURL: URL
    private let bundleIdentifier: String
    private var automaticTask: Task<Void, Never>?
    private var started = false

    private static let releasesAPI = URL(
        string: "https://api.github.com/repos/JesseZhao1990/tc001-codex-bridge-macos/releases?per_page=20"
    )!
    private static let releasesPage = URL(
        string: "https://github.com/JesseZhao1990/tc001-codex-bridge-macos/releases"
    )!

    init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.session = session
        self.fileManager = fileManager
        self.applicationURL = bundle.bundleURL.standardizedFileURL
        self.bundleIdentifier = bundle.bundleIdentifier ?? "io.github.tc001bridge.macos"
        self.currentVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        self.currentBuild = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        self.mode = defaults.string(forKey: DefaultsKey.mode)
            .flatMap(AppUpdateMode.init(rawValue:)) ?? .manual
    }

    deinit {
        automaticTask?.cancel()
    }

    var statusText: String {
        switch status {
        case .idle: return "尚未检查更新"
        case .checking: return "正在检查更新"
        case .upToDate: return "当前已是最新版本"
        case .available:
            return "发现版本 \(latestVersionText)"
        case .downloading: return "正在下载更新"
        case .preparing: return "正在验证更新"
        case .installing: return "正在安装并重启"
        case let .failed(message): return message
        }
    }

    var latestVersionText: String {
        latestRelease?.version?.description ?? latestRelease?.tagName ?? "--"
    }

    var hasAvailableUpdate: Bool {
        status == .available && latestRelease != nil
    }

    var isBusy: Bool {
        switch status {
        case .checking, .downloading, .preparing, .installing: return true
        default: return false
        }
    }

    func start() {
        guard !started else { return }
        started = true
        automaticTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                if self.mode == .automatic {
                    await self.checkForUpdates(installAutomatically: true)
                }
                try? await Task.sleep(nanoseconds: 6 * 60 * 60 * 1_000_000_000)
            }
        }
    }

    func setMode(_ newMode: AppUpdateMode) {
        guard mode != newMode else { return }
        mode = newMode
        defaults.set(newMode.rawValue, forKey: DefaultsKey.mode)
        if newMode == .automatic {
            Task { [weak self] in
                await self?.checkForUpdates(installAutomatically: true)
            }
        }
    }

    func checkForUpdates(installAutomatically: Bool = false) async {
        guard !isBusy else { return }
        status = .checking
        do {
            let releases = try await fetchReleases()
            latestRelease = AppUpdateResolver.newestUpdate(
                in: releases,
                newerThan: currentVersion
            )
            guard latestRelease != nil else {
                status = .upToDate
                return
            }
            status = .available
            if installAutomatically, mode == .automatic {
                await installAvailableUpdate()
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func installAvailableUpdate() async {
        guard !isBusy, let release = latestRelease else { return }
        do {
            let preparedApplication = try await prepareApplication(from: release)
            status = .installing
            try launchUpdateHelper(with: preparedApplication)
            NSApp.terminate(nil)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func openReleasePage() {
        NSWorkspace.shared.open(latestRelease?.pageURL ?? Self.releasesPage)
    }

    private func fetchReleases() async throws -> [GitHubRelease] {
        var request = URLRequest(url: Self.releasesAPI)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("TC001Bridge/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppUpdateError.invalidResponse
        }
        return try AppUpdateResolver.decodeReleases(data)
    }

    func prepareApplication(from release: GitHubRelease) async throws -> URL {
        guard let archiveAsset = release.archiveAsset else { throw AppUpdateError.missingArchive }
        status = .downloading
        let archiveData = try await download(asset: archiveAsset)
        let expectedDigest = try await expectedDigest(for: release, archiveAsset: archiveAsset)
        let actualDigest = SHA256.hash(data: archiveData).map { String(format: "%02x", $0) }.joined()
        guard actualDigest == expectedDigest else { throw AppUpdateError.checksumMismatch }

        status = .preparing
        let updateRoot = fileManager.temporaryDirectory
            .appendingPathComponent("tc001-update-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = updateRoot.appendingPathComponent(archiveAsset.name)
        let expandedURL = updateRoot.appendingPathComponent("expanded", isDirectory: true)
        try fileManager.createDirectory(at: expandedURL, withIntermediateDirectories: true)
        try archiveData.write(to: archiveURL, options: .atomic)

        try await Self.runProcess(
            executable: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-x", "-k", archiveURL.path, expandedURL.path]
        )

        let candidate = expandedURL.appendingPathComponent("TC001 Bridge.app", isDirectory: true)
        guard let bundle = Bundle(url: candidate),
              bundle.bundleIdentifier == bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                == release.version?.description else {
            throw AppUpdateError.invalidApplication
        }

        do {
            try await Self.runProcess(
                executable: URL(fileURLWithPath: "/usr/bin/codesign"),
                arguments: ["--verify", "--deep", "--strict", candidate.path]
            )
        } catch {
            throw AppUpdateError.invalidSignature
        }
        return candidate
    }

    private func expectedDigest(
        for release: GitHubRelease,
        archiveAsset: GitHubReleaseAsset
    ) async throws -> String {
        if let digest = AppUpdateResolver.sha256Digest(from: archiveAsset.digest) {
            return digest
        }
        guard let checksumAsset = release.checksumAsset else {
            throw AppUpdateError.missingChecksum
        }
        let data = try await download(asset: checksumAsset)
        guard let text = String(data: data, encoding: .utf8),
              let digest = text.split(whereSeparator: { $0.isWhitespace }).first,
              digest.count == 64 else {
            throw AppUpdateError.missingChecksum
        }
        return digest.lowercased()
    }

    private func download(asset: GitHubReleaseAsset) async throws -> Data {
        guard asset.downloadURL.host?.lowercased() == "github.com",
              asset.size > 0,
              asset.size <= 100 * 1024 * 1024 else {
            throw AppUpdateError.invalidResponse
        }
        var request = URLRequest(url: asset.downloadURL)
        request.timeoutInterval = 60
        request.setValue("TC001Bridge/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              data.count == asset.size else {
            throw AppUpdateError.invalidResponse
        }
        return data
    }

    private func launchUpdateHelper(with preparedApplication: URL) throws {
        if applicationURL.path.contains("/AppTranslocation/") {
            throw AppUpdateError.translocatedApplication
        }
        let parent = applicationURL.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parent.path) else {
            throw AppUpdateError.applicationDirectoryNotWritable
        }
        let helperURL = applicationURL
            .appendingPathComponent("Contents/Helpers/TC001UpdateHelper")
        guard fileManager.isExecutableFile(atPath: helperURL.path) else {
            throw AppUpdateError.helperMissing
        }

        let process = Process()
        process.executableURL = helperURL
        process.arguments = [
            String(ProcessInfo.processInfo.processIdentifier),
            preparedApplication.path,
            applicationURL.path,
            bundleIdentifier
        ]
        try process.run()
    }

    nonisolated private static func runProcess(
        executable: URL,
        arguments: [String]
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errorPipe
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let reason = message.flatMap { $0.isEmpty ? nil : $0 }
                        ?? "更新辅助命令执行失败"
                    continuation.resume(throwing: AppUpdateError.processFailed(reason))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
