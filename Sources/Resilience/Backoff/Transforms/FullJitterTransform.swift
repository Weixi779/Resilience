import Foundation

/// Full jitter: scale by a random factor in `[0, 1]` (AWS-style full jitter).
///
/// Spreads retries across the whole range from 0 up to the baseline delay.
///
/// Example:
/// ```swift
/// // Uniformly in [0s, 10s]
/// let backoff = Backoff.constant(.seconds(10)).fullJitter()
/// ```
struct FullJitterTransform: BackoffTransform {
    func apply<Generator: RandomNumberGenerator>(
        to duration: Duration,
        attempt: Int,
        context: AttemptContext,
        using randomNumberGenerator: inout Generator
    ) -> Duration? {
        let factor = Double.random(in: 0.0...1.0, using: &randomNumberGenerator)
        return scaleDuration(duration, by: factor)
    }
}
