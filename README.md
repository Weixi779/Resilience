# Resilience

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2016%2B%20%7C%20macOS%2013%2B%20%7C%20tvOS%2016%2B%20%7C%20watchOS%209%2B-lightgrey.svg)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

English | [简体中文](README-zh.md)

Resilience is a lightweight Swift package for async retry and polling workflows.
It provides a small set of primitives: composable `Backoff`, explicit attempt and elapsed-time limits, and simple decision callbacks for retry and polling behavior.

This package is intentionally not a workflow engine. It stays close to Swift concurrency and keeps business decisions in your code.

## Requirements

- Swift 6.2+
- iOS 16+
- macOS 13+
- tvOS 16+
- watchOS 9+

## Installation

Add Resilience to your package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/Weixi779/Resilience.git", branch: "main")
]
```

Then add `Resilience` to the target that uses it:

```swift
.target(
    name: "YourTarget",
    dependencies: ["Resilience"]
)
```

After the first release tag is cut, prefer a versioned dependency instead of `branch: "main"`.

## Retry

Use `retry` when an operation should be attempted again after selected failures.

```swift
import Foundation
import Resilience

let networkBackoff = Backoff
    .exponential(initial: .milliseconds(200), multiplier: 2)
    .max(.seconds(5))
    .jitter(percent: 0.15)

let value = try await retry(
    config: RetryConfig(
        attempts: .max(3),
        elapsed: .max(.seconds(30))
    ),
    operation: {
        try await fetchValue()
    },
    decision: { error, _ in
        guard error is URLError else { return .stop }
        return .retry(backoff: networkBackoff)
    }
)
```

`attempts: .max(3)` includes the initial attempt, so it allows the initial operation plus up to two retries.

## Polling

Use `poll` when an operation is expected to fail with a temporary "not ready yet" state until it eventually succeeds.

```swift
import Foundation
import Resilience

enum PollError: Error {
    case pending
}

let status = try await poll(
    config: PollConfig(
        elapsed: .max(.seconds(60))
    ),
    operation: {
        let status = try await fetchStatus()
        guard status != .done else { return status }
        throw PollError.pending
    },
    decision: { error, _ in
        guard case PollError.pending = error else { return .stop }
        return .retry(backoff: .constant(.seconds(1)))
    }
)
```

`PollConfig` defaults to unlimited attempts and unlimited elapsed time. In production code, prefer setting at least an elapsed limit unless cancellation or your decision callback already provides a clear stop condition.

## Backoff

`Backoff` describes how long to wait before the next attempt.

Built-in baselines:

- `.none`
- `.constant(_:)`
- `.linear(step:offset:)`
- `.exponential(initial:multiplier:)`
- `.custom(_:)`

Built-in transforms:

- `.min(_:)`
- `.max(_:)`
- `.clamp(min:max:)`
- `.jitter(percent:)`
- `.fullJitter()`

```swift
let backoff = Backoff
    .exponential(initial: .seconds(1), multiplier: 2)
    .max(.seconds(30))
    .jitter(percent: 0.15)

let firstDelay = backoff.duration(at: 0)
let secondDelay = backoff.duration(at: 1)
```

For deterministic jitter in tests, inject your own random number generator:

```swift
var randomNumberGenerator = MyFixedRandomNumberGenerator([0, .max])
let backoff = Backoff.constant(.seconds(10)).jitter(percent: 0.1)
let delay = backoff.duration(at: 0, using: &randomNumberGenerator)
```

## Limits

Retry and polling share the same limit types:

```swift
public enum AttemptLimit {
    case max(Int)
    case unlimited
}

public enum ElapsedLimit {
    case max(Duration)
    case unlimited
}
```

`AttemptLimit.max(_:)` counts operation executions, including the initial attempt.
`ElapsedLimit.max(_:)` applies to the whole retry or polling session, including time spent in backoff sleeps.

## API Shape

The core API is intentionally small:

```swift
RetryConfig(attempts: .max(3), elapsed: .max(.seconds(30)))
RetryDecision.retry(backoff: backoff)

PollConfig(attempts: .unlimited, elapsed: .max(.seconds(60)))
PollDecision.retry(backoff: .constant(.seconds(1)))
```

Use the decision callback to decide which errors should retry and which should stop. More structured policy APIs can be layered on later without changing the core model.

## License

Resilience is available under the MIT license. See [LICENSE](LICENSE) for details.
