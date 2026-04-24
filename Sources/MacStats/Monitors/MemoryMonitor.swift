import Foundation
import Darwin

final class MemoryMonitor {
    struct Sample {
        var totalBytes: UInt64
        var usedBytes: UInt64
        var activeBytes: UInt64
        var wiredBytes: UInt64
        var compressedBytes: UInt64
        var freeBytes: UInt64
        var pressurePercent: Double
    }

    private let pageSize: UInt64 = {
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        return UInt64(size)
    }()

    private let totalMemory: UInt64 = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }()

    func sample() -> Sample {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return Sample(totalBytes: totalMemory, usedBytes: 0, activeBytes: 0, wiredBytes: 0, compressedBytes: 0, freeBytes: 0, pressurePercent: 0)
        }

        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        let used = active + wired + compressed
        let pressure = totalMemory > 0 ? Double(used) / Double(totalMemory) * 100 : 0

        return Sample(
            totalBytes: totalMemory,
            usedBytes: used,
            activeBytes: active,
            wiredBytes: wired,
            compressedBytes: compressed,
            freeBytes: free,
            pressurePercent: pressure
        )
    }
}
