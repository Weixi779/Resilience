import Foundation

/// Decision returned by a retry policy.
public enum RetryDecision {
    /// Retry after the given backoff.
    case retry(backoff: Backoff)
    /// Stop immediately and surface the error.
    case stop
}

/// Configuration for retry behavior.
public struct RetryConfig: Equatable, Sendable {
    /// Total operation attempts, including the initial attempt.
    public var attempts: AttemptLimit
    /// Total elapsed time for the retry session.
    public var elapsed: ElapsedLimit
    
    public init(
        attempts: AttemptLimit = .max(3),
        elapsed: ElapsedLimit = .unlimited
    ) {
        attempts.validate()
        elapsed.validate()
        
        self.attempts = attempts
        self.elapsed = elapsed
    }
}

/// Execute an async operation with retry logic.
///
/// - Parameters:
///   - config: Retry configuration for attempt and elapsed limits.
///   - operation: The async operation to perform.
///   - decision: Policy mapping `(Error, AttemptContext)` to `RetryDecision`.
/// - Returns: The successful result of `operation`.
/// - Throws: Final error when retries are exhausted or the policy/limits stop retries.
public func retry<R>(
    config: RetryConfig = RetryConfig(),
    operation: () async throws -> R,
    decision: (Error, AttemptContext) -> RetryDecision = { _, _ in .retry(backoff: .none) }
) async throws -> R {
    let clock = ContinuousClock()
    let start = clock.now
    
    var attemptIndex = 0
    
    while true {
        do {
            return try await operation()
        } catch {
            try Task.checkCancellation()
            
            let elapsed = clock.now - start
            if config.elapsed.isReached(by: elapsed) {
                throw error
            }
            
            let attemptContext = AttemptContext(
                attemptIndex: attemptIndex,
                elapsed: elapsed
            )
            
            switch decision(error, attemptContext) {
            case .stop:
                throw error
                
            case .retry(let backoff):
                guard config.attempts.allowsRetry(afterAttemptAt: attemptIndex) else {
                    throw error
                }
                
                guard let delay = backoff.duration(at: attemptIndex, context: attemptContext) else {
                    throw error
                }
                
                if !config.elapsed.allowsSleep(elapsed: elapsed, delay: delay) {
                    throw error
                }
                
                try Task.checkCancellation()
                try await Task.sleep(for: delay, clock: clock)
                try Task.checkCancellation()
                
                attemptIndex += 1
            }
        }
    }
}
