import CoreBluetooth
import Foundation

final class AWTRIXBLEClient: NSObject {
    enum ConnectionState: Equatable {
        case idle
        case scanning
        case connecting(String)
        case discovering(String)
        case ready(String)
        case unavailable(String)
        case failed(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }

        var title: String {
            switch self {
            case .idle: return "尚未启动"
            case .scanning: return "正在搜索 TC001"
            case .connecting: return "正在连接蓝牙"
            case .discovering: return "正在读取蓝牙服务"
            case let .ready(name): return "已连接 \(name)"
            case let .unavailable(message), let .failed(message): return message
            }
        }
    }

    var onStateChange: ((ConnectionState) -> Void)?
    var onInfoChange: ((String?) -> Void)?

    private(set) var state: ConnectionState = .idle {
        didSet {
            guard oldValue != state else { return }
            onStateChange?(state)
        }
    }
    private(set) var deviceInfo: String? {
        didSet { onInfoChange?(deviceInfo) }
    }

    private static let serviceUUID = CBUUID(string: "7a5a0001-6e2d-4b35-a8c3-9f6a11d4c001")
    private static let receiveUUID = CBUUID(string: "7a5a0002-6e2d-4b35-a8c3-9f6a11d4c001")
    private static let statusUUID = CBUUID(string: "7a5a0003-6e2d-4b35-a8c3-9f6a11d4c001")
    private static let infoUUID = CBUUID(string: "7a5a0004-6e2d-4b35-a8c3-9f6a11d4c001")

    private final class PendingTransfer {
        let packets: [AWTRIXBLEProtocol.OutboundPacket]
        let continuation: CheckedContinuation<AWTRIXBLEProtocol.Status, Error>
        var index = 0
        var timeout: DispatchWorkItem?

        init(
            packets: [AWTRIXBLEProtocol.OutboundPacket],
            continuation: CheckedContinuation<AWTRIXBLEProtocol.Status, Error>
        ) {
            self.packets = packets
            self.continuation = continuation
        }
    }

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var receiveCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var infoCharacteristic: CBCharacteristic?
    private var pendingTransfer: PendingTransfer?
    private var transferWaiters: [CheckedContinuation<Void, Never>] = []
    private var shouldRun = false
    private var requestID: UInt8 = 1
    private var frameID: UInt8 = 1

    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    func start() {
        shouldRun = true
        if central.state == .poweredOn {
            startScanning()
        }
    }

    func stop() {
        shouldRun = false
        central.stopScan()
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        failPending(with: AWTRIXBLEClientError.disconnected)
        clearPeripheral()
        state = .idle
    }

