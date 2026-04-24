import Foundation

enum SamplingMath {
    static func delta(current: UInt64, previous: UInt64) -> UInt64? {
        guard current >= previous else { return nil }
        return current - previous
    }

    static func rate(current: UInt64, previous: UInt64, dt: TimeInterval) -> Double {
        guard dt > 0, let delta = delta(current: current, previous: previous) else { return 0 }
        return Double(delta) / dt
    }
}
