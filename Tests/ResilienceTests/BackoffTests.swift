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
    func jitterUsesInjectedRNG() async throws {
        // Values toggle between low/high to hit jitter bounds.
        var rng = FixedRNG([0, UInt64.max])
        let backoff = Backoff.constant(.seconds(10)).jitter(percent: 0.1)
        
        let d0 = backoff.duration(at: 0, rng: &rng)
        let d1 = backoff.duration(at: 1, rng: &rng)
        
        #expect(d0 != nil && d1 != nil)
        
        let s0 = doubleSeconds(d0!)
        let s1 = doubleSeconds(d1!)
        
        // With 10% jitter, delays should fall within [9, 11] seconds
        #expect(s0 >= 9.0 && s0 <= 11.0)
        #expect(s1 >= 9.0 && s1 <= 11.0)
    }
}

private struct FixedRNG: RandomNumberGenerator {
    var values: [UInt64]
    var index: Int = 0
    
    init(_ values: [UInt64]) {
        precondition(!values.isEmpty, "FixedRNG requires at least one value")
        self.values = values
    }
    
    mutating func next() -> UInt64 {
        defer { index = (index + 1) % values.count }
        return values[index]
    }
}

private func doubleSeconds(_ d: Duration) -> Double {
    Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
}
