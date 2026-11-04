import Foundation
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    enum Status: Equatable {
        case starting, noCamera, needsCalibration, good, slouching, tooClose, away, paused

        var title: String {
            switch self {
            case .starting: return "Запуск…"
            case .noCamera: return "Нет доступа к камере"
            case .needsCalibration: return "Сядь ровно и нажми «Калибровать»"
            case .good: return "Осанка в порядке"
            case .slouching: return "Сутулишься"
            case .tooClose: return "Слишком близко к экрану"
            case .away: return "Тебя не видно"
            case .paused: return "Пауза"
            }
        }

        var symbol: String {
            switch self {
            case .good: return "figure.stand"
            case .slouching, .tooClose: return "figure.fall"
            case .paused: return "pause.circle"
            case .away: return "person.slash"
            default: return "figure.stand.line.dotted.figure.stand"
            }
        }
    }

    enum Sensitivity: String, CaseIterable, Identifiable {
        case low = "Низкая", medium = "Средняя", high = "Высокая"
        var id: String { rawValue }
        var dropThreshold: Double {
            switch self { case .low: return 9; case .medium: return 6; case .high: return 4 }
        }
    }

    @Published private(set) var status: Status = .starting
    @Published private(set) var lidAngle: Double?
    @Published private(set) var drop: Double = 0
    @Published private(set) var sensorAvailable = false
    @Published var sensitivity: Sensitivity = .medium {
        didSet {
            engine.dropThreshold = sensitivity.dropThreshold
            UserDefaults.standard.set(sensitivity.rawValue, forKey: Keys.sensitivity)
        }
    }

    /// Bad posture must last this long before we nudge.
    let alertDelay: TimeInterval = 15
    /// Minimum gap between two notifications.
    let alertCooldown: TimeInterval = 120

    private enum Keys {
        static let sensitivity = "sensitivity"
        static let baselineLid = "baseline.lidAngle"
        static let baselineElevation = "baseline.elevation"
        static let baselineSize = "baseline.size"
    }

    private var engine = PostureEngine()
    private let tracker = FaceTracker()
    private let lidSensor = LidAngleSensor()
    private var lidTimer: Timer?
    private var badSince: Date?
    private var lastAlert = Date.distantPast
    private var isPaused = false

    init() {
        sensorAvailable = lidSensor != nil
        if let raw = UserDefaults.standard.string(forKey: Keys.sensitivity),
           let saved = Sensitivity(rawValue: raw) {
            sensitivity = saved
        } else {
            engine.dropThreshold = sensitivity.dropThreshold
        }
        if let baseline = Self.loadBaseline() {
            engine.restoreBaseline(baseline)
        }
        tracker.onSample = { [weak self] sample in
            Task { @MainActor in self?.handle(sample) }
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        start()
    }

    func start() {
        isPaused = false
        status = .starting
        lidTimer?.invalidate()
        lidTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.lidAngle = self?.lidSensor?.read() }
        }
        Task {
            do { try await tracker.start() } catch { status = .noCamera }
        }
    }

    func pause() {
        isPaused = true
        tracker.stop()
        lidTimer?.invalidate()
        status = .paused
        badSince = nil
    }

    func calibrate() {
        if engine.calibrate(lidAngle: lidAngle) {
            if let baseline = engine.baseline {
                Self.saveBaseline(baseline)
            }
            badSince = nil
            status = .good
        }
    }

    private static func loadBaseline() -> PostureEngine.Baseline? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Keys.baselineSize) != nil else { return nil }
        let size = defaults.double(forKey: Keys.baselineSize)
        guard size > 0 else { return nil }
        return PostureEngine.Baseline(
            lidAngle: defaults.double(forKey: Keys.baselineLid),
            elevation: defaults.double(forKey: Keys.baselineElevation),
            size: size
        )
    }

    private static func saveBaseline(_ baseline: PostureEngine.Baseline) {
        let defaults = UserDefaults.standard
        defaults.set(baseline.lidAngle, forKey: Keys.baselineLid)
        defaults.set(baseline.elevation, forKey: Keys.baselineElevation)
        defaults.set(baseline.size, forKey: Keys.baselineSize)
    }

    private func handle(_ sample: FaceSample?) {
        guard !isPaused else { return }
        let verdict = engine.ingest(sample, lidAngle: lidAngle)
        drop = engine.drop

        switch verdict {
        case .needsCalibration: status = .needsCalibration
        case .away: status = .away; badSince = nil
        case .good: status = .good; badSince = nil
        case .slouching: status = .slouching; trackBad()
        case .tooClose: status = .tooClose; trackBad()
        }
    }

    private func trackBad() {
        let now = Date()
        if badSince == nil { badSince = now }
        guard let badSince,
              now.timeIntervalSince(badSince) >= alertDelay,
              now.timeIntervalSince(lastAlert) >= alertCooldown else { return }
        lastAlert = now
        notify(status == .tooClose ? "Отодвинься от экрана" : "Выпрями спину")
    }

    private func notify(_ text: String) {
        let content = UNMutableNotificationContent()
        content.title = "LidPosture"
        content.body = text
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
