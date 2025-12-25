import Foundation

/// Full jitter: scale by a random factor in `[0, 1]` (AWS-style full jitter).
///
/// Spreads retries across the whole range from 0 up to the base delay.
///
/// Example:
/// ```swift
/// // Uniformly in [0s, 10s]
/// let backoff = Backoff.constant(.seconds(10)).fullJitter()
/// ```
struct FullJitterTransform: BackoffTransform {
    func apply<R: RandomNumberGenerator>(
        _ d: Duration,
        attempt: Int,
        context: AttemptContext,
        rng: inout R
    ) -> Duration? {
        let factor = Double.random(in: 0.0...1.0, using: &rng)
        return scaleDuration(d, by: factor)
    }
}
