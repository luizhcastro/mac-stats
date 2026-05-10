import Foundation
import IOKit
import Darwin

enum SMARTStatus: String, Sendable {
    case healthy
    case failing
    case unsupported
    case unknown
}

struct VolumeInfo: Sendable, Identifiable {
    var bsdName: String
    var physicalDisk: String
    var displayName: String
    var mountPath: String
    var totalBytes: UInt64
    var freeBytes: UInt64
    var isInternal: Bool
    var isReadOnly: Bool
    var isRoot: Bool
    var smartStatus: SMARTStatus

    var id: String { bsdName }
    var usedBytes: UInt64 { totalBytes >= freeBytes ? totalBytes - freeBytes : 0 }
    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

final class DiskMonitor {
    struct Sample: Sendable {
        var readPerSec: Double
        var writePerSec: Double
        var totalRead: UInt64
        var totalWritten: UInt64
        var capacityBytes: UInt64
        var freeBytes: UInt64
        var volumes: [VolumeInfo]
    }

    private var lastRead: UInt64 = 0
    private var lastWrite: UInt64 = 0
    private var lastTimestamp: Date?
    private var cachedVolumes: [VolumeInfo] = []
    private var lastVolumeStatsRefresh: Date?
    private let volumeRefreshInterval: TimeInterval = 30
    private var smartCache: [String: (status: SMARTStatus, at: Date)] = [:]
    private let smartTTL: TimeInterval = 300

    func sample(includeVolumeStats: Bool, forceVolumeStatsRefresh: Bool = false) -> Sample {
        let (read, written) = readIOStats()
        let now = Date()
        let volumes = volumeList(
            at: now,
            includeVolumeStats: includeVolumeStats,
            forceRefresh: forceVolumeStatsRefresh
        )
        let root = volumes.first(where: { $0.isRoot })
        let capacity = root?.totalBytes ?? 0
        let free = root?.freeBytes ?? 0

        defer {
            lastRead = read
            lastWrite = written
            lastTimestamp = now
        }
        guard let last = lastTimestamp else {
            return Sample(
                readPerSec: 0, writePerSec: 0,
                totalRead: read, totalWritten: written,
                capacityBytes: capacity, freeBytes: free,
                volumes: volumes
            )
        }
        let dt = now.timeIntervalSince(last)
        guard dt > 0 else {
            return Sample(
                readPerSec: 0, writePerSec: 0,
                totalRead: read, totalWritten: written,
                capacityBytes: capacity, freeBytes: free,
                volumes: volumes
            )
        }
        return Sample(
            readPerSec: SamplingMath.rate(current: read, previous: lastRead, dt: dt),
            writePerSec: SamplingMath.rate(current: written, previous: lastWrite, dt: dt),
            totalRead: read,
            totalWritten: written,
            capacityBytes: capacity,
            freeBytes: free,
            volumes: volumes
        )
    }

    private func volumeList(at now: Date, includeVolumeStats: Bool, forceRefresh: Bool) -> [VolumeInfo] {
        guard includeVolumeStats else { return cachedVolumes }
        let shouldRefresh =
            forceRefresh ||
            cachedVolumes.isEmpty ||
            lastVolumeStatsRefresh.map { now.timeIntervalSince($0) >= volumeRefreshInterval } ?? true
        if shouldRefresh {
            cachedVolumes = enumerateVolumes(now: now)
            lastVolumeStatsRefresh = now
        }
        return cachedVolumes
    }

    private func enumerateVolumes(now: Date) -> [VolumeInfo] {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsInternalKey,
            .volumeIsReadOnlyKey
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }
        var out: [VolumeInfo] = []
        out.reserveCapacity(urls.count)
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            guard let total = values.volumeTotalCapacity, total > 0 else { continue }
            let path = url.path
            var st = statfs()
            guard statfs(path, &st) == 0 else { continue }
            let fnSize = MemoryLayout.size(ofValue: st.f_mntfromname)
            let device = withUnsafePointer(to: &st.f_mntfromname) { ptr -> String in
                ptr.withMemoryRebound(to: CChar.self, capacity: fnSize) {
                    String(cString: $0)
                }
            }
            let bsd = device.hasPrefix("/dev/") ? String(device.dropFirst(5)) : device
            let physical = parentDisk(bsd: bsd)
            let smart = lookupSmart(bsd: physical, now: now)
            out.append(VolumeInfo(
                bsdName: bsd,
                physicalDisk: physical,
                displayName: values.volumeName ?? bsd,
                mountPath: path,
                totalBytes: UInt64(total),
                freeBytes: UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0),
                isInternal: values.volumeIsInternal ?? false,
                isReadOnly: values.volumeIsReadOnly ?? false,
                isRoot: path == "/",
                smartStatus: smart
            ))
        }
        out.sort { lhs, rhs in
            if lhs.isRoot != rhs.isRoot { return lhs.isRoot }
            if lhs.isInternal != rhs.isInternal { return lhs.isInternal }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return out
    }

    private func parentDisk(bsd: String) -> String {
        guard bsd.hasPrefix("disk") else { return bsd }
        let rest = bsd.dropFirst(4)
        var digits = ""
        for c in rest {
            if c.isNumber { digits.append(c) } else { break }
        }
        return digits.isEmpty ? bsd : "disk\(digits)"
    }

    private func lookupSmart(bsd: String, now: Date) -> SMARTStatus {
        if let cached = smartCache[bsd], now.timeIntervalSince(cached.at) < smartTTL {
            return cached.status
        }
        let status = querySmart(bsd: bsd)
        smartCache[bsd] = (status, now)
        return status
    }

    private func querySmart(bsd: String) -> SMARTStatus {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        proc.arguments = ["info", "-plist", "/dev/\(bsd)"]
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        do {
            try proc.run()
        } catch {
            return .unknown
        }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return .unknown }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            return .unknown
        }
        let s = (plist["SMARTStatus"] as? String) ?? ""
        switch s {
        case "Verified": return .healthy
        case "Failing": return .failing
        case "Not Supported": return .unsupported
        default: return .unknown
        }
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
}
