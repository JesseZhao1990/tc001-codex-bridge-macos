import Foundation

@main
struct AWTRIXRendererTests {
    static func main() throws {
        try check(QuotaPageSchedule.duration(for: 0) == 7, "5-hour page should last 7 seconds")
        try check(QuotaPageSchedule.duration(for: 1) == 3, "7-day page should last 3 seconds")
        try check(QuotaPageSchedule.page(at: 0) == 0, "cycle should start with the 5-hour page")
        try check(QuotaPageSchedule.page(at: 6.99) == 0, "5-hour page should occupy the first 7 seconds")
        try check(QuotaPageSchedule.page(at: 7) == 1, "7-day page should begin at 7 seconds")
        try check(QuotaPageSchedule.page(at: 9.99) == 1, "7-day page should occupy the final 3 seconds")
        try check(QuotaPageSchedule.page(at: 10) == 0, "the next cycle should return to the 5-hour page")

        let display = AWTRIXUsageDisplay.codexQuotas(fiveHour: 50, sevenDay: 25)
        let fiveHour = AWTRIXClient.customPayload(
            usageDisplay: display,
            activity: .working,
            animationFrame: 0,
            quotaPage: 0
        )
        let sevenDay = AWTRIXClient.customPayload(
            usageDisplay: display,
            activity: .working,
            animationFrame: 0,
            quotaPage: 1
        )
        let missing = AWTRIXClient.customPayload(
            usageDisplay: .codexQuotas(fiveHour: nil, sevenDay: nil),
            activity: .error,
            animationFrame: 0,
            quotaPage: 1
        )
        let partial = AWTRIXClient.customPayload(
            usageDisplay: .codexQuotas(fiveHour: 50, sevenDay: 25),
            activity: .idle,
            animationFrame: 0,
            quotaPage: 0
        )
        let onePercent = AWTRIXClient.customPayload(
            usageDisplay: .codexQuotas(fiveHour: 1, sevenDay: 0),
            activity: .idle,
            animationFrame: 0,
            quotaPage: 0
        )
        let spacedMetric = AWTRIXClient.customPayload(
            usageDisplay: .codexQuotas(fiveHour: 80, sevenDay: 65),
            activity: .working,
            animationFrame: 0,
            quotaPage: 0
        )

        try validateBounds(in: fiveHour)
        try validateBounds(in: sevenDay)
        try validateBounds(in: missing)
        try validateBounds(in: partial)
        try validateBounds(in: onePercent)
        try validateBounds(in: spacedMetric)

        for activity in ActivityState.allCases {
            let preview = AWTRIXClient.customPayload(
                usageDisplay: .codexQuotas(fiveHour: nil, sevenDay: nil),
                activity: .idle,
                animationFrame: 0,
                quotaPage: 0,
                previewActivity: activity
            )
            try validateBounds(in: preview)
        }

        let fiveHourData = try JSONSerialization.data(withJSONObject: fiveHour, options: [.sortedKeys])
        let sevenDayData = try JSONSerialization.data(withJSONObject: sevenDay, options: [.sortedKeys])
        try check(fiveHourData != sevenDayData, "5-hour and 7-day pages should render differently")

        let leftLines = try verticalLines(in: partial, column: 0)
        let rightLines = try verticalLines(in: partial, column: 31)
        try check(leftLines.count == 1, "left column should contain one 1x8 track")
        try check(rightLines.count == 1, "right column should contain one 1x8 track")
        try check(try integer(leftLines[0], at: 1) == 0, "5-hour track should start at the top")
        try check(try integer(leftLines[0], at: 3) == 7, "5-hour track should reach the bottom")
        try check(try integer(rightLines[0], at: 1) == 0, "7-day track should start at the top")
        try check(try integer(rightLines[0], at: 3) == 7, "7-day track should reach the bottom")
        try check(try pointRows(in: partial, column: 0) == [4, 5, 6, 7], "50 percent should fill four pixels")
        try check(try pointRows(in: partial, column: 31) == [6, 7], "25 percent should fill two pixels")

        try check(try pointRows(in: onePercent, column: 0) == [7], "a positive quota should light one partial pixel")
        try check(try pointRows(in: onePercent, column: 31).isEmpty, "zero percent should only show its track")

        try check(try pointCount(in: spacedMetric, column: 18) == 0, "first label/value spacer column should be blank")
        try check(try pointCount(in: spacedMetric, column: 19) == 0, "second label/value spacer column should be blank")
        try check(try pointCount(in: spacedMetric, column: 20) > 0, "quota value should start after the two-column gap")
        try check(try pointCount(in: spacedMetric, column: 27) == 0, "quota text should not include a percent glyph")

        let maxText = AWTRIXClient.customPayload(
            usageDisplay: .codexQuotas(fiveHour: 100, sevenDay: 100),
            activity: .idle,
            animationFrame: 0,
            quotaPage: 0
        )
        try validateBounds(in: maxText)
        try check(try pointCount(in: maxText, column: 30) == 0, "x30 should remain a gap beside the 7-day rail")
        try check(try centralPixels(in: maxText, rows: [0, 6, 7]).isEmpty, "top and bottom center rows should remain black")
        try check(try uniquePoints(in: maxText, x: 2...6, y: 1...5).count == 21, "status lamp should be a rounded 5x5 light")

        try checkLampColor(.idle, frame: 0, color: "#FFD60A")
        try checkLampColor(.working, frame: 0, color: "#30D158")
        try checkLampColor(.waiting, frame: 0, color: "#0A84FF")
        try checkLampColor(.error, frame: 0, color: "#FF453A")
        try checkFramesDiffer(.working, first: 0, second: 1, "working highlight should move inside the lamp")
        try checkFramesDiffer(.waiting, first: 0, second: 1, "waiting lamp should double-flash")
        try checkFramesDiffer(.error, first: 0, second: 1, "error lamp should blink")

        let bluetoothFrame = AWTRIXClient.rgb565Frame(
            usageDisplay: display,
            activity: .working,
            animationFrame: 0,
            quotaPage: 0
        )
        try check(bluetoothFrame.count == 512, "Bluetooth frame should contain 32x8 RGB565 pixels")
        try check(
            pixel(in: bluetoothFrame, x: 4, y: 3) == 0x368B,
            "Bluetooth frame should preserve the green status-lamp core"
        )
        try check(
            pixel(in: bluetoothFrame, x: 30, y: 0) == 0,
            "Bluetooth frame should preserve the blank column beside the right rail"
        )

        let nativeApps = NativeAppsSettings(
            showTime: true,
            showDate: false,
            showTemperature: true,
            showHumidity: false,
            showBattery: true
        )
        try check(nativeApps.bleMask == 0x15, "native-app switches should encode as a bit mask")
        try check(
            NativeAppsSettings(bleMask: nativeApps.bleMask) == nativeApps,
            "native-app bit mask should round-trip"
        )

        print("AWTRIXRendererTests: PASS")
    }

