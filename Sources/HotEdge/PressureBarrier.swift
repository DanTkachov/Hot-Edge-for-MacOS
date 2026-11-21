import Foundation

/// Port of GNOME Shell's `Layout.PressureBarrier` accumulation logic
/// (js/ui/layout.js), which the original Hot Edge extension relies on.
///
/// Every movement that pushes "into" the edge adds pressure (capped at 15 per
/// event). Pressure older than `timeout` decays away. When the sum within the
/// window reaches the threshold, the barrier triggers once and stays
/// triggered until the pointer leaves the edge.
struct PressureBarrier {
    static let maxDistancePerEvent = 15.0

    var timeout: TimeInterval = 1.0 // HOT_EDGE_PRESSURE_TIMEOUT = 1000 ms
    private(set) var isTriggered = false
    private(set) var currentPressure = 0.0
    private var events: [(time: TimeInterval, distance: Double)] = []

    /// Pointer left the edge: start fresh.
    mutating func reset() {
        events.removeAll()
        currentPressure = 0
        isTriggered = false
    }

    /// Feed one movement event while the pointer is on the edge.
    /// - Parameters:
    ///   - across: distance moved into the edge (positive = pushing down).
    ///   - along: distance moved parallel to the edge.
    /// - Returns: `true` exactly when the barrier fires.
    mutating func hit(time: TimeInterval, across: Double, along: Double, threshold: Double) -> Bool {
        guard !isTriggered, across > 0 else { return false }

        if across >= threshold { return trigger() }

        // Ignore moves that are more parallel to the edge than into it.
        if along > across { return false }

        trim(now: time)
        let distance = min(Self.maxDistancePerEvent, across)
        events.append((time, distance))
        currentPressure += distance

        return currentPressure >= threshold ? trigger() : false
    }

    private mutating func trigger() -> Bool {
        isTriggered = true
        events.removeAll()
        currentPressure = 0
        return true
    }

    private mutating func trim(now: TimeInterval) {
        while let first = events.first, now - first.time > timeout {
            currentPressure -= first.distance
            events.removeFirst()
        }
    }
}
