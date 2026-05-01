import Foundation

/// Composable backoff plan: baseline curve plus ordered transforms.
public struct Backoff {
    let base: (Int) -> Duration
    let transforms: [any BackoffTransform]
    
    public init(base: @escaping (Int) -> Duration, transforms: [any BackoffTransform] = []) {
        self.base = base
        self.transforms = transforms
    }
    
    /// Compute delay for a given attempt; any transform returning nil stops the chain.
    public func duration<R: RandomNumberGenerator>(
        at attempt: Int,
        context: AttemptContext? = nil,
        rng: inout R
    ) -> Duration? {
        let ctx = context ?? AttemptContext(attemptIndex: attempt)
        var value = base(attempt)
        for t in transforms {
            guard let next = t.apply(value, attempt: attempt, context: ctx, rng: &rng) else {
                return nil
            }
            value = next
        }
        return value
    }
    
    /// Convenience: compute delay using system RNG.
    public func duration(at attempt: Int, context: AttemptContext? = nil) -> Duration? {
        var rng = SystemRandomNumberGenerator()
        return duration(at: attempt, context: context, rng: &rng)
    }
}

// Baselines, transforms, and presets are defined in Backoff+*.swift files.
