import Foundation

/// A transform that modifies a baseline delay.
///
/// - `apply` may return `nil` to stop the transform chain early (reserved for future behaviors).
/// - The random number generator is generic for testability; production calls can use the convenience `Backoff.duration` which injects a system generator.
public protocol BackoffTransform {
    func apply<Generator: RandomNumberGenerator>(
        to duration: Duration,
        attempt: Int,
        context: AttemptContext,
        using randomNumberGenerator: inout Generator
    ) -> Duration?
}
