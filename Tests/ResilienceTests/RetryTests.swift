import Foundation
import Testing
@testable import Resilience

private enum SampleError: Error {
    case transient
    case terminal
}

@Suite
struct RetryTests {
    
    @Test
    func retriesSucceedWithinAttemptLimit() async throws {
        var attempts = 0
        let result = try await retry(config: RetryConfig(attempts: .max(3))) {
            attempts += 1
            if attempts < 3 { throw SampleError.transient }
            return "ok"
        }
        #expect(result == "ok")
        #expect(attempts == 3)
    }
    
    @Test
    func retriesExhaustAttemptLimit() async throws {
        var attempts = 0
        await #expect(throws: SampleError.transient) {
            try await retry(config: RetryConfig(attempts: .max(2))) {
                attempts += 1
                throw SampleError.transient
            }
        }
        #expect(attempts == 2)
    }
    
    @Test
    func unlimitedAttemptsCanContinueUntilSuccess() async throws {
        var attempts = 0
        let result = try await retry(config: RetryConfig(attempts: .unlimited)) {
            attempts += 1
            if attempts < 5 { throw SampleError.transient }
            return "ok"
        }
        
        #expect(result == "ok")
        #expect(attempts == 5)
    }
    
    @Test
    func elapsedLimitStopsRetrying() async throws {
        var attempts = 0
        await #expect(throws: SampleError.transient) {
            try await retry(config: RetryConfig(elapsed: .max(.zero))) {
                attempts += 1
                throw SampleError.transient
            }
        }
        #expect(attempts == 1)
    }
    
    @Test
    func decisionCanStopImmediately() async throws {
        var attempts = 0
        await #expect(throws: SampleError.transient) {
            try await retry {
                attempts += 1
                throw SampleError.transient
            } decision: { _, _ in
                .stop
            }
        }
        #expect(attempts == 1)
    }
    
    @Test(.timeLimit(.minutes(1)))
    func retryCancellationPropagates() async throws {
        let task = Task<Int, Error> {
            var attempts = 0
            try await retry(
                config: RetryConfig(attempts: .max(5)),
                operation: {
                    attempts += 1
                    throw SampleError.transient
                },
                decision: retryAfterOneSecond
            )
            return attempts
        }
        
        await Task.yield()
        task.cancel()
        
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        #expect(task.isCancelled)
    }
}

private func retryAfterOneSecond(_: Error, _: AttemptContext) -> RetryDecision {
    .retry(backoff: .constant(.seconds(1)))
}
