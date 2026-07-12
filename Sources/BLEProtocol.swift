import Foundation

enum AWTRIXBLEClientError: LocalizedError {
    case bluetoothUnavailable
    case connectionTimedOut
    case notReady
    case transferInProgress
    case disconnected
    case invalidFrameSize(Int)
    case packetSizeTooSmall
    case invalidSettingsResponse
    case writeFailed(String)
    case deviceStatus(UInt8)

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable: return "蓝牙不可用"
        case .connectionTimedOut: return "连接 TC001 蓝牙超时"
        case .notReady: return "TC001 蓝牙尚未连接"
        case .transferInProgress: return "上一帧仍在传输"
        case .disconnected: return "TC001 蓝牙连接已断开"
        case let .invalidFrameSize(size): return "蓝牙画面长度无效（\(size) 字节）"
        case .packetSizeTooSmall: return "蓝牙数据包容量不足"
        case .invalidSettingsResponse: return "TC001 返回了无法识别的页面设置"
        case let .writeFailed(message): return "蓝牙写入失败：\(message)"
        case let .deviceStatus(code): return "TC001 拒绝了蓝牙数据（状态 \(code)）"
        }
    }
}

enum AWTRIXBLEProtocol {
    static let magic: UInt8 = 0xA3
    static let version: UInt8 = 0x01
    static let responseMask: UInt8 = 0x80
    static let frameByteCount = 32 * 8 * 2

    enum Command: UInt8 {
        case ping = 0x01
        case getStatus = 0x02
        case frameBegin = 0x10
        case frameChunk = 0x11
        case frameCommit = 0x12
        case getNativeApps = 0x20
        case setNativeApps = 0x21
    }

    struct OutboundPacket {
        let command: Command
        let requestID: UInt8
        let data: Data
    }

    struct Status {
        let command: UInt8
        let requestID: UInt8
        let statusCode: UInt8
        let connected: Bool
        let freeHeap: UInt32
        let payload: Data
    }

    static func packet(command: Command, requestID: UInt8, payload: Data = Data()) -> OutboundPacket {
        var data = Data([magic, version, command.rawValue, requestID])
        data.append(payload)
        return OutboundPacket(command: command, requestID: requestID, data: data)
    }

    static func framePayloads(
        frame: Data,
        frameID: UInt8,
        maximumPacketSize: Int,
        switchToApp: Bool
    ) throws -> [(command: Command, payload: Data)] {
        guard frame.count == frameByteCount else {
            throw AWTRIXBLEClientError.invalidFrameSize(frame.count)
        }

        let chunkSize = maximumPacketSize - 4 - 3
        guard chunkSize > 0 else {
            throw AWTRIXBLEClientError.packetSizeTooSmall
        }

        var begin = Data([frameID, 0x01])
        begin.appendLittleEndian(UInt16(frame.count))
        begin.appendLittleEndian(crc32(frame))

        var payloads: [(command: Command, payload: Data)] = [(.frameBegin, begin)]
        var offset = 0
        while offset < frame.count {
            let end = min(frame.count, offset + chunkSize)
            var chunk = Data([frameID])
            chunk.appendLittleEndian(UInt16(offset))
            chunk.append(frame[offset..<end])
            payloads.append((.frameChunk, chunk))
            offset = end
        }
        payloads.append((.frameCommit, Data([frameID, switchToApp ? 0x01 : 0x00])))
        return payloads
    }

    static func parseStatus(_ data: Data) -> Status? {
        guard data.count >= 10, data[0] == magic, data[1] == version else { return nil }
        let freeHeap = UInt32(data[6]) |
            (UInt32(data[7]) << 8) |
            (UInt32(data[8]) << 16) |
            (UInt32(data[9]) << 24)
        return Status(
            command: data[2],
            requestID: data[3],
            statusCode: data[4],
            connected: data[5] != 0,
            freeHeap: freeHeap,
            payload: Data(data.dropFirst(10))
        )
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = UInt32(bitPattern: -Int32(crc & 1))
                crc = (crc >> 1) ^ (0xEDB8_8320 & mask)
            }
        }
        return ~crc
    }
}

extension Data {
    fileprivate mutating func appendLittleEndian(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8(value >> 8))
    }

    fileprivate mutating func appendLittleEndian(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}
