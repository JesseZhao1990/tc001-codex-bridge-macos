import Foundation

@main
struct LampTestSessionTests {
    static func main() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = LampTestSession()

        session.begin(.waiting, at: start)
        let waitingGeneration = try require(
            session.deliveryGeneration(for: .waiting),
            "waiting preview should be ready for delivery"
        )
        try check(
            session.deliveryGeneration(for: .error) == nil,
            "a different activity must not confirm the preview"
        )

        session.begin(.error, at: start.addingTimeInterval(1))
        let errorGeneration = try require(
            session.deliveryGeneration(for: .error),
            "the latest preview should replace the previous one"
        )
        session.markDisplayed(
            generation: waitingGeneration,
            at: start.addingTimeInterval(2)
        )
        try check(session.visibleUntil == nil, "a stale delivery must not start the timer")

        let deliveredAt = start.addingTimeInterval(3)
        session.markDisplayed(generation: errorGeneration, at: deliveredAt)
        try check(
            session.visibleUntil == deliveredAt.addingTimeInterval(LampTestSession.visibleDuration),
            "the visible timer should start after confirmed delivery"
        )
        try check(
            !session.expireIfNeeded(at: deliveredAt.addingTimeInterval(3.9)),
            "the preview should remain visible for the full duration"
        )
        try check(
            session.expireIfNeeded(at: deliveredAt.addingTimeInterval(4)),
            "the preview should expire at its visible deadline"
        )
        try check(session.activity == nil, "expiration should restore automatic activity")

        session.begin(.waiting, at: start)
        try check(
            !session.expireIfNeeded(
                at: start.addingTimeInterval(LampTestSession.deliveryTimeout - 0.1)
            ),
            "an undelivered preview should remain pending before the timeout"
        )
        try check(
            session.expireIfNeeded(
                at: start.addingTimeInterval(LampTestSession.deliveryTimeout)
            ),
            "an undelivered preview should eventually time out"
        )

        print("LampTestSessionTests: PASS")
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw TestFailure(message) }
        return value
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
