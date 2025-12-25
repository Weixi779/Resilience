import Foundation

/// Clamp duration into optional min/max bounds.
///
/// - If only `min` is set, values below it are raised.
/// - If only `max` is set, values above it are capped.
/// - If both are set, values are clamped into [min, max].
///
/// Example:
/// ```swift
/// // 1s, 2s, 4s, 5s, 5s...
/// let backoff = Backoff
///     .exponential(a: .seconds(1), factor: 2)
///     .clamp(min: .seconds(1), max: .seconds(5))
/// ```
struct ClampTransform: BackoffTransform {
    let minValue: Duration?
    let maxValue: Duration?
    
    init(min: Duration?, max: Duration?) {
        self.minValue = min
        self.maxValue = max
    }
    
    func apply<R: RandomNumberGenerator>(
        _ d: Duration,
        attempt: Int,
        context: AttemptContext,
        rng: inout R
    ) -> Duration? {
        var v = d
        if let minValue, v < minValue { v = minValue }
        if let maxValue, v > maxValue { v = maxValue }
        return v
    }
}
