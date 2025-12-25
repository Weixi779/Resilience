import Foundation

/// Best-effort scaling: convert to seconds as Double, scale, convert back.
/// Returns nil for non-finite or negative factors.
func scaleDuration(_ d: Duration, by factor: Double) -> Duration? {
    guard factor.isFinite, factor >= 0 else { return nil }
    let seconds = Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    let scaled = seconds * factor
    return .seconds(scaled)
}
