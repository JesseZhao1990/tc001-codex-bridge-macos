import Foundation

@main
struct BLEClientProbe {
    static func main() {
        let client = AWTRIXBLEClient()
        client.onStateChange = { state in
            print("BLE state: \(state.title)")
        }
        client.start()

        Task { @MainActor in
            do {
                try await client.waitUntilReady()
                let settings = try await client.fetchNativeAppsSettings()
                print("Native apps mask: \(String(format: "0x%02X", settings.bleMask))")

                if let maskIndex = CommandLine.arguments.firstIndex(of: "--mask"),
                   CommandLine.arguments.indices.contains(maskIndex + 1),
                   let mask = UInt8(
                       CommandLine.arguments[maskIndex + 1]
                           .replacingOccurrences(of: "0x", with: ""),
                       radix: 16
                   ) {
                    let applied = try await client.applyNativeAppsSettings(
                        NativeAppsSettings(bleMask: mask)
                    )
                    print("Applied native apps mask: \(String(format: "0x%02X", applied.bleMask))")
                }

                let frame = AWTRIXClient.rgb565Frame(
                    usageDisplay: .codexQuotas(fiveHour: 54, sevenDay: 79),
                    activity: .idle,
                    animationFrame: 0,
                    quotaPage: 0
                )
                let status = try await client.sendFrame(frame, switchToApp: true)
                print("Frame committed; freeHeap=\(status.freeHeap)")
                client.stop()
                exit(EXIT_SUCCESS)
            } catch {
                fputs("BLE client probe failed: \(error.localizedDescription)\n", stderr)
                client.stop()
                exit(EXIT_FAILURE)
            }
        }

        RunLoop.main.run(until: Date().addingTimeInterval(30))
        fputs("BLE client probe timed out\n", stderr)
        exit(EXIT_FAILURE)
    }
}
