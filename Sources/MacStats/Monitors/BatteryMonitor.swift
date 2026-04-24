import Foundation
import IOKit.ps

final class BatteryMonitor {
    struct Sample {
        var percent: Double
        var isCharging: Bool
        var isPluggedIn: Bool
        var timeToEmptyMinutes: Int?
        var timeToFullMinutes: Int?
        var hasBattery: Bool
    }

    func sample() -> Sample {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return Sample(percent: 0, isCharging: false, isPluggedIn: false, timeToEmptyMinutes: nil, timeToFullMinutes: nil, hasBattery: false)
        }

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

            let percent = maxCapacity > 0 ? Double(capacity) / Double(maxCapacity) * 100 : 0
            return Sample(
                percent: percent,
                isCharging: charging,
                isPluggedIn: state == kIOPSACPowerValue,
                timeToEmptyMinutes: (timeToEmpty ?? -1) > 0 ? timeToEmpty : nil,
                timeToFullMinutes: (timeToFull ?? -1) > 0 ? timeToFull : nil,
                hasBattery: true
            )
        }

        return Sample(percent: 0, isCharging: false, isPluggedIn: true, timeToEmptyMinutes: nil, timeToFullMinutes: nil, hasBattery: false)
    }
}
