import Foundation

/// Transform pipeline: chain modifiers to clamp or jitter the baseline delay.
///
/// Transforms run in the order you chain them. Example:
/// ```swift
/// // Exponential, capped at 30s, with 15% jitter
/// let backoff = Backoff
///     .exponential(initial: .seconds(1), multiplier: 2)
///     .max(.seconds(30))
///     .jitter(percent: 0.15)
/// ```
public extension Backoff {
    
    func min(_ m: Duration) -> Backoff {
        addingTransform(ClampTransform(min: m, max: nil))
    }
    
    func max(_ m: Duration) -> Backoff {
        addingTransform(ClampTransform(min: nil, max: m))
    }
    
    func clamp(min: Duration? = nil, max: Duration? = nil) -> Backoff {
        addingTransform(ClampTransform(min: min, max: max))
    }
    
    func jitter(percent p: Double = 0.15) -> Backoff {
        addingTransform(JitterTransform(percent: p))
    }
    
    func fullJitter() -> Backoff {
        addingTransform(FullJitterTransform())
    }
    
    private func addingTransform(_ t: any BackoffTransform) -> Backoff {
        Backoff(base: base, transforms: transforms + [t])
    }
}
