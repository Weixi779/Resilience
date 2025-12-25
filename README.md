# Resilience

Composable backoff + retry/poll utilities.

## Backoff
- Baselines (attempt is 0-based): `.none`, `.constant(_:)`, `.linear(step:offset:)`, `.exponential(initial:multiplier:)`, `.custom`.
- Transforms (chained in order): `.min`, `.max`, `.clamp`, `.jitter(percent:)`, `.fullJitter()`.
- Example:
```swift
let backoff = Backoff
    .exponential(initial: .seconds(1), multiplier: 2)
    .max(.seconds(30))
    .jitter(percent: 0.15)

let d0 = backoff.duration(at: 0) // ~1s with jitter
let d1 = backoff.duration(at: 1) // ~2s with jitter
```
- Deterministic jitter for tests:
```swift
var rng = MyFixedRNG([0, .max])
let backoff = Backoff.constant(.seconds(10)).jitter(percent: 0.1)
let d = backoff.duration(at: 0, rng: &rng) // deterministic
```

## Retry
- Config: `RetryConfig(maxAttempts, maxNoCountAttempts, maxElapsed?, tolerance?)`. Default `maxNoCountAttempts = 0` (no unbounded no-count retries).
- Decision: `(Error, AttemptContext) -> RetryDecision` where `RetryDecision = .retry(counted: Bool, backoff: Backoff) | .stop`.
- Example:
```swift
let result = try await retry(
    config: RetryConfig(maxAttempts: 3),
    operation: { try await doWork() },
    decision: { error, _ in
        // count budget for business errors; no-count for transient if you set a cap
        if error is URLError { return .retry(counted: false, backoff: .standard) }
        return .retry(counted: true, backoff: .standard)
    }
)
```

## Poll
- Signature: `poll(tolerance:maxElapsed:operation:backoff:)` where `backoff` returns a `Backoff?` (nil = stop/propagate error).
- Example:
```swift
try await poll(
    operation: {
        let status = try await fetchStatus()
        guard status != .done else { return status }
        throw PollError.pending
    },
    backoff: { error, _ in
        guard case PollError.pending = error else { return nil }
        return .constant(.seconds(1))
    }
)
```
