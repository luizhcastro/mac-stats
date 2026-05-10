import Foundation
import IOKit

final class GPUMonitor {
    struct Sample: Sendable {
        var utilizationPercent: Double
        var rendererUtilizationPercent: Double
        var tilerUtilizationPercent: Double
        var vramUsedBytes: UInt64
        var deviceCount: Int
        var primaryName: String?
        var hasReadings: Bool

        static let empty = Sample(
            utilizationPercent: 0,
            rendererUtilizationPercent: 0,
            tilerUtilizationPercent: 0,
            vramUsedBytes: 0,
            deviceCount: 0,
            primaryName: nil,
            hasReadings: false
        )
    }

    private let perfKey = "PerformanceStatistics" as CFString
    private let nameKey = "IOClass" as CFString
    private let modelKey = "model" as CFString

    func sample() -> Sample {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOAccelerator") else { return .empty }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return .empty
        }
        defer { IOObjectRelease(iterator) }

        var maxUtil: Double = 0
        var maxRend: Double = 0
        var maxTiler: Double = 0
        var totalVRAM: UInt64 = 0
        var deviceCount = 0
        var hasAny = false
        var primaryName: String?

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            deviceCount &+= 1

            if primaryName == nil,
               let modelProp = IORegistryEntryCreateCFProperty(service, modelKey, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                if let s = modelProp as? String {
                    primaryName = s
                } else if let d = modelProp as? Data, let s = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0"))), !s.isEmpty {
                    primaryName = s
                }
            }

            guard let propRef = IORegistryEntryCreateCFProperty(service, perfKey, kCFAllocatorDefault, 0),
                  let stats = propRef.takeRetainedValue() as? [String: Any] else {
                continue
            }

            if let v = Self.numeric(stats["Device Utilization %"]) {
                maxUtil = max(maxUtil, v)
                hasAny = true
            } else if let v = Self.numeric(stats["GPU Activity(%)"]) {
                maxUtil = max(maxUtil, v)
                hasAny = true
            }
            if let v = Self.numeric(stats["Renderer Utilization %"]) {
                maxRend = max(maxRend, v)
            }
            if let v = Self.numeric(stats["Tiler Utilization %"]) {
                maxTiler = max(maxTiler, v)
            }
            if let v = Self.numeric(stats["In use system memory"]) {
                totalVRAM &+= UInt64(max(0, v))
                hasAny = true
            } else if let v = Self.numeric(stats["vramUsedBytes"]) {
                totalVRAM &+= UInt64(max(0, v))
                hasAny = true
            }
        }

        return Sample(
            utilizationPercent: maxUtil,
            rendererUtilizationPercent: maxRend,
            tilerUtilizationPercent: maxTiler,
            vramUsedBytes: totalVRAM,
            deviceCount: deviceCount,
            primaryName: primaryName,
            hasReadings: hasAny
        )
    }

    private static func numeric(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let i = value as? Int { return Double(i) }
        if let i = value as? UInt64 { return Double(i) }
        if let d = value as? Double { return d }
        return nil
    }
}
