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
///     .exponential(initial: .seconds(1), multiplier: 2)
///     .clamp(min: .seconds(1), max: .seconds(5))
/// ```
struct ClampTransform: BackoffTransform {
    let minValue: Duration?
    let maxValue: Duration?
    
    init(min: Duration?, max: Duration?) {
        self.minValue = min
        self.maxValue = max
    }
    
    func apply<Generator: RandomNumberGenerator>(
        to duration: Duration,
        attempt: Int,
        context: AttemptContext,
        using randomNumberGenerator: inout Generator
    ) -> Duration? {
        var clampedDuration = duration
        if let minValue, clampedDuration < minValue { clampedDuration = minValue }
        if let maxValue, clampedDuration > maxValue { clampedDuration = maxValue }
        return clampedDuration
    }
}
