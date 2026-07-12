import AppKit
import Foundation

private let columns = 32
private let rows = 8
private let cellSize = 27
private let gap = 8
private let pitch = cellSize + gap
private let framePadding = 18
private let panelPadding = 10

private let matrixWidth = columns * pitch - gap
private let matrixHeight = rows * pitch - gap
private let panelWidth = matrixWidth + panelPadding * 2
private let panelHeight = matrixHeight + panelPadding * 2
private let imageWidth = panelWidth + framePadding * 2
private let imageHeight = panelHeight + framePadding * 2

private func color(_ hex: String) -> CGColor {
    let value = Int(hex.dropFirst(), radix: 16) ?? 0
    return CGColor(
        red: CGFloat((value >> 16) & 0xff) / 255,
        green: CGFloat((value >> 8) & 0xff) / 255,
        blue: CGFloat(value & 0xff) / 255,
        alpha: 1
    )
}

private func compactGlyph(_ character: Character) -> [String] {
    switch character {
    case "0": return ["111", "101", "101", "101", "111"]
    case "5": return ["111", "100", "111", "001", "111"]
    case "8": return ["111", "101", "111", "101", "111"]
    case "H": return ["101", "101", "111", "101", "101"]
    default: return []
    }
}

private var pixels = Array(
    repeating: Array<String?>(repeating: nil, count: columns),
    count: rows
)

private func setPixel(_ x: Int, _ y: Int, _ hex: String) {
    guard (0..<columns).contains(x), (0..<rows).contains(y) else { return }
    pixels[y][x] = hex
}

private func drawText(_ text: String, x: Int, y: Int, hex: String) {
    var cursor = x
    var needsGap = false
    for character in text {
        if character == " " {
            cursor += 1
            needsGap = false
            continue
        }
        let glyph = compactGlyph(character)
        if needsGap { cursor += 1 }
        for (rowIndex, row) in glyph.enumerated() {
            for (columnIndex, value) in row.enumerated() where value == "1" {
                setPixel(cursor + columnIndex, y + rowIndex, hex)
            }
        }
        cursor += glyph.first?.count ?? 0
        needsGap = true
    }
}

// Left and right quota rails: 5H 80%, 7D 65%.
for row in 0..<rows {
    setPixel(0, row, "#1C1C1E")
    setPixel(31, row, "#1C1C1E")
}
for row in 2...7 { setPixel(0, row, "#30D158") }
setPixel(0, 1, "#135423")
for row in 3...7 { setPixel(31, row, "#30D158") }
setPixel(31, 2, "#0A2A12")

// Working-state traffic light, frame 0.
let rimPoints = [
    (3, 1), (4, 1), (5, 1),
    (2, 2), (6, 2),
    (2, 3), (6, 3),
    (2, 4), (6, 4),
    (3, 5), (4, 5), (5, 5)
]
for (x, y) in rimPoints { setPixel(x, y, "#11652C") }
for y in 2...4 {
    for x in 3...5 { setPixel(x, y, "#30D158") }
}
setPixel(3, 1, "#B8F7C8")

// Two explicit blank columns separate the label from the value.
drawText("5H  80", x: 11, y: 1, hex: "#30D158")

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: imageWidth,
    pixelsHigh: imageHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to create image buffer")
}

guard let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
    fatalError("Unable to create graphics context")
}

context.setFillColor(color("#F4F4F6"))
context.fill(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

let frameRect = CGRect(
    x: framePadding / 2,
    y: framePadding / 2,
    width: imageWidth - framePadding,
    height: imageHeight - framePadding
)
context.setFillColor(color("#D8DAE0"))
context.fill(frameRect)

let panelRect = CGRect(
    x: framePadding,
    y: framePadding,
    width: panelWidth,
    height: panelHeight
)
context.setFillColor(color("#050607"))
context.fill(panelRect)
context.setStrokeColor(color("#5E6066"))
context.setLineWidth(2)
context.stroke(panelRect)

let matrixOriginX = framePadding + panelPadding
let matrixOriginY = framePadding + panelPadding
for row in 0..<rows {
    for column in 0..<columns {
        guard let hex = pixels[row][column] else { continue }
        let rect = CGRect(
            x: matrixOriginX + column * pitch,
            y: matrixOriginY + (rows - 1 - row) * pitch,
            width: cellSize,
            height: cellSize
        )
        context.setFillColor(color(hex))
        context.fill(rect)
    }
}

let outputURL = CommandLine.arguments.dropFirst().first.map {
    URL(fileURLWithPath: $0)
} ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("token-display-preview.png")
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
try png.write(to: outputURL)
print(outputURL.path)
