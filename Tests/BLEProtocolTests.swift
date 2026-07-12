import Foundation

@main
struct BLEProtocolTests {
    static func main() throws {
        let checksumFixture = Data("123456789".utf8)
        try check(
            AWTRIXBLEProtocol.crc32(checksumFixture) == 0xCBF4_3926,
            "CRC32 should match the standard IEEE fixture"
        )

        let frame = Data((0..<AWTRIXBLEProtocol.frameByteCount).map { UInt8($0 & 0xff) })
        let payloads = try AWTRIXBLEProtocol.framePayloads(
            frame: frame,
            frameID: 7,
            maximumPacketSize: 182,
            switchToApp: true
        )
        try check(payloads.count == 5, "a 512-byte frame should use begin, three chunks, and commit")
        try check(payloads.first?.command == .frameBegin, "first frame packet should be begin")
        try check(payloads.last?.command == .frameCommit, "last frame packet should be commit")

        var rebuilt = Data()
        var expectedOffset = 0
        for item in payloads where item.command == .frameChunk {
            try check(item.payload[0] == 7, "chunk should retain the frame id")
            let offset = Int(item.payload[1]) | (Int(item.payload[2]) << 8)
            try check(offset == expectedOffset, "chunks should be contiguous")
            rebuilt.append(item.payload.dropFirst(3))
            expectedOffset = rebuilt.count
            let packet = AWTRIXBLEProtocol.packet(command: item.command, requestID: 1, payload: item.payload)
            try check(packet.data.count <= 182, "packet should fit the negotiated MTU")
        }
        try check(rebuilt == frame, "chunk payloads should reconstruct the original frame")

        let statusData = Data([0xA3, 0x01, 0xA0, 0x2A, 0x00, 0x01, 0x78, 0x56, 0x34, 0x12, 0x15])
        guard let status = AWTRIXBLEProtocol.parseStatus(statusData) else {
            throw TestFailure("status packet should parse")
        }
        try check(status.command == 0xA0, "status should retain the response command")
        try check(status.requestID == 0x2A, "status should retain the request id")
        try check(status.connected, "status should report the connection bit")
        try check(status.freeHeap == 0x1234_5678, "status should decode little-endian heap size")
        try check(status.payload == Data([0x15]), "status should preserve command-specific payload")

        let getSettings = AWTRIXBLEProtocol.packet(command: .getNativeApps, requestID: 9)
        try check(
            getSettings.data == Data([0xA3, 0x01, 0x20, 0x09]),
            "native-app settings request should use command 0x20"
        )
        let setSettings = AWTRIXBLEProtocol.packet(
            command: .setNativeApps,
            requestID: 10,
            payload: Data([0x1F])
        )
        try check(
            setSettings.data == Data([0xA3, 0x01, 0x21, 0x0A, 0x1F]),
            "native-app settings update should carry one bit mask"
        )

        print("BLEProtocolTests: PASS")
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
