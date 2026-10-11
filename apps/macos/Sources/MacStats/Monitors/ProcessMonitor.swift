import Foundation
import Darwin

final class ProcessMonitor {
    struct ProcStat: Identifiable, Sendable {
        let id: Int32
        let name: String
        let nameLower: String
        var cpuPercent: Double
        var memoryBytes: UInt64
        var diskBytesRead: UInt64
        var diskBytesWritten: UInt64
        var diskReadPerSec: Double
        var diskWritePerSec: Double
        var wakeupsPerSec: Double
        var energyImpact: Double
        var netInPerSec: Double = 0
        var netOutPerSec: Double = 0

        var pid: Int32 { id }
    }

    private struct Prior {
        var cpuTimeNs: UInt64
        var diskRead: UInt64
        var diskWritten: UInt64
        var wakeups: UInt64
        var tick: UInt64
        var name: String
        var nameLower: String
    }

    private static let idleWakeupEnergyCost = 0.39

    private struct ProcessIdentity: Hashable {
        let pid: Int32
        let startSeconds: UInt64
        let startMicroseconds: UInt64
    }

    private var prior: [ProcessIdentity: Prior] = [:]
    private var currentTick: UInt64 = 0
    private var lastSampleTime: Date?
    private var staleScratch: [ProcessIdentity] = []
    private var pidBuf: [Int32] = []
    private var trackEnergy = false
    private let coreCount = Double(max(1, Int(Foundation.ProcessInfo.processInfo.activeProcessorCount)))
    private let rusageBufferSize = max(MemoryLayout<rusage_info_v2>.size, 4096)
    private let rusageBuffer = UnsafeMutableRawPointer.allocate(
        byteCount: max(MemoryLayout<rusage_info_v2>.size, 4096),
        alignment: 16
    )

    deinit {
        rusageBuffer.deallocate()
    }

    func setEnergyTrackingEnabled(_ enabled: Bool) {
        trackEnergy = enabled
    }

    func sample() -> [ProcStat] {
        let pidCount = listPidsInto(&pidBuf)
        let now = Date()
        let dt = lastSampleTime.map { now.timeIntervalSince($0) } ?? 1.0
        defer { lastSampleTime = now }

        currentTick &+= 1
        var results: [ProcStat] = []
        results.reserveCapacity(pidCount)

        for idx in 0..<pidCount {
            let pid = pidBuf[idx]
            guard pid > 0 else { continue }
            guard let info = taskAllInfo(pid: pid) else { continue }
            let task = info.ptinfo
            let identity = ProcessIdentity(
                pid: pid,
                startSeconds: info.pbsd.pbi_start_tvsec,
                startMicroseconds: info.pbsd.pbi_start_tvusec
            )
            let cpuTimeNs = task.pti_total_user + task.pti_total_system
            let rss = task.pti_resident_size

            var diskRead: UInt64 = 0
            var diskWritten: UInt64 = 0
            var wakeups: UInt64 = 0
            if let usage = rusageInfo(pid: pid) {
                diskRead = usage.ri_diskio_bytesread
                diskWritten = usage.ri_diskio_byteswritten
                if trackEnergy {
                    wakeups = usage.ri_pkg_idle_wkups &+ usage.ri_interrupt_wkups
                }
            }

            var cpuPct = 0.0
            var readRate = 0.0
            var writeRate = 0.0
            var wakeupsRate = 0.0
            var cachedName: String?
            var cachedNameLower: String?
            if let p = prior[identity] {
                cachedName = p.name
                cachedNameLower = p.nameLower
                if dt > 0 {
                    if let deltaCpuNs = SamplingMath.delta(current: cpuTimeNs, previous: p.cpuTimeNs) {
                        let deltaCpu = Double(deltaCpuNs) / 1_000_000_000.0
                        cpuPct = (deltaCpu / dt) * 100 / coreCount
                    }
                    readRate = SamplingMath.rate(current: diskRead, previous: p.diskRead, dt: dt)
                    writeRate = SamplingMath.rate(current: diskWritten, previous: p.diskWritten, dt: dt)
                    if trackEnergy {
                        wakeupsRate = SamplingMath.rate(current: wakeups, previous: p.wakeups, dt: dt)
                    }
                }
            }

            let name = cachedName ?? processName(pid: pid, info: info)
            let nameLower = cachedNameLower ?? name.lowercased()
            prior[identity] = Prior(
                cpuTimeNs: cpuTimeNs,
                diskRead: diskRead,
                diskWritten: diskWritten,
                wakeups: wakeups,
                tick: currentTick,
                name: name,
                nameLower: nameLower
            )

            let cpuPctClamped = max(0, cpuPct)
            let wakeupsClamped = trackEnergy ? max(0, wakeupsRate) : 0
            let energyImpact = trackEnergy ? cpuPctClamped + wakeupsClamped * Self.idleWakeupEnergyCost : 0

            results.append(ProcStat(
                id: pid,
                name: name,
                nameLower: nameLower,
                cpuPercent: cpuPctClamped,
                memoryBytes: rss,
                diskBytesRead: diskRead,
                diskBytesWritten: diskWritten,
                diskReadPerSec: max(0, readRate),
                diskWritePerSec: max(0, writeRate),
                wakeupsPerSec: wakeupsClamped,
                energyImpact: energyImpact
            ))
        }

        sweepStalePrior()
        return results
    }

    private func sweepStalePrior() {
        staleScratch.removeAll(keepingCapacity: true)
        for (k, v) in prior where v.tick != currentTick {
            staleScratch.append(k)
        }
        for k in staleScratch {
            prior.removeValue(forKey: k)
        }
    }

    private func listPidsInto(_ buf: inout [Int32]) -> Int {
        let probe = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard probe > 0 else { return 0 }
        let slackBytes = Int32(1024 * MemoryLayout<Int32>.size)
        let bufBytes = probe + slackBytes
        let capacity = Int(bufBytes) / MemoryLayout<Int32>.size
        if buf.count < capacity {
            buf = [Int32](repeating: 0, count: capacity)
        }
        let n = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, ptr.baseAddress, bufBytes)
        }
        guard n > 0 else { return 0 }
        return min(Int(n) / MemoryLayout<Int32>.size, capacity)
    }

    private func taskAllInfo(pid: Int32) -> proc_taskallinfo? {
        var info = proc_taskallinfo()
        let size = Int32(MemoryLayout<proc_taskallinfo>.size)
        let ret = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size)
        guard ret == size else { return nil }
        return info
    }

    private func rusageInfo(pid: Int32) -> rusage_info_v2? {
        let casted = UnsafeMutablePointer<rusage_info_t?>(OpaquePointer(rusageBuffer))
        let ret = proc_pid_rusage(pid, RUSAGE_INFO_V2, casted)
        guard ret == 0 else { return nil }
        return rusageBuffer.assumingMemoryBound(to: rusage_info_v2.self).pointee
    }

    private func processName(pid: Int32, info: proc_taskallinfo) -> String {
        if let name = decodeCStringTuple(info.pbsd.pbi_name), !name.isEmpty {
            return name
        }
        if let command = decodeCStringTuple(info.pbsd.pbi_comm), !command.isEmpty {
            return command
        }
        return "pid:\(pid)"
    }

    private func decodeCStringTuple<T>(_ tuple: T) -> String? {
        withUnsafeBytes(of: tuple) { rawBuffer in
            let end = rawBuffer.firstIndex(of: 0) ?? rawBuffer.count
            guard end > 0 else { return nil }
            return String(decoding: rawBuffer.prefix(end), as: UTF8.self)
        }
    }
}
