import SwiftUI

struct ContentView: View {
    @StateObject private var bt = BluetoothManager()
    @State private var showHistory = false
    @State private var alertHistory: [AlertEvent] = []

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                VStack(spacing: 36) {
                    header
                    proximityRing
                    statusLabel
                    rssiBar
                    Spacer()
                    actionButtons
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory.toggle()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(events: alertHistory)
            }
        }
        .onChange(of: bt.proximityState) { _, newState in
            if newState == .movingAway || newState == .far || newState == .lost {
                alertHistory.insert(
                    AlertEvent(state: newState, date: Date()),
                    at: 0
                )
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), stateColor.opacity(0.12)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("The Loop")
                .font(.largeTitle.bold())

            Text("Tracking: \(bt.pairedDeviceName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var proximityRing: some View {
        ZStack {
            Circle()
                .stroke(stateColor.opacity(0.25), lineWidth: 2)
                .frame(width: 200, height: 200)
                .scaleEffect(bt.proximityState == .nearby ? 1.15 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: bt.proximityState
                )

            Circle()
                .fill(stateColor.opacity(0.15))
                .frame(width: 170, height: 170)

            Circle()
                .stroke(stateColor, lineWidth: 3)
                .frame(width: 170, height: 170)

            Image(systemName: bt.proximityState.systemImage)
                .font(.system(size: 64))
                .foregroundStyle(stateColor)
                .symbolEffect(.bounce, value: bt.proximityState)
        }
    }

    private var statusLabel: some View {
        VStack(spacing: 6) {
            Text(bt.proximityState.label)
                .font(.title2.bold())
                .foregroundStyle(stateColor)

            if bt.isScanning || bt.isAdvertising {
                Label("Active", systemImage: "dot.radiowaves.left.and.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rssiBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Signal Strength")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(bt.rssi) dBm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemFill)).frame(height: 8)
                    Capsule()
                        .fill(stateColor)
                        .frame(width: signalBarWidth(in: geo.size.width), height: 8)
                        .animation(.easeInOut(duration: 0.4), value: bt.rssi)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 4)
        .opacity(bt.isScanning ? 1 : 0.4)
    }

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                if bt.isScanning {
                    bt.stopAll()
                } else {
                    bt.startAll()
                }
            } label: {
                Label(
                    bt.isScanning ? "Stop Monitoring" : "Start Monitoring",
                    systemImage: bt.isScanning ? "stop.circle.fill" : "play.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(bt.isScanning ? Color.red : Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.bottom, 32)
    }

    private var stateColor: Color {
        switch bt.proximityState {
        case .idle: return .gray
        case .nearby: return .green
        case .movingAway: return .yellow
        case .far: return .orange
        case .lost: return .red
        }
    }

    private func signalBarWidth(in totalWidth: CGFloat) -> CGFloat {
        guard bt.rssi != 0 else { return 0 }
        let clamped = max(-100, min(0, bt.rssi))
        let ratio = Double(clamped + 100) / 100.0
        return totalWidth * ratio
    }
}

struct AlertEvent: Identifiable {
    let id = UUID()
    let state: ProximityState
    let date: Date
}

struct HistoryView: View {
    let events: [AlertEvent]

    var body: some View {
        NavigationStack {
            List(events) { event in
                HStack {
                    Image(systemName: event.state.systemImage)
                        .foregroundStyle(colorFor(event.state))
                    VStack(alignment: .leading) {
                        Text(event.state.label)
                            .font(.headline)
                        Text(event.date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Alert History")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No Alerts Yet",
                        systemImage: "checkmark.shield",
                        description: Text("Everything looks good so far.")
                    )
                }
            }
        }
    }

    private func colorFor(_ state: ProximityState) -> Color {
        switch state {
        case .movingAway: return .yellow
        case .far: return .orange
        case .lost: return .red
        default: return .gray
        }
    }
}

#Preview {
    ContentView()
}
