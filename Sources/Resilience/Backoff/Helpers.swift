import Foundation

/// Best-effort scaling: convert to seconds as Double, scale, convert back.
func scaleDuration(_ d: Duration, by factor: Double) -> Duration {
    let seconds = Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    let scaled = seconds * factor
    return .seconds(scaled)
}
