import Foundation

/// Best-effort scaling: convert to seconds as Double, scale, convert back.
/// Guards against non-finite or negative factors by preconditioning.
func scaleDuration(_ d: Duration, by factor: Double) -> Duration {
    precondition(factor.isFinite && factor >= 0, "scale factor must be >= 0 and finite")
    let seconds = Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    let scaled = seconds * factor
    return .seconds(scaled)
}
