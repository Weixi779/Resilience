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
    func countedRetriesSucceedWithinLimit() async throws {
        var attempts = 0
        let result = try await retry(config: RetryConfig(maxAttempts: 3)) {
            attempts += 1
            if attempts < 3 { throw SampleError.transient }
            return "ok"
        }
        #expect(result == "ok")
        #expect(attempts == 3)
    }
    
    @Test
    func countedRetriesExhaustLimit() async throws {
        var attempts = 0
        await #expect(throws: SampleError.transient) {
            try await retry(config: RetryConfig(maxAttempts: 2)) {
                attempts += 1
                throw SampleError.transient
            }
        }
        #expect(attempts == 2)
    }
    
    @Test
    func noCountRetriesRespectCap() async throws {
        var attempts = 0
        let backoff = Backoff.none
        let cfg = RetryConfig(maxAttempts: 1, maxNoCountAttempts: 1)
        
        await #expect(throws: SampleError.transient) {
            try await retry(config: cfg, operation: {
                attempts += 1
                throw SampleError.transient
            }, decision: { error, _ in
                guard case SampleError.transient = error else { return .stop }
                return .retry(counted: false, backoff: backoff)
            })
        }
        #expect(attempts == 2) // initial + one no-count retry
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
}
