import Foundation
import IOKit

final class DiskMonitor {
    struct Sample: Sendable {
        var readPerSec: Double
        var writePerSec: Double
        var totalRead: UInt64
        var totalWritten: UInt64
        var capacityBytes: UInt64
        var freeBytes: UInt64
    }

    private var lastRead: UInt64 = 0
    private var lastWrite: UInt64 = 0
    private var lastTimestamp: Date?
    private var cachedCapacityBytes: UInt64 = 0
    private var cachedFreeBytes: UInt64 = 0
    private var lastVolumeStatsRefresh: Date?
    private let volumeRefreshInterval: TimeInterval = 30

    func sample(includeVolumeStats: Bool, forceVolumeStatsRefresh: Bool = false) -> Sample {
        let (read, written) = readIOStats()
        let now = Date()
        let (capacity, free) = volumeStats(
            at: now,
            includeVolumeStats: includeVolumeStats,
            forceRefresh: forceVolumeStatsRefresh
        )
        defer {
            lastRead = read
            lastWrite = written
            lastTimestamp = now
        }
        guard let last = lastTimestamp else {
            return Sample(readPerSec: 0, writePerSec: 0, totalRead: read, totalWritten: written, capacityBytes: capacity, freeBytes: free)
        }
        let dt = now.timeIntervalSince(last)
        guard dt > 0 else {
            return Sample(readPerSec: 0, writePerSec: 0, totalRead: read, totalWritten: written, capacityBytes: capacity, freeBytes: free)
        }
        return Sample(
            readPerSec: SamplingMath.rate(current: read, previous: lastRead, dt: dt),
            writePerSec: SamplingMath.rate(current: written, previous: lastWrite, dt: dt),
            totalRead: read,
            totalWritten: written,
            capacityBytes: capacity,
            freeBytes: free
        )
    }

    private func volumeStats(at now: Date, includeVolumeStats: Bool, forceRefresh: Bool) -> (UInt64, UInt64) {
        guard includeVolumeStats else {
            return (cachedCapacityBytes, cachedFreeBytes)
        }

        let shouldRefresh =
            forceRefresh ||
            cachedCapacityBytes == 0 ||
            lastVolumeStatsRefresh.map { now.timeIntervalSince($0) >= volumeRefreshInterval } ?? true

        if shouldRefresh {
            let (capacity, free) = readVolumeStats()
            cachedCapacityBytes = capacity
            cachedFreeBytes = free
            lastVolumeStatsRefresh = now
        }

        return (cachedCapacityBytes, cachedFreeBytes)
    }

    private let statisticsKey = "Statistics" as CFString

    private func readIOStats() -> (UInt64, UInt64) {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            guard let prop = IORegistryEntryCreateCFProperty(service, statisticsKey, kCFAllocatorDefault, 0),
                  let stats = prop.takeRetainedValue() as? [String: Any] else { continue }
            if let r = stats["Bytes (Read)"] as? UInt64 { totalRead &+= r }
            if let w = stats["Bytes (Write)"] as? UInt64 { totalWrite &+= w }
        }
        return (totalRead, totalWrite)
    }

    private func readVolumeStats() -> (UInt64, UInt64) {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) else {
            return (0, 0)
        }
        let total = UInt64(values.volumeTotalCapacity ?? 0)
        let free = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        return (total, free)
    }
}
