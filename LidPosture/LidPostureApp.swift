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

            DisclosureGroup("Настройки") {
                VStack(alignment: .leading, spacing: 8) {
                    labeledPicker("Ждать перед уведомлением", selection: $state.alertDelay) {
                        Text("10 с").tag(10.0)
                        Text("15 с").tag(15.0)
                        Text("30 с").tag(30.0)
                    }
                    labeledPicker("Пауза между уведомлениями", selection: $state.alertCooldown) {
                        Text("1 мин").tag(60.0)
                        Text("2 мин").tag(120.0)
                        Text("5 мин").tag(300.0)
                    }
                    labeledPicker("Угол обзора камеры", selection: $state.verticalFOV) {
                        Text("40°").tag(40.0)
                        Text("50°").tag(50.0)
                        Text("60°").tag(60.0)
                    }
                    Toggle("Инвертировать компенсацию крышки", isOn: $state.lidCompensationFlipped)
                        .font(.callout)
                }
                .padding(.top, 6)
            }

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

            Button("Сбросить калибровку") { state.resetCalibration() }
                .disabled(!state.isCalibrated)
                .font(.callout)
        }
        .padding()
        .frame(width: 320)
    }

    private func labeledPicker<Content: View>(
        _ title: String,
        selection: Binding<Double>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) { content() }
                .labelsHidden()
                .pickerStyle(.segmented)
        }
    }
}
