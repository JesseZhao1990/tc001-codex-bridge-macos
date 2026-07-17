import Foundation

@main
struct WidgetStatusSnapshotTests {
    static func main() throws {
        let generatedAt = Date(timeIntervalSince1970: 1_000)
        let lastSyncDate = Date(timeIntervalSince1970: 900)
        let snapshot = WidgetStatusSnapshot(
            generatedAt: generatedAt,
            quotaSource: .codex,
            fiveHourRemainingPercent: 120,
            sevenDayRemainingPercent: -4,
            manualRemainingPercent: nil,
            showsFiveHourQuota: true,
            showsSevenDayQuota: true,
            activity: .working,
            sourceTitle: "Codex · gpt-test",
            transportTitle: "蓝牙",
            connection: .connected,
            batteryPercent: 101,
            lastSyncDate: lastSyncDate
        )

        try check(snapshot.fiveHourRemainingPercent == 100, "five-hour quota should clamp to 100")
        try check(snapshot.sevenDayRemainingPercent == 0, "seven-day quota should clamp to 0")
        try check(snapshot.batteryPercent == 100, "battery should clamp to 100")

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetStatusSnapshot.self, from: encoded)
        try check(decoded == snapshot, "widget snapshot should round-trip through Codable")

        let laterSnapshot = WidgetStatusSnapshot(
            generatedAt: generatedAt.addingTimeInterval(30),
            quotaSource: .codex,
            fiveHourRemainingPercent: 100,
            sevenDayRemainingPercent: 0,
            manualRemainingPercent: nil,
            showsFiveHourQuota: true,
            showsSevenDayQuota: true,
            activity: .working,
            sourceTitle: "Codex · gpt-test",
            transportTitle: "蓝牙",
            connection: .connected,
            batteryPercent: 100,
            lastSyncDate: lastSyncDate.addingTimeInterval(30)
        )
        try check(
            laterSnapshot.contentSignature == snapshot.contentSignature,
            "timestamps should not force widget reloads"
        )

        let changedSnapshot = WidgetStatusSnapshot(
            generatedAt: generatedAt,
            quotaSource: .codex,
            fiveHourRemainingPercent: 99,
            sevenDayRemainingPercent: 0,
            manualRemainingPercent: nil,
            showsFiveHourQuota: true,
            showsSevenDayQuota: true,
            activity: .working,
            sourceTitle: "Codex · gpt-test",
            transportTitle: "蓝牙",
            connection: .connected,
            batteryPercent: 100,
            lastSyncDate: lastSyncDate
        )
        try check(
            changedSnapshot.contentSignature != snapshot.contentSignature,
            "visible quota changes should reload the widget"
        )

        print("WidgetStatusSnapshotTests: PASS")
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
