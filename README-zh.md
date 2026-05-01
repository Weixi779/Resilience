# Resilience

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2016%2B%20%7C%20macOS%2013%2B%20%7C%20tvOS%2016%2B%20%7C%20watchOS%209%2B-lightgrey.svg)](README.md#requirements)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) | 简体中文

Resilience 是一个轻量的 Swift async retry / polling 工具库。
它只提供少量核心原语：可组合的 `Backoff`、明确的次数和耗时限制，以及用于 retry 和 polling 的 decision callback。

这个库不试图成为流程编排框架。它尽量贴近 Swift concurrency，把业务判断留在调用方代码里。

## 环境要求

- Swift 6.2+
- iOS 16+
- macOS 13+
- tvOS 16+
- watchOS 9+

## 安装

在 Swift Package 依赖中加入 Resilience：

```swift
dependencies: [
    .package(url: "https://github.com/Weixi779/Resilience.git", branch: "main")
]
```

然后在需要使用的 target 中加入依赖：

```swift
.target(
    name: "YourTarget",
    dependencies: ["Resilience"]
)
```

第一个 release tag 打好之后，建议改成基于版本号的依赖，而不是 `branch: "main"`。

## Retry

当一个异步操作在特定错误下需要重新执行时，使用 `retry`。

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

`attempts: .max(3)` 包含第一次执行，所以它表示初始执行 1 次，最多再 retry 2 次。

## Polling

当一个异步操作会先进入“暂未完成”状态，并需要持续等待直到成功时，使用 `poll`。

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

`PollConfig` 默认不限制 attempts，也不限制 elapsed。生产代码里建议至少设置一个 elapsed 限制，除非 cancellation 或 decision callback 已经能明确停止。

## Backoff

`Backoff` 描述下一次 attempt 前需要等待多久。

内置基线：

- `.none`
- `.constant(_:)`
- `.linear(step:offset:)`
- `.exponential(initial:multiplier:)`
- `.custom(_:)`

内置变换：

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

测试中如果需要稳定的 jitter 结果，可以注入自己的随机数生成器：

```swift
var rng = MyFixedRNG([0, .max])
let backoff = Backoff.constant(.seconds(10)).jitter(percent: 0.1)
let delay = backoff.duration(at: 0, rng: &rng)
```

## Limits

Retry 和 polling 共用同一组限制模型：

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

`AttemptLimit.max(_:)` 统计的是 operation 的执行次数，包含第一次执行。
`ElapsedLimit.max(_:)` 限制的是整个 retry 或 polling 会话的总耗时，包含 backoff sleep 的时间。

## API 形态

核心 API 保持很小：

```swift
RetryConfig(attempts: .max(3), elapsed: .max(.seconds(30)))
RetryDecision.retry(backoff: backoff)

PollConfig(attempts: .unlimited, elapsed: .max(.seconds(60)))
PollDecision.retry(backoff: .constant(.seconds(1)))
```

调用方通过 decision callback 决定哪些错误继续 retry，哪些错误直接 stop。更结构化的 policy API 可以后续再叠加，但第一版核心模型先保持克制。

## License

Resilience 使用 MIT License。详情见 [LICENSE](LICENSE)。
