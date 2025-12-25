import Foundation

/// Safety helpers for Backoff baseline parameters.
extension Backoff {
    /// Validate that a duration is non-negative (best-effort).
    static func preconditionNonNegative(_ d: Duration, name: String) {
        precondition(d >= .zero, "\(name) must be >= 0")
    }
    
    /// Validate that a multiplier is positive and finite.
    static func preconditionPositiveFinite(_ m: Double, name: String) {
        precondition(m.isFinite && m > 0, "\(name) must be > 0 and finite")
    }
}