    func waitUntilReady(timeout: TimeInterval = 12) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !state.isReady {
            if case .unavailable = state {
                throw AWTRIXBLEClientError.bluetoothUnavailable
            }
            guard Date() < deadline else {
                throw AWTRIXBLEClientError.connectionTimedOut
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    @discardableResult
    func ping() async throws -> AWTRIXBLEProtocol.Status {
        try await waitUntilReady()
        return try await send([
            AWTRIXBLEProtocol.packet(command: .ping, requestID: nextRequestID())
        ])
    }

    @discardableResult
    func sendFrame(_ frame: Data, switchToApp: Bool) async throws -> AWTRIXBLEProtocol.Status {
        try await waitUntilReady()
        guard let peripheral else { throw AWTRIXBLEClientError.notReady }

        let maximumPacketSize = min(
            182,
            peripheral.maximumWriteValueLength(for: .withResponse)
        )
        let currentFrameID = nextFrameID()
        let payloads = try AWTRIXBLEProtocol.framePayloads(
            frame: frame,
            frameID: currentFrameID,
            maximumPacketSize: maximumPacketSize,
            switchToApp: switchToApp
        )
        let packets = payloads.map {
            AWTRIXBLEProtocol.packet(
                command: $0.command,
                requestID: nextRequestID(),
                payload: $0.payload
            )
        }
        return try await send(packets)
    }

    func fetchNativeAppsSettings() async throws -> NativeAppsSettings {
        try await waitUntilReady()
        let status = try await send([
            AWTRIXBLEProtocol.packet(command: .getNativeApps, requestID: nextRequestID())
        ])
        return try nativeAppsSettings(from: status)
    }

    func applyNativeAppsSettings(_ settings: NativeAppsSettings) async throws -> NativeAppsSettings {
        try await waitUntilReady()
        let status = try await send([
            AWTRIXBLEProtocol.packet(
                command: .setNativeApps,
                requestID: nextRequestID(),
                payload: Data([settings.bleMask])
            )
        ])
        return try nativeAppsSettings(from: status)
    }

    private func send(
        _ packets: [AWTRIXBLEProtocol.OutboundPacket]
    ) async throws -> AWTRIXBLEProtocol.Status {
        guard state.isReady,
              peripheral != nil,
              receiveCharacteristic != nil,
              statusCharacteristic?.isNotifying == true else {
            throw AWTRIXBLEClientError.notReady
        }
        while pendingTransfer != nil {
            await withCheckedContinuation { continuation in
                transferWaiters.append(continuation)
            }
        }
        guard state.isReady else {
            releaseTransferSlot()
            throw AWTRIXBLEClientError.notReady
        }
        guard !packets.isEmpty else {
            throw AWTRIXBLEClientError.writeFailed("没有可发送的数据")
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingTransfer = PendingTransfer(packets: packets, continuation: continuation)
            writeCurrentPacket()
        }
    }

    private func writeCurrentPacket() {
        guard let pendingTransfer,
              pendingTransfer.packets.indices.contains(pendingTransfer.index),
              let peripheral,
              let receiveCharacteristic else {
            failPending(with: AWTRIXBLEClientError.notReady)
            return
        }

        let packet = pendingTransfer.packets[pendingTransfer.index]
        guard packet.data.count <= peripheral.maximumWriteValueLength(for: .withResponse) else {
            failPending(with: AWTRIXBLEClientError.packetSizeTooSmall)
            return
        }

        pendingTransfer.timeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            self?.failPending(with: AWTRIXBLEClientError.connectionTimedOut)
        }
        pendingTransfer.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)
        peripheral.writeValue(packet.data, for: receiveCharacteristic, type: .withResponse)
    }

    private func acceptStatus(_ status: AWTRIXBLEProtocol.Status) {
        guard let pendingTransfer,
              pendingTransfer.packets.indices.contains(pendingTransfer.index) else { return }
        let expected = pendingTransfer.packets[pendingTransfer.index]
        guard status.command == (expected.command.rawValue | AWTRIXBLEProtocol.responseMask),
              status.requestID == expected.requestID else { return }

        pendingTransfer.timeout?.cancel()
        guard status.statusCode == 0 else {
            failPending(with: AWTRIXBLEClientError.deviceStatus(status.statusCode))
            return
        }

        pendingTransfer.index += 1
        if pendingTransfer.index == pendingTransfer.packets.count {
            self.pendingTransfer = nil
            releaseTransferSlot()
            pendingTransfer.continuation.resume(returning: status)
        } else {
            writeCurrentPacket()
        }
    }

    private func failPending(with error: Error) {
        guard let pendingTransfer else { return }
        pendingTransfer.timeout?.cancel()
        self.pendingTransfer = nil
        releaseTransferSlot()
        pendingTransfer.continuation.resume(throwing: error)
    }

    private func releaseTransferSlot() {
        guard !transferWaiters.isEmpty else { return }
        transferWaiters.removeFirst().resume()
    }

    private func nativeAppsSettings(
        from status: AWTRIXBLEProtocol.Status
    ) throws -> NativeAppsSettings {
        guard status.payload.count == 1 else {
            throw AWTRIXBLEClientError.invalidSettingsResponse
        }
        let mask = status.payload[0]
        guard mask & ~NativeAppsSettings.supportedBLEMask == 0 else {
            throw AWTRIXBLEClientError.invalidSettingsResponse
        }
        return NativeAppsSettings(bleMask: mask)
    }

