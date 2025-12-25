import Foundation

/// Percentage jitter: scale by a random factor in `[1 - p, 1 + p]`.
///
/// - `percent` is clamped to be non-negative (precondition).
/// - Uses the provided RNG (generic `R`) for testability; defaults to system RNG via `Backoff.duration`.
///
/// Example:
/// ```swift
/// // Around 9s...11s uniformly distributed
/// let backoff = Backoff.constant(.seconds(10)).jitter(percent: 0.1)
/// ```
struct JitterTransform: BackoffTransform {
    let percent: Double
    
    init(percent: Double) {
        precondition(percent >= 0.0, "percent must be non-negative")
        self.percent = percent
    }
    
    func apply<R: RandomNumberGenerator>(
        _ d: Duration,
        attempt: Int,
        context: AttemptContext,
        rng: inout R
    ) -> Duration? {
        let low = max(0.0, 1.0 - percent)
        let high = 1.0 + percent
        let factor = Double.random(in: low...high, using: &rng)
        return scaleDuration(d, by: factor)
    }
}
