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
            tolerance: nil,
            maxElapsed: nil,
            operation: {
                attempts += 1
                if attempts < 3 { throw PollError.pending }
                return "done"
            },
            backoff: { error, _ in
                guard case PollError.pending = error else { return nil }
                return .constant(.zero)
            }
        )
        #expect(result == "done")
        #expect(attempts == 3)
    }
    
    @Test
    func pollStopsOnNilBackoff() async throws {
        var attempts = 0
        await #expect(throws: PollError.fatal) {
            try await poll(
                tolerance: nil,
                maxElapsed: nil,
                operation: {
                    attempts += 1
                    throw PollError.fatal
                },
                backoff: { error, _ in
                    guard case PollError.pending = error else { return nil }
                    return .constant(.zero)
                }
            )
        }
        #expect(attempts == 1)
    }
}