    private func nextRequestID() -> UInt8 {
        let value = requestID
        requestID &+= 1
        if requestID == 0 { requestID = 1 }
        return value
    }

    private func nextFrameID() -> UInt8 {
        let value = frameID
        frameID &+= 1
        if frameID == 0 { frameID = 1 }
        return value
    }

    private func startScanning() {
        guard shouldRun, central.state == .poweredOn, peripheral == nil else { return }
        central.stopScan()
        state = .scanning
        central.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func clearPeripheral() {
        peripheral?.delegate = nil
        peripheral = nil
        receiveCharacteristic = nil
        statusCharacteristic = nil
        infoCharacteristic = nil
        deviceInfo = nil
    }

    private func scheduleReconnect() {
        guard shouldRun else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.startScanning()
        }
    }

    private func failDiscovery(_ error: Error?) {
        let message = error?.localizedDescription ?? "TC001 蓝牙服务不完整"
        state = .failed(message)
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
    }

    private func markReadyIfPossible() {
        guard let peripheral,
              receiveCharacteristic != nil,
              statusCharacteristic?.isNotifying == true else { return }
        state = .ready(peripheral.name ?? "AWTRIX BLE")
    }
}

extension AWTRIXBLEClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if shouldRun { startScanning() }
        case .poweredOff:
            state = .unavailable("蓝牙已关闭")
            failPending(with: AWTRIXBLEClientError.bluetoothUnavailable)
            clearPeripheral()
        case .unauthorized:
            state = .unavailable("没有蓝牙权限")
            failPending(with: AWTRIXBLEClientError.bluetoothUnavailable)
            clearPeripheral()
        case .unsupported:
            state = .unavailable("这台 Mac 不支持蓝牙")
            failPending(with: AWTRIXBLEClientError.bluetoothUnavailable)
            clearPeripheral()
        case .resetting:
            state = .unavailable("蓝牙正在重置")
            failPending(with: AWTRIXBLEClientError.bluetoothUnavailable)
            clearPeripheral()
        case .unknown:
            state = .idle
        @unknown default:
            state = .unavailable("蓝牙状态未知")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard shouldRun, self.peripheral == nil else { return }
        self.peripheral = peripheral
        central.stopScan()
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "AWTRIX BLE"
        state = .connecting(name)
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        state = .discovering(peripheral.name ?? "AWTRIX BLE")
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .failed(error?.localizedDescription ?? "TC001 蓝牙连接失败")
        clearPeripheral()
        scheduleReconnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        failPending(with: error ?? AWTRIXBLEClientError.disconnected)
        clearPeripheral()
        state = error.map { .failed($0.localizedDescription) } ?? .scanning
        scheduleReconnect()
    }
}

extension AWTRIXBLEClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            failDiscovery(error)
            return
        }
        peripheral.discoverCharacteristics(
            [Self.receiveUUID, Self.statusUUID, Self.infoUUID],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            failDiscovery(error)
            return
        }
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case Self.receiveUUID: receiveCharacteristic = characteristic
            case Self.statusUUID: statusCharacteristic = characteristic
            case Self.infoUUID: infoCharacteristic = characteristic
            default: break
            }
        }
        guard receiveCharacteristic != nil, let statusCharacteristic else {
            failDiscovery(nil)
            return
        }
        if let infoCharacteristic {
            peripheral.readValue(for: infoCharacteristic)
        }
        peripheral.setNotifyValue(true, for: statusCharacteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil else {
            failDiscovery(error)
            return
        }
        markReadyIfPossible()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        if characteristic.uuid == Self.infoUUID {
            deviceInfo = String(data: data, encoding: .utf8)
        } else if characteristic.uuid == Self.statusUUID,
                  let status = AWTRIXBLEProtocol.parseStatus(data) {
            acceptStatus(status)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            failPending(with: AWTRIXBLEClientError.writeFailed(error.localizedDescription))
        }
    }
}
