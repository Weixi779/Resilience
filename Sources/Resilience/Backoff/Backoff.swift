import Foundation

/// Composable backoff plan: baseline curve plus ordered transforms.
public struct Backoff {
    let baseline: (Int) -> Duration
    let transforms: [any BackoffTransform]
    
    public init(baseline: @escaping (Int) -> Duration, transforms: [any BackoffTransform] = []) {
        self.baseline = baseline
        self.transforms = transforms
    }
    
    /// Compute delay for a given attempt; any transform returning nil stops the chain.
    public func duration<Generator: RandomNumberGenerator>(
        at attempt: Int,
        context: AttemptContext? = nil,
        using randomNumberGenerator: inout Generator
    ) -> Duration? {
        let attemptContext = context ?? AttemptContext(attemptIndex: attempt)
        var duration = baseline(attempt)
        for transform in transforms {
            guard let nextDuration = transform.apply(
                to: duration,
                attempt: attempt,
                context: attemptContext,
                using: &randomNumberGenerator
            ) else {
                return nil
            }
            duration = nextDuration
        }
        return duration
    }
    
    /// Convenience: compute delay using the system random number generator.
    public func duration(at attempt: Int, context: AttemptContext? = nil) -> Duration? {
        var randomNumberGenerator = SystemRandomNumberGenerator()
        return duration(at: attempt, context: context, using: &randomNumberGenerator)
    }
}

// Baselines, transforms, and presets are defined in Backoff+*.swift files.
