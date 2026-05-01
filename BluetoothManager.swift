import CoreBluetooth
import Foundation
import UIKit

let loopServiceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")

private let rssiNearby: Int = -60
private let rssiMovingAway: Int = -75
private let rssiFar: Int = -90
private let lostTimeout: TimeInterval = 8

enum ProximityState: Equatable {
    case idle
    case nearby
    case movingAway
    case far
    case lost

    var label: String {
        switch self {
        case .idle: return "Waiting..."
        case .nearby: return "Nearby"
        case .movingAway: return "Moving Away"
        case .far: return "Far Away"
        case .lost: return "Signal Lost"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "antenna.radiowaves.left.and.right"
        case .nearby: return "checkmark.circle.fill"
        case .movingAway: return "figure.walk"
        case .far: return "exclamationmark.triangle.fill"
        case .lost: return "xmark.circle.fill"
        }
    }
}

@MainActor
final class BluetoothManager: NSObject, ObservableObject {
    @Published var proximityState: ProximityState = .idle
    @Published var rssi: Int = 0
    @Published var isAdvertising = false
    @Published var isScanning = false
    @Published var pairedDeviceName = "Your Person"

    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var lostTimer: Timer?
    private var previousState: ProximityState = .idle

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    deinit {
        lostTimer?.invalidate()
    }

    func startAll() {
        startAdvertising()
        startScanning()
    }

    func stopAll() {
        stopAdvertising()
        stopScanning()
        lostTimer?.invalidate()
        handleStateChange(.idle)
    }

    private func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }

        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [loopServiceUUID],
            CBAdvertisementDataLocalNameKey: UIDevice.current.name
        ]

        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
    }

    private func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
    }

    private func startScanning() {
        guard centralManager.state == .poweredOn else { return }

        centralManager.scanForPeripherals(
            withServices: [loopServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
    }

    private func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    private func resetLostTimer() {
        lostTimer?.invalidate()
        lostTimer = Timer.scheduledTimer(withTimeInterval: lostTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleStateChange(.lost)
            }
        }
    }

    private func handleStateChange(_ newState: ProximityState) {
        guard newState != previousState else { return }
        previousState = newState
        proximityState = newState

        switch newState {
        case .movingAway:
            NotificationManager.shared.send(
                title: "\(pairedDeviceName) is moving away",
                body: "They seem to be walking away from you."
            )
        case .far:
            NotificationManager.shared.send(
                title: "\(pairedDeviceName) is far away",
                body: "You are getting far apart. Heads up."
            )
        case .lost:
            NotificationManager.shared.send(
                title: "Signal lost",
                body: "You have lost contact with \(pairedDeviceName)."
            )
        default:
            break
        }
    }

    private func state(from rssiValue: Int) -> ProximityState {
        if rssiValue >= rssiNearby { return .nearby }
        if rssiValue >= rssiMovingAway { return .movingAway }
        if rssiValue >= rssiFar { return .far }
        return .far
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn {
                startScanning()
            } else {
                stopScanning()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssiValue = RSSI.intValue

        Task { @MainActor in
            self.rssi = rssiValue
            self.resetLostTimer()
            self.handleStateChange(self.state(from: rssiValue))

            if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
               !name.isEmpty {
                self.pairedDeviceName = name
            }
        }
    }
}

extension BluetoothManager: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            if peripheral.state == .poweredOn {
                startAdvertising()
            } else {
                stopAdvertising()
            }
        }
    }
}