    private static func validateBounds(in payload: [String: Any]) throws {
        guard let commands = payload["draw"] as? [[String: Any]] else {
            throw TestFailure("missing draw commands")
        }

        for command in commands {
            if let values = command["dp"] as? [Any] {
                try point(x: integer(values, at: 0), y: integer(values, at: 1))
            } else if let values = command["dl"] as? [Any] {
                try point(x: integer(values, at: 0), y: integer(values, at: 1))
                try point(x: integer(values, at: 2), y: integer(values, at: 3))
            } else if let values = command["df"] as? [Any] {
                let x = try integer(values, at: 0)
                let y = try integer(values, at: 1)
                let width = try integer(values, at: 2)
                let height = try integer(values, at: 3)
                try check(x >= 0 && y >= 0 && width > 0 && height > 0, "invalid fill rectangle")
                try check(x + width <= 32 && y + height <= 8, "fill rectangle exceeds the matrix")
            }
        }
    }

    private static func point(x: Int, y: Int) throws {
        try check((0..<32).contains(x), "x coordinate \(x) exceeds the matrix")
        try check((0..<8).contains(y), "y coordinate \(y) exceeds the matrix")
    }

    private static func pointRows(in payload: [String: Any], column: Int) throws -> [Int] {
        guard let commands = payload["draw"] as? [[String: Any]] else {
            throw TestFailure("missing draw commands")
        }
        return try commands.compactMap { command -> Int? in
            guard let values = command["dp"] as? [Any],
                  try integer(values, at: 0) == column else { return nil }
            return try integer(values, at: 1)
        }.sorted()
    }

