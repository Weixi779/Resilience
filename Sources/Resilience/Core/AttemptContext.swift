import Foundation

/// Context for the failed operation attempt currently being handled.
public struct AttemptContext: Equatable, Sendable {
    /// Zero-based index of the failed operation attempt.
    public let attemptIndex: Int
    /// Total elapsed time since retry or poll started.
    public let elapsed: Duration
    
    public init(attemptIndex: Int, elapsed: Duration = .zero) {
        self.attemptIndex = attemptIndex
        self.elapsed = elapsed
    }
}
