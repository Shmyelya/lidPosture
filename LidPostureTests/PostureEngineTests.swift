import XCTest
@testable import LidPosture

final class PostureEngineTests: XCTestCase {
    private func engine() -> PostureEngine {
        var engine = PostureEngine()
        engine.smoothing = 1
        engine.verticalFOV = 50
        engine.dropThreshold = 6
        engine.slouchHysteresis = 2
        engine.closeThreshold = 0.15
        engine.closeHysteresis = 0.05
        return engine
    }

    private func sample(y: Double, size: Double = 0.2) -> FaceSample {
        FaceSample(centerY: y, size: size, timestamp: Date())
    }

    func testAwayBeforeAnyFace() {
        var engine = engine()
        XCTAssertEqual(engine.ingest(nil, lidAngle: 90), .away)
    }

    func testNeedsCalibrationBeforeBaseline() {
        var engine = engine()
        XCTAssertEqual(engine.ingest(sample(y: 0.5), lidAngle: 90), .needsCalibration)
    }

    func testUprightAfterCalibrationIsGood() {
        var engine = engine()
        _ = engine.ingest(sample(y: 0.5), lidAngle: 90)
        XCTAssertTrue(engine.calibrate(lidAngle: 90))
        XCTAssertEqual(engine.ingest(sample(y: 0.5), lidAngle: 90), .good)
        XCTAssertEqual(engine.drop, 0, accuracy: 0.01)
    }

    func testLowerFaceCountsAsSlouching() {
        var engine = engine()
        _ = engine.ingest(sample(y: 0.5), lidAngle: 80)
        XCTAssertTrue(engine.calibrate(lidAngle: 80))
        let verdict = engine.ingest(sample(y: 0.35), lidAngle: 80)
        XCTAssertEqual(verdict, .slouching)
        XCTAssertGreaterThan(engine.drop, engine.dropThreshold)
    }

    func testOpeningTheLidReducesApparentDrop() {
        var engine = engine()
        _ = engine.ingest(sample(y: 0.5), lidAngle: 80)
        XCTAssertTrue(engine.calibrate(lidAngle: 80))

        _ = engine.ingest(sample(y: 0.35), lidAngle: 80)
        let uncompensated = engine.drop
        _ = engine.ingest(sample(y: 0.35), lidAngle: 100)
        XCTAssertLessThan(engine.drop, uncompensated)
    }

    func testSlouchStaysUntilHeadRisesPastHysteresis() {
        var engine = engine()
        _ = engine.ingest(sample(y: 0.5), lidAngle: 90)
        XCTAssertTrue(engine.calibrate(lidAngle: 90))

        XCTAssertEqual(engine.ingest(sample(y: 0.35), lidAngle: 90), .slouching)
        XCTAssertEqual(engine.ingest(sample(y: 0.40), lidAngle: 90), .slouching)
        XCTAssertEqual(engine.ingest(sample(y: 0.48), lidAngle: 90), .good)
    }

    func testTooCloseStaysUntilDistanceFallsBack() {
        var engine = engine()
        _ = engine.ingest(sample(y: 0.5, size: 0.20), lidAngle: 90)
        XCTAssertTrue(engine.calibrate(lidAngle: 90))

        XCTAssertEqual(engine.ingest(sample(y: 0.5, size: 0.24), lidAngle: 90), .tooClose)
        XCTAssertEqual(engine.ingest(sample(y: 0.5, size: 0.225), lidAngle: 90), .tooClose)
        XCTAssertEqual(engine.ingest(sample(y: 0.5, size: 0.20), lidAngle: 90), .good)
    }
}
