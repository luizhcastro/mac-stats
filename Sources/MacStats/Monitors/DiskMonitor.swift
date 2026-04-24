import Foundation
import IOKit

final class DiskMonitor {
    struct Sample {
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

    func sample() -> Sample {
        let (read, written) = readIOStats()
        let (capacity, free) = readVolumeStats()
        let now = Date()
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
            readPerSec: Double(read &- lastRead) / dt,
            writePerSec: Double(written &- lastWrite) / dt,
            totalRead: read,
            totalWritten: written,
            capacityBytes: capacity,
            freeBytes: free
        )
    }

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
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any],
                  let stats = dict["Statistics"] as? [String: Any] else { continue }
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
