import Foundation

/// Limit for total operation attempts, including the initial attempt.
public enum AttemptLimit: Equatable, Sendable {
    /// Allow at most the given number of attempts. The value must be greater than zero.
    case max(Int)
    /// Do not limit attempts by count.
    case unlimited
}

/// Limit for total elapsed time.
public enum ElapsedLimit: Equatable, Sendable {
    /// Allow at most the given elapsed duration. The value must be non-negative.
    case max(Duration)
    /// Do not limit elapsed time.
    case unlimited
}

extension AttemptLimit {
    func validate() {
        if case .max(let attempts) = self {
            precondition(attempts > 0, "AttemptLimit.max must be > 0")
        }
    }
    
    func allowsRetry(afterAttemptAt attemptIndex: Int) -> Bool {
        validate()
        
        switch self {
        case .max(let attempts):
            return attemptIndex + 1 < attempts
        case .unlimited:
            return true
        }
    }
}

extension ElapsedLimit {
    func validate() {
        if case .max(let elapsed) = self {
            precondition(elapsed >= .zero, "ElapsedLimit.max must be >= 0")
        }
    }
    
    func isReached(by elapsed: Duration) -> Bool {
        validate()
        
        switch self {
        case .max(let limit):
            return elapsed >= limit
        case .unlimited:
            return false
        }
    }
    
    func allowsSleep(elapsed: Duration, delay: Duration) -> Bool {
        validate()
        
        switch self {
        case .max(let limit):
            return elapsed + delay <= limit
        case .unlimited:
            return true
        }
    }
}
