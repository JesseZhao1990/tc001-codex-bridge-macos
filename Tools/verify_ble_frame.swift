import Foundation

@main
struct VerifyBLEFrame {
    static func main() throws {
        let frame = AWTRIXClient.rgb565Frame(
            usageDisplay: .single(percent: 73),
            activity: .idle,
            animationFrame: 0,
            quotaPage: 0
        )
        let expected = stride(from: 0, to: frame.count, by: 2).map { offset -> Int in
            let value = UInt16(frame[offset]) | (UInt16(frame[offset + 1]) << 8)
            let red = Int(gamma5[Int(value >> 11)])
            let green = Int(gamma6[Int((value >> 5) & 0x3f)])
            let blue = Int(gamma5[Int(value & 0x1f)])
            return (red << 16) | (green << 8) | blue
        }

        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard let numbers = try JSONSerialization.jsonObject(with: data) as? [NSNumber] else {
            throw VerificationError.invalidScreenResponse
        }
        let actual = numbers.map(\.intValue)
        let mismatches = zip(expected, actual).enumerated().compactMap { index, pair in
            pair.0 == pair.1 ? nil : index
        }
        guard expected.count == actual.count, mismatches.isEmpty else {
            throw VerificationError.pixelMismatch(
                expectedCount: expected.count,
                actualCount: actual.count,
                indices: Array(mismatches.prefix(12))
            )
        }
        print("BLE frame verification: PASS (256/256 pixels)")
    }

    private static let gamma5: [UInt8] = [
        0x00, 0x01, 0x02, 0x03, 0x05, 0x07, 0x09, 0x0b,
        0x0e, 0x11, 0x14, 0x18, 0x1d, 0x22, 0x28, 0x2e,
        0x36, 0x3d, 0x46, 0x4f, 0x59, 0x64, 0x6f, 0x7c,
        0x89, 0x97, 0xa6, 0xb6, 0xc7, 0xd9, 0xeb, 0xff
    ]

    private static let gamma6: [UInt8] = [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x08,
        0x09, 0x0a, 0x0b, 0x0d, 0x0e, 0x10, 0x12, 0x13,
        0x15, 0x17, 0x19, 0x1b, 0x1d, 0x20, 0x22, 0x25,
        0x27, 0x2a, 0x2d, 0x30, 0x33, 0x37, 0x3a, 0x3e,
        0x41, 0x45, 0x49, 0x4d, 0x52, 0x56, 0x5b, 0x5f,
        0x64, 0x69, 0x6e, 0x74, 0x79, 0x7f, 0x85, 0x8b,
        0x91, 0x97, 0x9d, 0xa4, 0xab, 0xb2, 0xb9, 0xc0,
        0xc7, 0xcf, 0xd6, 0xde, 0xe6, 0xee, 0xf7, 0xff
    ]
}

private enum VerificationError: Error, CustomStringConvertible {
    case invalidScreenResponse
    case pixelMismatch(expectedCount: Int, actualCount: Int, indices: [Int])

    var description: String {
        switch self {
        case .invalidScreenResponse:
            return "TC001 returned an invalid screen response"
        case let .pixelMismatch(expectedCount, actualCount, indices):
            return "BLE frame mismatch: expected \(expectedCount), actual \(actualCount), pixels \(indices)"
        }
    }
}
