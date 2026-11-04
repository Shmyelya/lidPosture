import Foundation

/// Turns face samples + lid angle into a posture verdict.
///
/// The idea that makes this different from other webcam posture apps:
/// the camera sits on the lid, so tilting the screen moves the face in the frame
/// even if you didn't move. We convert the face position to an angle and add the
/// change in lid angle since calibration, so the estimate stays stable when you
/// adjust the screen.
struct PostureEngine {
    enum Verdict: Equatable {
        case needsCalibration
        case good
        case slouching
        case tooClose
        case away
    }

    struct Baseline {
        let lidAngle: Double
        let elevation: Double   // degrees, camera-relative face elevation at calibration
        let size: Double
    }

    // MARK: Tunables

    /// Vertical field of view of the built-in camera, degrees. Approximate —
    /// tune it on your Mac (see README, "Проверка компенсации").
    var verticalFOV: Double = 50
    /// +1 or −1. Flip if tilting the lid makes the corrected value drift *more*.
    var lidCompensationSign: Double = 1
    /// How many degrees the head may drop before it counts as slouching.
    var dropThreshold: Double = 6
    /// Relative face-size growth that counts as "too close" (0.15 = 15% bigger).
    var closeThreshold: Double = 0.15
    /// Smoothing factor for the exponential moving average, 0…1.
    var smoothing: Double = 0.3

    // MARK: State

    private(set) var baseline: Baseline?
    private(set) var smoothedElevation: Double?
    private(set) var smoothedSize: Double?
    private(set) var lastFaceSeen: Date?

    /// Head drop in degrees relative to calibration, after lid compensation.
    private(set) var drop: Double = 0
    private(set) var sizeChange: Double = 0

    mutating func calibrate(lidAngle: Double?) -> Bool {
        guard let elevation = smoothedElevation, let size = smoothedSize else { return false }
        baseline = Baseline(lidAngle: lidAngle ?? 0, elevation: elevation, size: size)
        return true
    }

    mutating func restoreBaseline(_ baseline: Baseline) {
        self.baseline = baseline
    }

    /// Converts a normalized vertical position into an angle from the camera axis.
    private func elevation(fromCenterY y: Double) -> Double {
        let halfFOV = verticalFOV / 2 * .pi / 180
        let angle = atan((y - 0.5) * 2 * tan(halfFOV))
        return angle * 180 / .pi
    }

    mutating func ingest(_ sample: FaceSample?, lidAngle: Double?, now: Date = Date()) -> Verdict {
        if let sample {
            let e = elevation(fromCenterY: sample.centerY)
            smoothedElevation = smoothedElevation.map { $0 + smoothing * (e - $0) } ?? e
            smoothedSize = smoothedSize.map { $0 + smoothing * (sample.size - $0) } ?? sample.size
            lastFaceSeen = now
        }

        if let lastFaceSeen, now.timeIntervalSince(lastFaceSeen) > 10 { return .away }
        if lastFaceSeen == nil { return .away }
        guard let baseline, let elevation = smoothedElevation, let size = smoothedSize else {
            return .needsCalibration
        }

        // Camera tilt since calibration. Opening the lid further tilts the camera up,
        // which makes a still face look lower in the frame — so we add it back.
        let lidDelta = (lidAngle.map { $0 - baseline.lidAngle } ?? 0) * lidCompensationSign
        let corrected = elevation + lidDelta

        drop = baseline.elevation - corrected
        sizeChange = size / baseline.size - 1

        if sizeChange > closeThreshold { return .tooClose }
        if drop > dropThreshold { return .slouching }
        return .good
    }
}
