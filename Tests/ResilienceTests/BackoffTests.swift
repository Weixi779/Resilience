import Foundation
import Testing
@testable import Resilience

@Suite
struct BackoffTests {
    
    @Test
    func linearBackoff() async throws {
        let backoff = Backoff.linear(step: .seconds(1), offset: .seconds(2))
        #expect(backoff.duration(at: 0) == .seconds(2))
        #expect(backoff.duration(at: 1) == .seconds(3))
        #expect(backoff.duration(at: 2) == .seconds(4))
    }
    
    @Test
    func exponentialBackoff() async throws {
        let backoff = Backoff.exponential(initial: .milliseconds(500), multiplier: 2.0)
        #expect(backoff.duration(at: 0) == .milliseconds(500))
        #expect(backoff.duration(at: 1) == .milliseconds(1000))
        #expect(backoff.duration(at: 2) == .milliseconds(2000))
    }
    
    @Test
    func clampMaxStopsGrowth() async throws {
        let backoff = Backoff
            .exponential(initial: .seconds(1), multiplier: 2)
            .max(.seconds(3))
        
        #expect(backoff.duration(at: 0) == .seconds(1))
        #expect(backoff.duration(at: 1) == .seconds(2))
        #expect(backoff.duration(at: 2) == .seconds(3))
        #expect(backoff.duration(at: 3) == .seconds(3))
    }
    
    @Test
    func jitterUsesInjectedRandomNumberGenerator() async throws {
        // Values toggle between low/high to hit jitter bounds.
        var randomNumberGenerator = FixedRandomNumberGenerator([0, UInt64.max])
        let backoff = Backoff.constant(.seconds(10)).jitter(percent: 0.1)
        
        let firstDelay = try #require(backoff.duration(at: 0, using: &randomNumberGenerator))
        let secondDelay = try #require(backoff.duration(at: 1, using: &randomNumberGenerator))
        
        let firstSeconds = doubleSeconds(firstDelay)
        let secondSeconds = doubleSeconds(secondDelay)
        
        // With 10% jitter, delays should fall within [9, 11] seconds
        #expect(firstSeconds >= 9.0 && firstSeconds <= 11.0)
        #expect(secondSeconds >= 9.0 && secondSeconds <= 11.0)
    }
}

private struct FixedRandomNumberGenerator: RandomNumberGenerator {
    var values: [UInt64]
    var index: Int = 0
    
    init(_ values: [UInt64]) {
        precondition(!values.isEmpty, "FixedRandomNumberGenerator requires at least one value")
        self.values = values
    }
    
    mutating func next() -> UInt64 {
        defer { index = (index + 1) % values.count }
        return values[index]
    }
}

private func doubleSeconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
}
