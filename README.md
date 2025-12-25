# Resilience

Composable backoff utilities (baseline curve + transform chain).

## Quick example
```swift
import Resilience

// Exponential backoff with cap and jitter
let backoff = Backoff
    .exponential(initial: .seconds(1), multiplier: 2)
    .max(.seconds(30))
    .jitter(percent: 0.15)

let d0 = backoff.duration(at: 0) // ~1s with jitter
let d1 = backoff.duration(at: 1) // ~2s with jitter
```

## Building your own
- Baselines: `.none`, `.constant(_:)`, `.linear(step:offset:)`, `.exponential(initial:multiplier:)`, `.custom { attempt in ... }`
- Transforms (order matters): `.min`, `.max`, `.clamp`, `.jitter(percent:)`, `.fullJitter()`

## Testing with deterministic RNG
```swift
var rng = MyFixedRNG([0, .max])
let backoff = Backoff.constant(.seconds(10)).jitter(percent: 0.1)
let d = backoff.duration(at: 0, rng: &rng) // deterministic
```
