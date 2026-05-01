import Foundation
import Testing
@testable import Resilience

private enum PollError: Error {
    case pending
    case fatal
}

@Suite
struct PollTests {
    
    @Test
    func pollSucceedsAfterRetries() async throws {
        var attempts = 0
        let result = try await poll(
            operation: {
                attempts += 1
                if attempts < 3 { throw PollError.pending }
                return "done"
            },
            decision: retryPendingImmediately
        )
        #expect(result == "done")
        #expect(attempts == 3)
    }
    
    @Test
    func pollStopsOnDecisionStop() async throws {
        var attempts = 0
        await #expect(throws: PollError.fatal) {
            try await poll(
                operation: {
                    attempts += 1
                    throw PollError.fatal
                },
                decision: retryPendingImmediately
            )
        }
        #expect(attempts == 1)
    }
    
    @Test
    func pollRespectsAttemptLimit() async throws {
        var attempts = 0
        await #expect(throws: PollError.pending) {
            try await poll(
                config: PollConfig(attempts: .max(2)),
                operation: {
                    attempts += 1
                    throw PollError.pending
                },
                decision: { _, _ in .retry(backoff: .constant(.zero)) }
            )
        }
        #expect(attempts == 2)
    }
    
    @Test
    func pollRespectsElapsedLimit() async throws {
        var attempts = 0
        await #expect(throws: PollError.pending) {
            try await poll(
                config: PollConfig(elapsed: .max(.zero)),
                operation: {
                    attempts += 1
                    throw PollError.pending
                },
                decision: { _, _ in .retry(backoff: .constant(.zero)) }
            )
        }
        #expect(attempts == 1)
    }
    
    @Test(.timeLimit(.minutes(1)))
    func pollCancellationPropagates() async throws {
        let task = Task<String, Error> {
            try await poll(
                operation: {
                    throw PollError.pending
                },
                decision: retryAfterOneSecond
            )
        }
        
        await Task.yield()
        task.cancel()
        
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        #expect(task.isCancelled)
    }
}

private func retryPendingImmediately(_ error: Error, _: AttemptContext) -> PollDecision {
    guard case PollError.pending = error else { return .stop }
    return .retry(backoff: .constant(.zero))
}

private func retryAfterOneSecond(_: Error, _: AttemptContext) -> PollDecision {
    .retry(backoff: .constant(.seconds(1)))
}
