import SwiftUI

@main
struct LidPostureApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(state)
        } label: {
            Image(systemName: state.status.symbol)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.status.title)
                .font(.headline)

            Group {
                if let angle = state.lidAngle {
                    Text("Угол крышки: \(Int(angle))°")
                } else {
                    Text(state.sensorAvailable ? "Угол крышки: нет данных" : "Датчик крышки не найден")
                }
                Text(String(format: "Наклон головы от нормы: %.1f°", state.drop))
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Picker("Чувствительность", selection: $state.sensitivity) {
                ForEach(AppState.Sensitivity.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Калибровать") { state.calibrate() }
                    .keyboardShortcut("k")
                if state.status == .paused {
                    Button("Продолжить") { state.start() }
                } else {
                    Button("Пауза") { state.pause() }
                }
                Spacer()
                Button("Выйти") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 300)
    }
}
