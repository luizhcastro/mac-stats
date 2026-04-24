import Foundation
import Darwin

final class ProcessMonitor {
    struct ProcStat: Identifiable {
        let id: Int32
        let name: String
        var cpuPercent: Double
        var memoryBytes: UInt64
        var diskBytesRead: UInt64
        var diskBytesWritten: UInt64
        var diskReadPerSec: Double
        var diskWritePerSec: Double
    }

    private struct Prior {
        var cpuTimeNs: UInt64
        var diskRead: UInt64
        var diskWritten: UInt64
    }

    private var prior: [Int32: Prior] = [:]
    private var lastSampleTime: Date?
    private let coreCount = Double(max(1, Int(Foundation.ProcessInfo.processInfo.activeProcessorCount)))

    func sample() -> [ProcStat] {
        let pids = listPids()
        let now = Date()
        let dt = lastSampleTime.map { now.timeIntervalSince($0) } ?? 1.0
        defer { lastSampleTime = now }

        var results: [ProcStat] = []
        var nextPrior: [Int32: Prior] = [:]
        results.reserveCapacity(pids.count)

        for pid in pids where pid > 0 {
            guard let task = taskInfo(pid: pid) else { continue }
            let cpuTimeNs = task.pti_total_user + task.pti_total_system
            let rss = task.pti_resident_size

            var diskRead: UInt64 = 0
            var diskWritten: UInt64 = 0
            if let usage = rusageInfo(pid: pid) {
                diskRead = usage.ri_diskio_bytesread
                diskWritten = usage.ri_diskio_byteswritten
            }

            var cpuPct = 0.0
            var readRate = 0.0
            var writeRate = 0.0
            if let p = prior[pid], dt > 0 {
                let deltaCpu = Double(cpuTimeNs &- p.cpuTimeNs) / 1_000_000_000.0
                cpuPct = (deltaCpu / dt) * 100 / coreCount
                readRate = Double(diskRead &- p.diskRead) / dt
                writeRate = Double(diskWritten &- p.diskWritten) / dt
            }

            nextPrior[pid] = Prior(cpuTimeNs: cpuTimeNs, diskRead: diskRead, diskWritten: diskWritten)

            let name = processName(pid: pid)
            results.append(ProcStat(
                id: pid,
                name: name,
                cpuPercent: max(0, cpuPct),
                memoryBytes: rss,
                diskBytesRead: diskRead,
                diskBytesWritten: diskWritten,
                diskReadPerSec: max(0, readRate),
                diskWritePerSec: max(0, writeRate)
            ))
        }

        prior = nextPrior
        return results
    }

    private func listPids() -> [Int32] {
        let probe = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard probe > 0 else { return [] }
        let slackBytes = Int32(1024 * MemoryLayout<Int32>.size)
        let bufBytes = probe + slackBytes
        let capacity = Int(bufBytes) / MemoryLayout<Int32>.size
        var buf = [Int32](repeating: 0, count: capacity)
        let n = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, ptr.baseAddress, bufBytes)
        }
        guard n > 0 else { return [] }
        let actual = min(Int(n) / MemoryLayout<Int32>.size, capacity)
        return Array(buf.prefix(actual))
    }

    private func taskInfo(pid: Int32) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        guard ret == size else { return nil }
        return info
    }

    private func rusageInfo(pid: Int32) -> rusage_info_v2? {
        let bufSize = max(MemoryLayout<rusage_info_v2>.size, 4096)
        let raw = UnsafeMutableRawPointer.allocate(byteCount: bufSize, alignment: 16)
        defer { raw.deallocate() }
        raw.initializeMemory(as: UInt8.self, repeating: 0, count: bufSize)
        let casted = UnsafeMutablePointer<rusage_info_t?>(OpaquePointer(raw))
        let ret = proc_pid_rusage(pid, RUSAGE_INFO_V2, casted)
        guard ret == 0 else { return nil }
        return raw.assumingMemoryBound(to: rusage_info_v2.self).pointee
    }

    private func processName(pid: Int32) -> String {
        var buf = [CChar](repeating: 0, count: 1024)
        let n = proc_name(pid, &buf, UInt32(buf.count))
        if n > 0 {
            return String(cString: buf)
        }
        return "pid:\(pid)"
    }
}
