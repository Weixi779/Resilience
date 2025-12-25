import Foundation

/// Poll an async operation until it succeeds or the backoff policy stops it.
///
/// - Parameters:
///   - tolerance: Optional sleep tolerance.
///   - maxElapsed: Optional total elapsed limit for polling session.
///   - operation: Async operation to poll until success.
///   - backoff: Maps `(Error, AttemptContext)` to a `Backoff`; returning `nil` stops polling.
/// - Returns: The successful result of `operation`.
/// - Throws: The last error when backoff returns `nil`, elapsed limit is hit, or cancellation occurs.
public func poll<R>(
    tolerance: Duration? = nil,
    maxElapsed: Duration? = nil,
    operation: () async throws -> R,
    backoff: (Error, AttemptContext) -> Backoff?
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
            if let maxElapsed, elapsed >= maxElapsed {
                throw error
            }
            
            let ctx = AttemptContext(
                attemptIndex: attemptIndex,
                countedAttempts: attemptIndex,
                elapsed: elapsed
            )
            
            guard let strategy = backoff(error, ctx),
                  let delay = strategy.duration(at: attemptIndex, context: ctx)
            else {
                throw error
            }
            
            if let maxElapsed, elapsed + delay > maxElapsed {
                throw error
            }
            
            try Task.checkCancellation()
            try await Task.sleep(for: delay, tolerance: tolerance, clock: clock)
            try Task.checkCancellation()
            
            attemptIndex += 1
        }
    }
}
