import Foundation

@main
struct CodexRateLimitsClientTests {
    static func main() throws {
        let response = #"{"id":3,"result":{"rateLimits":{"limitId":"codex","limitName":null,"primary":{"usedPercent":74,"windowDurationMins":300,"resetsAt":1783785234},"secondary":{"usedPercent":12,"windowDurationMins":10080,"resetsAt":1784372034}},"rateLimitsByLimitId":{"codex_bengalfox":{"limitId":"codex_bengalfox","limitName":"GPT-5.3-Codex-Spark","primary":{"usedPercent":0,"windowDurationMins":300,"resetsAt":1783800820},"secondary":{"usedPercent":0,"windowDurationMins":10080,"resetsAt":1784387620}},"codex":{"limitId":"codex","limitName":null,"primary":{"usedPercent":74,"windowDurationMins":300,"resetsAt":1783785234},"secondary":{"usedPercent":12,"windowDurationMins":10080,"resetsAt":1784372034}}}}}"#

        let quota = try CodexRateLimitsClient.decodeQuota(from: Data(response.utf8))
        try check(quota.limitID == "codex", "account-level codex bucket should be selected")
        try check(
            quota.window(minutes: 300)?.remainingPercent == 26,
            "5-hour remaining quota should be calculated from real usedPercent"
        )
        try check(
            quota.window(minutes: 10_080)?.remainingPercent == 88,
            "7-day remaining quota should be calculated from real usedPercent"
        )

        if ProcessInfo.processInfo.environment["TC001_LIVE_CODEX_QUOTA"] == "1" {
            let liveQuota = try CodexRateLimitsClient().fetch()
            let fiveHour = liveQuota.window(minutes: 300)?.remainingPercent
            let sevenDay = liveQuota.window(minutes: 10_080)?.remainingPercent
            print("Codex live quota: 5h=\(fiveHour.map(String.init) ?? "--") 7d=\(sevenDay.map(String.init) ?? "--")")
        }
        print("CodexRateLimitsClientTests: PASS")
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
