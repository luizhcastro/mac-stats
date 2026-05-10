import Foundation
import Darwin

final class MemoryMonitor {
    struct Sample: Sendable {
        var totalBytes: UInt64
        var usedBytes: UInt64
        var activeBytes: UInt64
        var wiredBytes: UInt64
        var compressedBytes: UInt64
        var freeBytes: UInt64
        var pressurePercent: Double
        var swapUsedBytes: UInt64
        var swapTotalBytes: UInt64
        var swapInsPerSec: Double
        var swapOutsPerSec: Double

        static let empty = Sample(
            totalBytes: 0, usedBytes: 0, activeBytes: 0, wiredBytes: 0,
            compressedBytes: 0, freeBytes: 0, pressurePercent: 0,
            swapUsedBytes: 0, swapTotalBytes: 0,
            swapInsPerSec: 0, swapOutsPerSec: 0
        )
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

    private var lastSwap: (ins: UInt64, outs: UInt64, at: Date)?

    func sample() -> Sample {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            var s = Sample.empty
            s.totalBytes = totalMemory
            return s
        }

        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        let used = active + wired + compressed
        let pressure = totalMemory > 0 ? Double(used) / Double(totalMemory) * 100 : 0

        let now = Date()
        let curIns = UInt64(stats.swapins)
        let curOuts = UInt64(stats.swapouts)
        var swapInRate = 0.0
        var swapOutRate = 0.0
        if let last = lastSwap {
            let dt = now.timeIntervalSince(last.at)
            if dt > 0 {
                let dIn = SamplingMath.delta(current: curIns, previous: last.ins) ?? 0
                let dOut = SamplingMath.delta(current: curOuts, previous: last.outs) ?? 0
                swapInRate = Double(dIn) / dt * Double(pageSize)
                swapOutRate = Double(dOut) / dt * Double(pageSize)
            }
        }
        lastSwap = (curIns, curOuts, now)

        var swap = xsw_usage()
        var ssize = MemoryLayout<xsw_usage>.size
        let kr = sysctlbyname("vm.swapusage", &swap, &ssize, nil, 0)
        let swapUsed = kr == 0 ? UInt64(swap.xsu_used) : 0
        let swapTotal = kr == 0 ? UInt64(swap.xsu_total) : 0

        return Sample(
            totalBytes: totalMemory,
            usedBytes: used,
            activeBytes: active,
            wiredBytes: wired,
            compressedBytes: compressed,
            freeBytes: free,
            pressurePercent: pressure,
            swapUsedBytes: swapUsed,
            swapTotalBytes: swapTotal,
            swapInsPerSec: swapInRate,
            swapOutsPerSec: swapOutRate
        )
    }
}
