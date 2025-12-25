import Foundation

/// Baseline curves: choose one to define the raw attempt→delay shape (attempt is 0-based).
/// 
/// Examples:
/// ```swift
/// // No delay
/// let b0 = Backoff.none
/// 
/// // Constant 2s delay
/// let b1 = Backoff.constant(.seconds(2))
/// 
/// // Linear: 1s, 2s, 3s...
/// let b2 = Backoff.linear(step: .seconds(1), offset: .zero)
/// 
/// // Exponential: 1s, 2s, 4s, 8s...
/// let b3 = Backoff.exponential(initial: .seconds(1), multiplier: 2)
/// ```
public extension Backoff {
    
    static var none: Backoff {
        Backoff { _ in .zero }
    }
    
    static func constant(_ d: Duration) -> Backoff {
        Backoff { _ in d }
    }
    
    /// Linear growth: `offset + step * attempt`
    static func linear(step: Duration, offset: Duration) -> Backoff {
        Backoff { attempt in
            let scaled = scaleDuration(step, by: Double(attempt))
            return scaled + offset
        }
    }
    
    /// Exponential growth: `initial * multiplier^attempt`
    static func exponential(initial: Duration, multiplier: Double) -> Backoff {
        Backoff { attempt in
            let scale = pow(multiplier, Double(attempt))
            return scaleDuration(initial, by: scale)
        }
    }
    
    static func custom(_ f: @escaping (Int) -> Duration) -> Backoff {
        Backoff(base: f)
    }
}
