import AppKit
import Foundation

@main
@MainActor
struct UpdateRelaunchCoordinatorTests {
    static func main() throws {
        _ = NSApplication.shared
        let parent = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        parent.beginSheet(sheet)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        try check(sheet.sheetParent === parent, "the test sheet should be attached")

        UpdateRelaunchCoordinator.dismissAttachedSheets(in: [parent, sheet])
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        try check(sheet.sheetParent == nil, "the update sheet should be dismissed")
        try check(parent.attachedSheet == nil, "the parent should no longer own a sheet")

        print("UpdateRelaunchCoordinatorTests: PASS")
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message) }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
