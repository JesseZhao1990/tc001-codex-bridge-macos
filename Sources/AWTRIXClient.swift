import Foundation

enum AWTRIXClientError: LocalizedError {
    case invalidAddress
    case invalidResponse
    case httpStatus(Int, String)
    case rebootTimedOut
    case settingsVerificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "TC001 地址无效"
        case .invalidResponse:
            return "TC001 返回了无法识别的数据"
        case let .httpStatus(code, message):
            return "TC001 请求失败（HTTP \(code)）\(message.isEmpty ? "" : "：\(message)")"
        case .rebootTimedOut:
            return "TC001 重启后未能重新连接"
        case .settingsVerificationFailed:
            return "TC001 重启后的页面设置与所选开关不一致"
        }
    }
}

struct AWTRIXClient {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 6
        configuration.waitsForConnectivity = false
        // A LAN device must not be routed through the Mac's HTTP proxy.
        configuration.connectionProxyDictionary = [:]
        return URLSession(configuration: configuration)
    }()

    static func fetchStats(address: String) async throws -> DeviceStats {
        let data = try await request(address: address, path: "/api/stats", method: "GET", body: nil)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AWTRIXClientError.invalidResponse
        }
        return DeviceStats(
            version: json["version"] as? String,
            appName: json["app"] as? String,
            battery: (json["bat"] as? NSNumber)?.intValue
                ?? (json["battery"] as? NSNumber)?.intValue
        )
    }

    static func fetchNativeAppsSettings(address: String) async throws -> NativeAppsSettings {
        let data = try await request(address: address, path: "/api/settings", method: "GET", body: nil)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AWTRIXClientError.invalidResponse
        }
        return NativeAppsSettings(
            showTime: boolean(json["TIM"]),
            showDate: boolean(json["DAT"]),
            showTemperature: boolean(json["TEMP"]),
            showHumidity: boolean(json["HUM"]),
            showBattery: boolean(json["BAT"])
        )
    }

    static func applyNativeAppsSettings(address: String, settings: NativeAppsSettings) async throws {
        let payload: [String: Any] = [
            "TIM": settings.showTime,
            "DAT": settings.showDate,
            "TEMP": settings.showTemperature,
            "HUM": settings.showHumidity,
            "BAT": settings.showBattery
        ]
        _ = try await post(address: address, path: "/api/settings", json: payload)
    }

    static func reboot(address: String) async throws {
        _ = try await request(address: address, path: "/api/reboot", method: "POST", body: Data())
    }

    static func sync(
        address: String,
        appName: String,
        usageDisplay: AWTRIXUsageDisplay,
        activity: ActivityState,
        animationFrame: Int = 0,
        quotaPage: Int = 0,
        quotaWarningFrame: Int = 0,
        previewActivity: ActivityState? = nil,
        switchToApp: Bool
    ) async throws {
        let customPayload = customPayload(
            usageDisplay: usageDisplay,
            activity: activity,
            animationFrame: animationFrame,
            quotaPage: quotaPage,
            quotaWarningFrame: quotaWarningFrame,
            previewActivity: previewActivity
        )
        let encodedName = appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "codex"
        _ = try await post(address: address, path: "/api/custom?name=\(encodedName)", json: customPayload)

        // AWTRIX indicators are drawn over the matrix corners; keep them off so
        // quota text has the full 32-pixel width.
        _ = try await post(
            address: address,
            path: "/api/indicator1",
            json: ["color": "#000000"]
        )

        if switchToApp {
            _ = try await post(address: address, path: "/api/switch", json: ["name": appName])
        }
    }

    static func customPayload(
        usageDisplay: AWTRIXUsageDisplay,
        activity: ActivityState,
        animationFrame: Int,
        quotaPage: Int,
        quotaWarningFrame: Int = 0,
        previewActivity: ActivityState? = nil
    ) -> [String: Any] {
        let lampActivity = previewActivity ?? activity
        let frame = animationFrame % max(lampActivity.animationFrameCount, 1)
        var draw: [[String: Any]] = [
            ["df": [0, 0, 32, 8, "#000000"]]
        ]

        let metric = renderedMetric(for: usageDisplay, quotaPage: quotaPage)
        drawStatusLamp(activity: lampActivity, frame: frame, into: &draw)
        drawMetric(metric.text, color: metric.textColor, into: &draw)

        switch usageDisplay {
        case let .single(percent):
            drawQuotaRail(percent: percent, column: 0, into: &draw)
            drawQuotaRail(percent: nil, column: 31, into: &draw)
        case let .codexQuotas(fiveHour, sevenDay, displayMode):
            if displayMode.showsFiveHour {
                drawQuotaRail(percent: fiveHour, column: 0, into: &draw)
            }
            if displayMode.showsSevenDay {
                drawQuotaRail(percent: sevenDay, column: 31, into: &draw)
            }
        }

        _ = quotaWarningFrame

        return [
            "draw": draw,
            "noScroll": true,
            "repeat": 1
        ]
    }

    static func rgb565Frame(
        usageDisplay: AWTRIXUsageDisplay,
        activity: ActivityState,
        animationFrame: Int,
        quotaPage: Int,
        quotaWarningFrame: Int = 0,
        previewActivity: ActivityState? = nil
    ) -> Data {
        let payload = customPayload(
            usageDisplay: usageDisplay,
            activity: activity,
            animationFrame: animationFrame,
            quotaPage: quotaPage,
            quotaWarningFrame: quotaWarningFrame,
            previewActivity: previewActivity
        )
        return rgb565Frame(from: payload)
    }

    static func rgb565Frame(from payload: [String: Any]) -> Data {
        var pixels = [UInt32](repeating: 0, count: 32 * 8)
        guard let commands = payload["draw"] as? [[String: Any]] else {
            return Data(repeating: 0, count: 32 * 8 * 2)
        }

        func setPixel(x: Int, y: Int, color: UInt32) {
            guard (0..<32).contains(x), (0..<8).contains(y) else { return }
            pixels[y * 32 + x] = color
        }

        for command in commands {
            if let values = command["dp"] as? [Any],
               let x = integer(values, at: 0),
               let y = integer(values, at: 1),
               let color = color(values, at: 2) {
                setPixel(x: x, y: y, color: color)
            } else if let values = command["df"] as? [Any],
                      let x = integer(values, at: 0),
                      let y = integer(values, at: 1),
                      let width = integer(values, at: 2),
                      let height = integer(values, at: 3),
                      let color = color(values, at: 4) {
                for row in y..<(y + max(0, height)) {
                    for column in x..<(x + max(0, width)) {
                        setPixel(x: column, y: row, color: color)
                    }
                }
            } else if let values = command["dl"] as? [Any],
                      let startX = integer(values, at: 0),
                      let startY = integer(values, at: 1),
                      let endX = integer(values, at: 2),
                      let endY = integer(values, at: 3),
                      let color = color(values, at: 4) {
                drawLine(
                    fromX: startX,
                    fromY: startY,
                    toX: endX,
                    toY: endY,
                    color: color,
                    setPixel: setPixel
                )
            }
        }

        var data = Data()
        data.reserveCapacity(pixels.count * 2)
        for color in pixels {
            let value = rgb565(color)
            data.append(UInt8(value & 0xff))
            data.append(UInt8(value >> 8))
        }
        return data
    }

    private static func renderedMetric(
        for usageDisplay: AWTRIXUsageDisplay,
        quotaPage: Int
    ) -> (text: String, percent: Int?, textColor: String, progressColor: String) {
        switch usageDisplay {
        case let .single(percent):
            let normalized = min(100, max(0, percent))
            return ("\(normalized)", normalized, "#FFFFFF", progressColor(for: normalized))
        case let .codexQuotas(fiveHour, sevenDay, displayMode):
            let quota = displayMode.quota(forPage: quotaPage)
            let label = quota == .sevenDay ? "7D" : "5H"
            let percent = quota == .sevenDay ? sevenDay : fiveHour
            guard let percent else {
                return ("\(label)  --", nil, "#8E8E93", "#636366")
            }
            let normalized = min(100, max(0, percent))
            let color = progressColor(for: normalized)
            return ("\(label)  \(normalized)", normalized, color, color)
        }
    }

    private static func integer(_ values: [Any], at index: Int) -> Int? {
        guard values.indices.contains(index) else { return nil }
        if let number = values[index] as? NSNumber { return number.intValue }
        return values[index] as? Int
    }

    private static func color(_ values: [Any], at index: Int) -> UInt32? {
        guard values.indices.contains(index) else { return nil }
        if let number = values[index] as? NSNumber { return number.uint32Value }
        guard let string = values[index] as? String else { return nil }
        return UInt32(string.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16)
    }

    private static func drawLine(
        fromX: Int,
        fromY: Int,
        toX: Int,
        toY: Int,
        color: UInt32,
        setPixel: (Int, Int, UInt32) -> Void
    ) {
        var x = fromX
        var y = fromY
        let deltaX = abs(toX - fromX)
        let stepX = fromX < toX ? 1 : -1
        let deltaY = -abs(toY - fromY)
        let stepY = fromY < toY ? 1 : -1
        var error = deltaX + deltaY

        while true {
            setPixel(x, y, color)
            if x == toX, y == toY { break }
            let doubledError = error * 2
            if doubledError >= deltaY {
                error += deltaY
                x += stepX
            }
            if doubledError <= deltaX {
                error += deltaX
                y += stepY
            }
        }
    }

    private static func rgb565(_ color: UInt32) -> UInt16 {
        let red = UInt16((color >> 16) & 0xff)
        let green = UInt16((color >> 8) & 0xff)
        let blue = UInt16(color & 0xff)
        return ((red & 0xf8) << 8) | ((green & 0xfc) << 3) | (blue >> 3)
    }

    private static func drawQuotaRail(
        percent: Int?,
        column: Int,
        into draw: inout [[String: Any]]
    ) {
        draw.append(["dl": [column, 0, column, 7, "#1C1C1E"]])
        guard let percent else { return }
        let normalized = min(100, max(0, percent))
        guard normalized > 0 else { return }

        let exactHeight = Double(normalized) / 100 * 8
        let fullPixels = min(8, Int(exactHeight.rounded(.down)))
        let fillColor = progressColor(for: normalized)
        for offset in 0..<fullPixels {
            draw.append(["dp": [column, 7 - offset, fillColor]])
        }

        let remainder = exactHeight - Double(fullPixels)
        if fullPixels < 8, remainder > 0 {
            draw.append([
                "dp": [column, 7 - fullPixels, scaledColor(fillColor, factor: max(0.15, remainder))]
            ])
        }
    }

    private static func progressColor(for percent: Int) -> String {
        switch percent {
        case 51...100: return "#30D158"
        case 21...50: return "#FFD60A"
        default: return "#FF453A"
        }
    }

    private static func scaledColor(_ color: String, factor: Double) -> String {
        guard color.hasPrefix("#"), let value = Int(color.dropFirst(), radix: 16) else { return color }
        let normalizedFactor = min(1, max(0, factor))
        let red = Int((Double((value >> 16) & 0xff) * normalizedFactor).rounded())
        let green = Int((Double((value >> 8) & 0xff) * normalizedFactor).rounded())
        let blue = Int((Double(value & 0xff) * normalizedFactor).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private static func drawMetric(
        _ text: String,
        color: String,
        into draw: inout [[String: Any]]
    ) {
        let textAreaStart = 8
        let textAreaWidth = 22
        let width = compactTextWidth(text)
        let x = textAreaStart + max(0, (textAreaWidth - width) / 2)
        drawCompactText(text, x: x, y: 1, color: color, into: &draw)
    }

    private static func drawStatusLamp(
        activity: ActivityState,
        frame: Int,
        into draw: inout [[String: Any]]
    ) {
        let style = lampStyle(activity: activity, frame: frame)
        let rimPoints = [
            (3, 1), (4, 1), (5, 1),
            (2, 2), (6, 2),
            (2, 3), (6, 3),
            (2, 4), (6, 4),
            (3, 5), (4, 5), (5, 5)
        ]
        for (x, y) in rimPoints {
            draw.append(["dp": [x, y, style.rim]])
        }
        for y in 2...4 {
            for x in 3...5 {
                draw.append(["dp": [x, y, style.core]])
            }
        }
        if let highlight = style.highlight {
            draw.append(["dp": [highlight.x, highlight.y, highlight.color]])
        }
    }

    private static func lampStyle(
        activity: ActivityState,
        frame: Int
    ) -> (rim: String, core: String, highlight: (x: Int, y: Int, color: String)?) {
        switch activity {
        case .idle:
            return ("#796500", "#FFD60A", (3, 2, "#FFF3A6"))
        case .working:
            let path = [(3, 1), (5, 1), (6, 2), (6, 4), (5, 5), (3, 5), (2, 4), (2, 2)]
            let point = path[frame % path.count]
            return ("#11652C", "#30D158", (point.0, point.1, "#B8F7C8"))
        case .waiting:
            if frame == 0 || frame == 2 {
                return ("#0757A6", "#0A84FF", (3, 2, "#A6E4FF"))
            }
            return ("#001A35", "#003B70", nil)
        case .error:
            if frame.isMultiple(of: 2) {
                return ("#8A1713", "#FF453A", (3, 2, "#FFB0AA"))
            }
            return ("#300605", "#650E0A", nil)
        }
    }

    private static func drawCompactText(
        _ text: String,
        x: Int,
        y: Int,
        color: String,
        into draw: inout [[String: Any]]
    ) {
        var cursor = x
        var needsGap = false
        for character in text {
            if character == " " {
                cursor += 1
                needsGap = false
                continue
            }
            guard let glyph = compactGlyph(for: character) else {
                if needsGap { cursor += 1 }
                cursor += 2
                needsGap = true
                continue
            }
            if needsGap { cursor += 1 }
            for (rowIndex, row) in glyph.enumerated() {
                for (columnIndex, pixel) in row.enumerated() where pixel == "1" {
                    draw.append(["dp": [cursor + columnIndex, y + rowIndex, color]])
                }
            }
            cursor += glyph.first?.count ?? 0
            needsGap = true
        }
    }

    private static func compactTextWidth(_ text: String) -> Int {
        var width = 0
        var needsGap = false
        for character in text {
            if character == " " {
                width += 1
                needsGap = false
            } else {
                if needsGap { width += 1 }
                width += compactGlyph(for: character)?.first?.count ?? 1
                needsGap = true
            }
        }
        return width
    }

    private static func compactGlyph(for character: Character) -> [String]? {
        switch character {
        case "0": return ["111", "101", "101", "101", "111"]
        case "1": return ["01", "11", "01", "01", "11"]
        case "2": return ["111", "001", "111", "100", "111"]
        case "3": return ["111", "001", "111", "001", "111"]
        case "4": return ["101", "101", "111", "001", "001"]
        case "5": return ["111", "100", "111", "001", "111"]
        case "6": return ["111", "100", "111", "101", "111"]
        case "7": return ["111", "001", "010", "010", "010"]
        case "8": return ["111", "101", "111", "101", "111"]
        case "9": return ["111", "101", "111", "001", "111"]
        case "-": return ["000", "000", "111", "000", "000"]
        case "H": return ["101", "101", "111", "101", "101"]
        case "D": return ["110", "101", "101", "101", "110"]
        case "A": return ["010", "101", "111", "101", "101"]
        case "I": return ["111", "010", "010", "010", "111"]
        case "L": return ["100", "100", "100", "100", "111"]
        case "R": return ["110", "101", "110", "101", "101"]
        case "T": return ["111", "010", "010", "010", "010"]
        case "U": return ["101", "101", "101", "101", "111"]
        case "W": return ["101", "101", "111", "111", "101"]
        case "N": return ["101", "111", "111", "111", "101"]
        case "Z": return ["111", "001", "010", "100", "111"]
        case "E": return ["111", "100", "110", "100", "111"]
        default: return nil
        }
    }

    private static func post(address: String, path: String, json: [String: Any]) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: json)
        return try await request(address: address, path: path, method: "POST", body: body)
    }

    private static func request(address: String, path: String, method: String, body: Data?) async throws -> Data {
        guard let baseURL = normalizedBaseURL(from: address),
              let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw AWTRIXClientError.invalidAddress
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("TC001Bridge/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AWTRIXClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw AWTRIXClientError.httpStatus(http.statusCode, message)
        }
        return data
    }

    private static func normalizedBaseURL(from address: String) -> URL? {
        var value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") {
            value = "http://" + value
        }
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return URL(string: value + "/")
    }

    private static func boolean(_ value: Any?) -> Bool {
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String { return (string as NSString).boolValue }
        return false
    }
}