    private static func pointCount(in payload: [String: Any], column: Int) throws -> Int {
        try pointRows(in: payload, column: column).count
    }

    private static func centralPixels(in payload: [String: Any], rows: Set<Int>) throws -> [[Any]] {
        guard let commands = payload["draw"] as? [[String: Any]] else {
            throw TestFailure("missing draw commands")
        }
        return try commands.compactMap { command -> [Any]? in
            guard let values = command["dp"] as? [Any] else { return nil }
            let x = try integer(values, at: 0)
            let y = try integer(values, at: 1)
            return (1...30).contains(x) && rows.contains(y) ? values : nil
        }
    }

    private static func uniquePoints(
        in payload: [String: Any],
        x xRange: ClosedRange<Int>,
        y yRange: ClosedRange<Int>
    ) throws -> Set<String> {
        guard let commands = payload["draw"] as? [[String: Any]] else {
            throw TestFailure("missing draw commands")
        }
        return try Set(commands.compactMap { command -> String? in
            guard let values = command["dp"] as? [Any] else { return nil }
            let x = try integer(values, at: 0)
            let y = try integer(values, at: 1)
            guard xRange.contains(x), yRange.contains(y) else { return nil }
            return "\(x):\(y)"
        })
    }

    private static func checkLampColor(
        _ activity: ActivityState,
        frame: Int,
        color: String
    ) throws {
        let payload = AWTRIXClient.customPayload(
            usageDisplay: .codexQuotas(fiveHour: nil, sevenDay: nil),
            activity: activity,
            animationFrame: frame,
            quotaPage: 0
        )
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
        try check(json.contains(color), "\(activity.rawValue) lamp should use \(color)")
    }

    private static func checkFramesDiffer(
        _ activity: ActivityState,
        first: Int,
        second: Int,
        _ message: String
    ) throws {
        let firstPayload = AWTRIXClient.customPayload(
            usageDisplay: .codexQuotas(fiveHour: nil, sevenDay: nil),
            activity: activity,
            animationFrame: first,
            quotaPage: 0
        )
        let secondPayload = AWTRIXClient.customPayload(
            usageDisplay: .codexQuotas(fiveHour: nil, sevenDay: nil),
            activity: activity,
            animationFrame: second,
            quotaPage: 0
        )
        let firstData = try JSONSerialization.data(withJSONObject: firstPayload, options: [.sortedKeys])
        let secondData = try JSONSerialization.data(withJSONObject: secondPayload, options: [.sortedKeys])
        try check(firstData != secondData, message)
    }

    private static func verticalLines(in payload: [String: Any], column: Int) throws -> [[Any]] {
        guard let commands = payload["draw"] as? [[String: Any]] else {
            throw TestFailure("missing draw commands")
        }
        return commands.compactMap { command in
            guard let values = command["dl"] as? [Any],
                  values.count >= 4,
                  let startColumn = values[0] as? NSNumber,
                  let endColumn = values[2] as? NSNumber,
                  startColumn.intValue == column,
                  endColumn.intValue == column else { return nil }
            return values
        }
    }

    private static func integer(_ values: [Any], at index: Int) throws -> Int {
        guard values.indices.contains(index), let number = values[index] as? NSNumber else {
            throw TestFailure("invalid draw command")
        }
        return number.intValue
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }

    private static func pixel(in data: Data, x: Int, y: Int) -> UInt16 {
        let offset = (y * 32 + x) * 2
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
