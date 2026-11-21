import Foundation

/// `HotEdge --selftest` checks the pressure logic without needing a mouse.
enum SelfTest {
    static func run() -> Bool {
        var failures = 0
        func check(_ cond: Bool, _ name: String) {
            print(cond ? "  ok  \(name)" : "  FAIL \(name)")
            if !cond { failures += 1 }
        }

        do { // Small pushes accumulate until the threshold (15 cap per event).
            var b = PressureBarrier()
            var firedAt: Int?
            for i in 0..<20 where firedAt == nil {
                if b.hit(time: Double(i) * 0.02, across: 20, along: 0, threshold: 150) { firedAt = i }
            }
            check(firedAt == 9, "fires after 10 capped events of 15 (150 total)")
        }
        do { // Fires once, then stays quiet until the pointer leaves.
            var b = PressureBarrier()
            _ = b.hit(time: 0, across: 200, along: 0, threshold: 150)
            check(b.isTriggered, "single big push fires immediately")
            check(!b.hit(time: 0.1, across: 200, along: 0, threshold: 150), "no re-trigger while still on edge")
            b.reset()
            check(b.hit(time: 0.2, across: 200, along: 0, threshold: 150), "re-arms after leaving the edge")
        }
        do { // Pressure older than 1 s decays.
            var b = PressureBarrier()
            var fired = false
            for i in 0..<30 { fired = fired || b.hit(time: Double(i) * 0.5, across: 10, along: 0, threshold: 150) }
            check(!fired, "slow drift (2 events/s) never fires")
            check(b.currentPressure <= 30, "old pressure is trimmed")
        }
        do { // Sideways sliding along the edge is ignored.
            var b = PressureBarrier()
            var fired = false
            for i in 0..<50 { fired = fired || b.hit(time: Double(i) * 0.01, across: 2, along: 10, threshold: 150) }
            check(!fired, "sliding along the edge doesn't fire")
        }
        do { // Upward movement never counts.
            var b = PressureBarrier()
            check(!b.hit(time: 0, across: -500, along: 0, threshold: 150), "moving away doesn't fire")
            check(b.hit(time: 0, across: 1, along: 0, threshold: 0), "threshold 0 fires on any push")
        }

        print(failures == 0 ? "All self-tests passed." : "\(failures) self-test(s) failed.")
        return failures == 0
    }
}
