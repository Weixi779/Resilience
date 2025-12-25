import Foundation

/// Decision returned by a retry policy.
public enum RetryDecision {
    /// Retry after the given backoff; `counted` controls whether it consumes `maxAttempts`.
    case retry(counted: Bool, backoff: Backoff)
    /// Stop immediately and surface the error.
    case stop
}

/// Configuration for retry behavior.
public struct RetryConfig {
    /// Maximum number of counted attempts (including the initial attempt). Must be > 0.
    public var maxAttempts: Int
    /// Optional cap for non-counted retries (defaults to unlimited).
    public var maxNoCountAttempts: Int?
    /// Optional maximum total elapsed time for the whole retry session.
    public var maxElapsed: Duration?
    /// Optional sleep tolerance passed to `Task.sleep`.
    public var tolerance: Duration?
    
    public init(
        maxAttempts: Int = 3,
        maxNoCountAttempts: Int? = nil,
        maxElapsed: Duration? = nil,
        tolerance: Duration? = nil
    ) {
        precondition(maxAttempts > 0, "maxAttempts must be > 0")
        if let maxNoCountAttempts {
            precondition(maxNoCountAttempts >= 0, "maxNoCountAttempts must be >= 0 when provided")
        }
        self.maxAttempts = maxAttempts
        self.maxNoCountAttempts = maxNoCountAttempts
        self.maxElapsed = maxElapsed
        self.tolerance = tolerance
    }
}

/// Execute an async operation with retry logic.
///
/// - Parameters:
///   - config: Retry configuration (attempt limits, elapsed limit, tolerance).
///   - operation: The async operation to perform.
///   - decision: Policy mapping `(Error, AttemptContext)` to `RetryDecision`.
/// - Returns: The successful result of `operation`.
/// - Throws: Final error when retries are exhausted or the policy/limits stop retries.
public func retry<R>(
    config: RetryConfig = RetryConfig(),
    operation: () async throws -> R,
    decision: (Error, AttemptContext) -> RetryDecision = { _, _ in .retry(counted: true, backoff: .none) }
) async throws -> R {
    let clock = ContinuousClock()
    let start = clock.now
    
    var attemptIndex = 0
    var countedAttempts = 0
    var noCountAttempts = 0
    
    while true {
        do {
            return try await operation()
        } catch {
            try Task.checkCancellation()
            
            let elapsed = clock.now - start
            if let maxElapsed = config.maxElapsed, elapsed >= maxElapsed {
                throw error
            }
            
            let ctx = AttemptContext(
                attemptIndex: attemptIndex,
                countedAttempts: countedAttempts,
                elapsed: elapsed
            )
            
            switch decision(error, ctx) {
            case .stop:
                throw error
                
            case .retry(let counted, let backoff):
                // Enforce no-count cap if configured
                if !counted, let maxNoCount = config.maxNoCountAttempts, noCountAttempts >= maxNoCount {
                    throw error
                }
                
                guard let delay = backoff.duration(at: attemptIndex, context: ctx) else {
                    throw error
                }
                
                if counted {
                    if countedAttempts >= config.maxAttempts - 1 {
                        throw error
                    }
                    countedAttempts += 1
                } else {
                    noCountAttempts += 1
                }
                
                if let maxElapsed = config.maxElapsed, elapsed + delay > maxElapsed {
                    throw error
                }
                
                try Task.checkCancellation()
                try await Task.sleep(for: delay, tolerance: config.tolerance, clock: clock)
                try Task.checkCancellation()
                
                attemptIndex += 1
            }
        }
    }
}
