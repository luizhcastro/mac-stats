import Foundation
import IOKit
import IOKit.ps

final class BatteryMonitor {
    struct Sample: Sendable {
        var percent: Double
        var isCharging: Bool
        var isPluggedIn: Bool
        var timeToEmptyMinutes: Int?
        var timeToFullMinutes: Int?
        var hasBattery: Bool

        var cycleCount: Int?
        var designCapacityMAh: Int?
        var currentMaxCapacityMAh: Int?
        var healthPercent: Double?
        var temperatureCelsius: Double?
        var voltageVolts: Double?
        var amperageMilliAmps: Int?
        var wattage: Double?
        var serial: String?
        var deviceName: String?

        static let empty = Sample(
            percent: 0,
            isCharging: false,
            isPluggedIn: false,
            timeToEmptyMinutes: nil,
            timeToFullMinutes: nil,
            hasBattery: false
        )
    }

    func sample() -> Sample {
        var sample = Sample.empty

        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { continue }
                let type = desc[kIOPSTypeKey] as? String
                guard type == kIOPSInternalBatteryType else { continue }

                let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
                let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
                let state = desc[kIOPSPowerSourceStateKey] as? String
                let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
                let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int
                let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int

                sample.percent = maxCapacity > 0 ? Double(capacity) / Double(maxCapacity) * 100 : 0
                sample.isCharging = charging
                sample.isPluggedIn = state == kIOPSACPowerValue
                sample.timeToEmptyMinutes = (timeToEmpty ?? -1) > 0 ? timeToEmpty : nil
                sample.timeToFullMinutes = (timeToFull ?? -1) > 0 ? timeToFull : nil
                sample.hasBattery = true
                break
            }
        }

        if !sample.hasBattery {
            return sample
        }

        if let smart = readSmartBattery() {
            if let v = smart["CycleCount"] as? Int { sample.cycleCount = v }
            if let v = smart["DesignCapacity"] as? Int { sample.designCapacityMAh = v }
            if let v = smart["AppleRawMaxCapacity"] as? Int {
                sample.currentMaxCapacityMAh = v
            } else if let v = smart["NominalChargeCapacity"] as? Int {
                sample.currentMaxCapacityMAh = v
            }
            if let design = sample.designCapacityMAh, let cur = sample.currentMaxCapacityMAh, design > 0 {
                sample.healthPercent = min(100, Double(cur) / Double(design) * 100)
            }
            if let temp = smart["Temperature"] as? Int {
                sample.temperatureCelsius = Double(temp) / 100.0
            } else if let temp = smart["VirtualTemperature"] as? Int {
                sample.temperatureCelsius = Double(temp) / 100.0
            }
            if let mv = smart["Voltage"] as? Int {
                sample.voltageVolts = Double(mv) / 1000.0
            } else if let mv = smart["AppleRawBatteryVoltage"] as? Int {
                sample.voltageVolts = Double(mv) / 1000.0
            }
            if let amp = smart["Amperage"] as? NSNumber {
                let signed = Int(amp.int64Value)
                sample.amperageMilliAmps = signed
                if let v = sample.voltageVolts {
                    sample.wattage = abs(Double(signed) / 1000.0 * v)
                }
            }
            if let s = smart["Serial"] as? String, !s.isEmpty { sample.serial = s }
            if let n = smart["DeviceName"] as? String, !n.isEmpty { sample.deviceName = n }
        }

        return sample
    }

    private func readSmartBattery() -> [String: Any]? {
        let match = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, match)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let dict = props?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return dict
    }
}
