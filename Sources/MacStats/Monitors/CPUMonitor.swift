import Foundation
import Darwin

enum CoreCluster: UInt8, Sendable {
    case performance, efficiency, unified
}

struct CoreUsage: Sendable {
    var coreId: Int
    var usage: Double
    var cluster: CoreCluster
}

struct LoadAverage: Sendable {
    var one: Double
    var five: Double
    var fifteen: Double
    static let zero = LoadAverage(one: 0, five: 0, fifteen: 0)
}

final class CPUMonitor {
    struct Sample: Sendable {
        var usage: Double
        var user: Double
        var system: Double
        var idle: Double
        var cores: [CoreUsage]
        var loadAverage: LoadAverage
        var frequencyMHz: Int?

        static let empty = Sample(
            usage: 0, user: 0, system: 0, idle: 0,
            cores: [], loadAverage: .zero, frequencyMHz: nil
        )
    }

    private let host = mach_host_self()
    private var previousLoad: host_cpu_load_info?
    private var previousCoreTicks: [(user: UInt32, sys: UInt32, idle: UInt32, nice: UInt32)] = []
    private let coreClusters: [CoreCluster]
    private let nominalFrequencyMHz: Int?

    init() {
        var logical: Int32 = 0
        var lsize = MemoryLayout<Int32>.size
        sysctlbyname("hw.logicalcpu", &logical, &lsize, nil, 0)
        let total = Int(max(logical, 1))

        var perfCount: Int32 = 0
        var effCount: Int32 = 0
        var psize = MemoryLayout<Int32>.size
        var esize = MemoryLayout<Int32>.size
        let perfOK = sysctlbyname("hw.perflevel0.physicalcpu", &perfCount, &psize, nil, 0) == 0
        let effOK = sysctlbyname("hw.perflevel1.physicalcpu", &effCount, &esize, nil, 0) == 0

        if perfOK && effOK && perfCount > 0 {
            let physicalSum = Int(perfCount) + Int(effCount)
            let smt = max(1, total / max(physicalSum, 1))
            var arr: [CoreCluster] = []
            arr.reserveCapacity(total)
            for _ in 0..<(Int(perfCount) * smt) { arr.append(.performance) }
            for _ in 0..<(Int(effCount) * smt) { arr.append(.efficiency) }
            while arr.count < total { arr.append(.unified) }
            self.coreClusters = arr
        } else {
            self.coreClusters = Array(repeating: .unified, count: total)
        }

        var freq: UInt64 = 0
        var fsize = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.cpufrequency", &freq, &fsize, nil, 0) == 0 && freq > 0 {
            self.nominalFrequencyMHz = Int(freq / 1_000_000)
        } else {
            self.nominalFrequencyMHz = nil
        }
    }

    func sample(includeCores: Bool = true) -> Sample {
        let aggregate = sampleAggregate()
        let cores = includeCores ? sampleCores() : []

        var loads = [Double](repeating: 0, count: 3)
        let n = getloadavg(&loads, 3)
        let load = n == 3
            ? LoadAverage(one: loads[0], five: loads[1], fifteen: loads[2])
            : LoadAverage.zero

        return Sample(
            usage: aggregate.usage,
            user: aggregate.user,
            system: aggregate.system,
            idle: aggregate.idle,
            cores: cores,
            loadAverage: load,
            frequencyMHz: nominalFrequencyMHz
        )
    }

    private func sampleAggregate() -> (usage: Double, user: Double, system: Double, idle: Double) {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        var load = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0, 0, 0) }
        defer { previousLoad = load }
        guard let prev = previousLoad else { return (0, 0, 0, 0) }

        let user = Double(load.cpu_ticks.0 - prev.cpu_ticks.0)
        let sys = Double(load.cpu_ticks.1 - prev.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2 - prev.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3 - prev.cpu_ticks.3)
        let total = user + sys + idle + nice
        guard total > 0 else { return (0, 0, 0, 0) }
        return (
            (user + sys + nice) / total * 100,
            (user + nice) / total * 100,
            sys / total * 100,
            idle / total * 100
        )
    }

    private func sampleCores() -> [CoreUsage] {
        var processorCount: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0
        var info: processor_info_array_t? = nil
        let kr = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &info,
            &infoCount
        )
        guard kr == KERN_SUCCESS, let info, processorCount > 0 else { return [] }
        defer {
            let bytes = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), bytes)
        }

        let count = Int(processorCount)
        if previousCoreTicks.count != count {
            previousCoreTicks = Array(repeating: (0, 0, 0, 0), count: count)
        }
        let needsBaseline = previousCoreTicks.allSatisfy { $0.user == 0 && $0.sys == 0 && $0.idle == 0 && $0.nice == 0 }

        var cores: [CoreUsage] = []
        cores.reserveCapacity(count)
        let buf = info.withMemoryRebound(to: processor_cpu_load_info_data_t.self, capacity: count) { ptr in
            UnsafeBufferPointer(start: ptr, count: count)
        }
        for i in 0..<count {
            let cur = buf[i]
            let user = cur.cpu_ticks.0
            let sys = cur.cpu_ticks.1
            let idle = cur.cpu_ticks.2
            let nice = cur.cpu_ticks.3
            let prev = previousCoreTicks[i]

            let dUser = Double(user &- prev.user)
            let dSys = Double(sys &- prev.sys)
            let dIdle = Double(idle &- prev.idle)
            let dNice = Double(nice &- prev.nice)
            let total = dUser + dSys + dIdle + dNice

            let usage: Double
            if needsBaseline || total <= 0 {
                usage = 0
            } else {
                usage = max(0, min(100, (dUser + dSys + dNice) / total * 100))
            }

            let cluster = i < coreClusters.count ? coreClusters[i] : .unified
            cores.append(CoreUsage(coreId: i, usage: usage, cluster: cluster))
            previousCoreTicks[i] = (user, sys, idle, nice)
        }
        return cores
    }
}
