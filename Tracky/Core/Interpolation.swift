import Foundation

/// Time and value interpolation helpers.
///
/// GPS samples arrive roughly ten times a second, so a car passing 100 km/h is
/// almost never sampled exactly at 100 km/h. Every threshold in Tracky is
/// resolved by interpolating between the two samples that straddle it instead
/// of waiting for a sample that happens to match.
enum Interpolation {

    /// Linear blend between two values. `t` is not clamped.
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    /// Where `value` sits between `from` and `to`, as 0...1.
    /// Returns 0 when the span is degenerate.
    static func fraction(from: Double, to: Double, value: Double) -> Double {
        let span = to - from
        guard abs(span) > 1e-12 else { return 0 }
        return (value - from) / span
    }

    /// Solves for the x where the straight line through (x0, y0) and (x1, y1)
    /// equals `target`.
    ///
    /// Unclamped on purpose: the launch detector uses it to project *backwards*
    /// past the first sample to estimate the instant the car started moving.
    /// Returns nil when the line is flat and never reaches the target.
    static func crossing(x0: Double, y0: Double, x1: Double, y1: Double, target: Double) -> Double? {
        let dy = y1 - y0
        guard abs(dy) > 1e-12 else { return nil }
        let t = (target - y0) / dy
        guard t.isFinite else { return nil }
        let x = x0 + (x1 - x0) * t
        return x.isFinite ? x : nil
    }

    /// Same as `crossing`, but only when the target actually lies between the
    /// two samples. This is what finish detection uses.
    static func bracketedCrossing(
        x0: Double, y0: Double,
        x1: Double, y1: Double,
        target: Double
    ) -> Double? {
        let low = Swift.min(y0, y1)
        let high = Swift.max(y0, y1)
        guard target >= low, target <= high else { return nil }
        if abs(y1 - y0) <= 1e-12 { return x0 }
        return crossing(x0: x0, y0: y0, x1: x1, y1: y1, target: target)
    }

    /// Value of a second channel at the moment the first channel crossed its
    /// target. Used to read off distance at a speed threshold, or speed at a
    /// distance threshold (the trap speed).
    static func companionValue(
        at x: Double,
        x0: Double, x1: Double,
        v0: Double, v1: Double
    ) -> Double {
        let span = x1 - x0
        guard abs(span) > 1e-12 else { return v1 }
        return lerp(v0, v1, (x - x0) / span)
    }
}
