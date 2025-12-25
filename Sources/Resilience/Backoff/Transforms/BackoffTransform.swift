import Foundation

/// A transform that modifies a baseline delay.
///
/// - `apply` may return `nil` to stop the transform chain early (reserved for future behaviors).
/// - The RNG is generic for testability; production calls can use the convenience `Backoff.duration` which injects a system RNG.
public protocol BackoffTransform {
    func apply<R: RandomNumberGenerator>(
        _ d: Duration,
        attempt: Int,
        context: AttemptContext,
        rng: inout R
    ) -> Duration?
}
