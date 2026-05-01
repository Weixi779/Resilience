import Foundation

/// Decision returned by a poll policy.
public enum PollDecision {
    /// Poll again after the given backoff.
    case retry(backoff: Backoff)
    /// Stop immediately and surface the error.
    case stop
}

/// Configuration for poll behavior.
public struct PollConfig: Equatable, Sendable {
    /// Total operation attempts, including the initial attempt.
    public var attempts: AttemptLimit
    /// Total elapsed time for the poll session.
    public var elapsed: ElapsedLimit
    
    public init(
        attempts: AttemptLimit = .unlimited,
        elapsed: ElapsedLimit = .unlimited
    ) {
        attempts.validate()
        elapsed.validate()
        
        self.attempts = attempts
        self.elapsed = elapsed
    }
}

/// Poll an async operation until it succeeds or the backoff policy stops it.
///
/// - Parameters:
///   - config: Poll configuration for attempt and elapsed limits.
///   - operation: Async operation to poll until success.
///   - decision: Policy mapping `(Error, AttemptContext)` to `PollDecision`.
/// - Returns: The successful result of `operation`.
/// - Throws: The last error when polling stops, limits are hit, or cancellation occurs.
public func poll<R>(
    config: PollConfig = PollConfig(),
    operation: () async throws -> R,
    decision: (Error, AttemptContext) -> PollDecision
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
            
            let ctx = AttemptContext(
                attemptIndex: attemptIndex,
                elapsed: elapsed
            )
            
            let backoff: Backoff
            switch decision(error, ctx) {
            case .stop:
                throw error
            case .retry(let retryBackoff):
                backoff = retryBackoff
            }
            
            guard config.attempts.allowsRetry(afterAttemptAt: attemptIndex) else {
                throw error
            }
            
            guard let delay = backoff.duration(at: attemptIndex, context: ctx) else {
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
