import Foundation
import IOKit
import IOKit.ps
import Combine

/// Transient things the collapsed pill announces and then forgets.
enum PillAlert: Equatable {
    case pluggedIn(level: Int)
    case unplugged(level: Int)
    case bluetooth(name: String, level: Int)
}

/// Battery, charging state, and Bluetooth accessory battery (AirPods et al).
///
/// Battery comes from IOKit's power-source notifications, so plug/unplug registers
/// immediately rather than on a poll. Accessory battery is polled separately — see
/// `accessoryBatteries()` for why it goes through system_profiler.
final class PowerMonitor: ObservableObject {
    @Published private(set) var level: Int = 100
    @Published private(set) var isCharging = false
    @Published private(set) var isPluggedIn = false
    @Published private(set) var alert: PillAlert?

    private var runLoopSource: CFRunLoopSource?
    private var accessoryTimer: Timer?
    private var knownAccessories: Set<String> = []
    private var alertWork: DispatchWorkItem?
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        refresh(announce: false)
        scanAccessories(announce: false)

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { monitor.refresh(announce: true) }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        accessoryTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: true) { [weak self] _ in
            self?.scanAccessories(announce: true)
        }
    }

    // MARK: - Battery

    private func refresh(announce: Bool) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            guard (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            let plugged = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let percent = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : 0

            let plugChanged = plugged != isPluggedIn
            level = percent
            isCharging = charging
            isPluggedIn = plugged

            if announce, plugChanged {
                show(plugged ? .pluggedIn(level: percent) : .unplugged(level: percent))
            }
            return
        }
    }

    // MARK: - Bluetooth accessories

    private func scanAccessories(announce: Bool) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let found = Self.accessoryBatteries()
            DispatchQueue.main.async {
                guard let self else { return }
                let names = Set(found.map(\.name))
                if announce, let arrival = found.first(where: { !self.knownAccessories.contains($0.name) }) {
                    self.show(.bluetooth(name: arrival.name, level: arrival.level))
                }
                self.knownAccessories = names
            }
        }
    }

    /// Accessory battery has no usable public API. The IO registry route that other
    /// guides suggest (`AppleDeviceManagementHIDEventService` / `BatteryPercent*`)
    /// yields nothing on this macOS version — those keys simply aren't published.
    /// `system_profiler` does report it, runs in well under a tenth of a second, and is
    /// a stable, documented surface, so it wins over the private alternatives.
    static func accessoryBatteries() -> [(name: String, level: Int)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]] else { return [] }

        var results: [(name: String, level: Int)] = []
        for section in sections {
            guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                for (name, value) in entry {
                    guard let properties = value as? [String: Any] else { continue }
                    // Earbuds report per side; take the lower one, since that's what
                    // actually runs out first. Anything else reports a single level.
                    let buds = [
                        percent(properties["device_batteryLevelLeft"]),
                        percent(properties["device_batteryLevelRight"]),
                    ].compactMap { $0 }
                    let level = buds.min()
                        ?? percent(properties["device_batteryLevelMain"])
                        ?? percent(properties["device_batteryLevelCase"])
                    guard let level else { continue }
                    results.append((name, level))
                }
            }
        }
        return results
    }

    /// Levels arrive as strings like "100%".
    private static func percent(_ value: Any?) -> Int? {
        guard let text = value as? String else { return nil }
        return Int(text.trimmingCharacters(in: CharacterSet(charactersIn: "% ")))
    }

    // MARK: - Alerts

    private func show(_ alert: PillAlert) {
        alertWork?.cancel()
        self.alert = alert
        let work = DispatchWorkItem { [weak self] in self?.alert = nil }
        alertWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }
}
