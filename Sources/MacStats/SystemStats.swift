import Foundation

struct ProcessLeaders: Sendable {
    var cpu: [ProcessMonitor.ProcStat]
    var memory: [ProcessMonitor.ProcStat]
    var disk: [ProcessMonitor.ProcStat]
    var network: [NetworkProcessMonitor.ProcStat]
    var energy: [ProcessMonitor.ProcStat]

    static let empty = ProcessLeaders(cpu: [], memory: [], disk: [], network: [], energy: [])
}

struct MetricHistory: Sendable {
    var cpu: [Double]
    var memoryPercent: [Double]
    var networkIn: [Double]
    var networkOut: [Double]
    var diskRead: [Double]
    var diskWrite: [Double]

    static let empty = MetricHistory(
        cpu: Array(repeating: 0, count: 60),
        memoryPercent: Array(repeating: 0, count: 60),
        networkIn: Array(repeating: 0, count: 60),
        networkOut: Array(repeating: 0, count: 60),
        diskRead: Array(repeating: 0, count: 60),
        diskWrite: Array(repeating: 0, count: 60)
    )
}

struct SystemSnapshot: Sendable {
    var cpu: CPUMonitor.Sample
    var memory: MemoryMonitor.Sample
    var network: NetworkMonitor.Sample
    var battery: BatteryMonitor.Sample
    var disk: DiskMonitor.Sample
    var history: MetricHistory
    var processLeaders: ProcessLeaders
    var allProcesses: [ProcessMonitor.ProcStat]

    static let empty = SystemSnapshot(
        cpu: CPUMonitor.Sample(usage: 0, user: 0, system: 0, idle: 0),
        memory: MemoryMonitor.Sample(totalBytes: 0, usedBytes: 0, activeBytes: 0, wiredBytes: 0, compressedBytes: 0, freeBytes: 0, pressurePercent: 0),
        network: NetworkMonitor.Sample(bytesInPerSec: 0, bytesOutPerSec: 0, totalIn: 0, totalOut: 0),
        battery: BatteryMonitor.Sample(percent: 0, isCharging: false, isPluggedIn: false, timeToEmptyMinutes: nil, timeToFullMinutes: nil, hasBattery: false),
        disk: DiskMonitor.Sample(readPerSec: 0, writePerSec: 0, totalRead: 0, totalWritten: 0, capacityBytes: 0, freeBytes: 0),
        history: .empty,
        processLeaders: .empty,
        allProcesses: []
    )
}

@MainActor
final class SystemStats: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.empty

    private let sampler = StatsSampler()
    private var samplingTask: Task<Void, Never>?
    private var detailRetainCount = 0
    private var fullProcessListRetainCount = 0

    var cpu: CPUMonitor.Sample { snapshot.cpu }
    var memory: MemoryMonitor.Sample { snapshot.memory }
    var network: NetworkMonitor.Sample { snapshot.network }
    var battery: BatteryMonitor.Sample { snapshot.battery }
    var disk: DiskMonitor.Sample { snapshot.disk }
    var history: MetricHistory { snapshot.history }
    var cpuHistory: [Double] { snapshot.history.cpu }
    var processLeaders: ProcessLeaders { snapshot.processLeaders }
    var allProcesses: [ProcessMonitor.ProcStat] { snapshot.allProcesses }

    init() {
        samplingTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    deinit { samplingTask?.cancel() }

    func retainDetailSampling() {
        detailRetainCount += 1
        if detailRetainCount == 1 {
            Task { [weak self] in
                guard let self else { return }
                await sampler.setDetailSamplingEnabled(true)
                await refresh(forceDetailRefresh: true)
            }
        }
    }

    func releaseDetailSampling() {
        guard detailRetainCount > 0 else { return }
        detailRetainCount -= 1
        if detailRetainCount == 0 {
            Task { [sampler] in
                await sampler.setDetailSamplingEnabled(false)
            }
        }
    }

    func retainFullProcessList() {
        fullProcessListRetainCount += 1
        if fullProcessListRetainCount == 1 {
            Task { [sampler] in
                await sampler.setFullProcessListEnabled(true)
            }
        }
    }

    func releaseFullProcessList() {
        guard fullProcessListRetainCount > 0 else { return }
        fullProcessListRetainCount -= 1
        if fullProcessListRetainCount == 0 {
            Task { [sampler] in
                await sampler.setFullProcessListEnabled(false)
            }
        }
    }

    func setEnergyTrackingEnabled(_ enabled: Bool) {
        Task { [weak self] in
            guard let self else { return }
            await sampler.setEnergyTrackingEnabled(enabled)
            if enabled {
                await refresh(forceDetailRefresh: true)
            }
        }
    }

    private func refresh(forceDetailRefresh: Bool = false) async {
        snapshot = await sampler.sample(forceDetailRefresh: forceDetailRefresh)
    }
}

private actor StatsSampler {
    private static let processRefreshIntervalTicks = 2
    private static let batteryRefreshIntervalTicks = 30
    private static let historyCapacity = 60

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let diskMonitor = DiskMonitor()
    private let processMonitor = ProcessMonitor()
    private let networkProcessMonitor = NetworkProcessMonitor()

    private var tickCount = 0
    private var detailSamplingEnabled = false
    private var energyTrackingEnabled = false
    private var fullProcessListEnabled = false

    private var cpuRing = [Double](repeating: 0, count: StatsSampler.historyCapacity)
    private var memRing = [Double](repeating: 0, count: StatsSampler.historyCapacity)
    private var netInRing = [Double](repeating: 0, count: StatsSampler.historyCapacity)
    private var netOutRing = [Double](repeating: 0, count: StatsSampler.historyCapacity)
    private var diskReadRing = [Double](repeating: 0, count: StatsSampler.historyCapacity)
    private var diskWriteRing = [Double](repeating: 0, count: StatsSampler.historyCapacity)
    private var ringHead = 0

    private var lastBattery = BatteryMonitor.Sample(percent: 0, isCharging: false, isPluggedIn: false, timeToEmptyMinutes: nil, timeToFullMinutes: nil, hasBattery: false)
    private var lastBatterySampleTick: Int?
    private var lastProcessLeaders = ProcessLeaders.empty
    private var lastProcessList: [ProcessMonitor.ProcStat] = []

    init() {
        _ = cpuMonitor.sample()
        _ = networkMonitor.sample()
        _ = diskMonitor.sample(includeVolumeStats: false)
    }

    func setDetailSamplingEnabled(_ enabled: Bool) {
        detailSamplingEnabled = enabled
        if enabled {
            networkProcessMonitor.start()
        } else {
            networkProcessMonitor.stop()
        }
    }

    func setEnergyTrackingEnabled(_ enabled: Bool) {
        energyTrackingEnabled = enabled
        processMonitor.setEnergyTrackingEnabled(enabled)
    }

    func setFullProcessListEnabled(_ enabled: Bool) {
        fullProcessListEnabled = enabled
        if !enabled {
            lastProcessList = []
        }
    }

    func sample(forceDetailRefresh: Bool = false) -> SystemSnapshot {
        let cpu = cpuMonitor.sample()
        let memory = memoryMonitor.sample()
        let network = networkMonitor.sample()
        let disk = diskMonitor.sample(
            includeVolumeStats: detailSamplingEnabled,
            forceVolumeStatsRefresh: forceDetailRefresh
        )

        tickCount += 1
        cpuRing[ringHead] = cpu.usage
        let memTotal = max(memory.totalBytes, 1)
        memRing[ringHead] = Double(memory.usedBytes) / Double(memTotal) * 100.0
        netInRing[ringHead] = network.bytesInPerSec
        netOutRing[ringHead] = network.bytesOutPerSec
        diskReadRing[ringHead] = disk.readPerSec
        diskWriteRing[ringHead] = disk.writePerSec
        ringHead = (ringHead + 1) % Self.historyCapacity

        if detailSamplingEnabled && shouldRefreshBattery(force: forceDetailRefresh) {
            lastBattery = batteryMonitor.sample()
            lastBatterySampleTick = tickCount
        }

        if detailSamplingEnabled && shouldRefreshProcesses(force: forceDetailRefresh) {
            let processes = processMonitor.sample()
            let netProcesses = networkProcessMonitor.sample()
            lastProcessLeaders = buildProcessLeaders(
                from: processes,
                networkProcesses: netProcesses,
                limit: 8,
                trackEnergy: energyTrackingEnabled
            )
            if fullProcessListEnabled {
                lastProcessList = mergeNetworkRates(processes: processes, networkProcesses: netProcesses)
            }
        }

        return SystemSnapshot(
            cpu: cpu,
            memory: memory,
            network: network,
            battery: lastBattery,
            disk: disk,
            history: MetricHistory(
                cpu: linearized(cpuRing),
                memoryPercent: linearized(memRing),
                networkIn: linearized(netInRing),
                networkOut: linearized(netOutRing),
                diskRead: linearized(diskReadRing),
                diskWrite: linearized(diskWriteRing)
            ),
            processLeaders: lastProcessLeaders,
            allProcesses: lastProcessList
        )
    }

    private func linearized(_ ring: [Double]) -> [Double] {
        let cap = Self.historyCapacity
        var out = [Double](repeating: 0, count: cap)
        for i in 0..<cap {
            out[i] = ring[(ringHead + i) % cap]
        }
        return out
    }

    private func shouldRefreshBattery(force: Bool) -> Bool {
        if force { return true }
        guard let lastBatterySampleTick else { return true }
        return tickCount - lastBatterySampleTick >= Self.batteryRefreshIntervalTicks
    }

    private func shouldRefreshProcesses(force: Bool) -> Bool {
        force || tickCount % Self.processRefreshIntervalTicks == 0
    }

    private func mergeNetworkRates(
        processes: [ProcessMonitor.ProcStat],
        networkProcesses: [NetworkProcessMonitor.ProcStat]
    ) -> [ProcessMonitor.ProcStat] {
        guard !networkProcesses.isEmpty else { return processes }
        var byPid: [Int32: NetworkProcessMonitor.ProcStat] = [:]
        byPid.reserveCapacity(networkProcesses.count)
        for n in networkProcesses { byPid[n.id] = n }
        var out = processes
        for i in out.indices {
            if let net = byPid[out[i].id] {
                out[i].netInPerSec = net.bytesInPerSec
                out[i].netOutPerSec = net.bytesOutPerSec
            }
        }
        return out
    }

    private func buildProcessLeaders(
        from processes: [ProcessMonitor.ProcStat],
        networkProcesses: [NetworkProcessMonitor.ProcStat],
        limit: Int,
        trackEnergy: Bool
    ) -> ProcessLeaders {
        var cpu: [ProcessMonitor.ProcStat] = []
        var mem: [ProcessMonitor.ProcStat] = []
        var dsk: [ProcessMonitor.ProcStat] = []
        var net: [NetworkProcessMonitor.ProcStat] = []
        var nrg: [ProcessMonitor.ProcStat] = []
        cpu.reserveCapacity(limit)
        mem.reserveCapacity(limit)
        dsk.reserveCapacity(limit)
        net.reserveCapacity(limit)
        if trackEnergy { nrg.reserveCapacity(limit) }
        for p in processes {
            Self.topKInsert(into: &cpu, capacity: limit, value: p) { $0.cpuPercent > $1.cpuPercent }
            Self.topKInsert(into: &mem, capacity: limit, value: p) { $0.memoryBytes > $1.memoryBytes }
            Self.topKInsert(into: &dsk, capacity: limit, value: p) {
                ($0.diskReadPerSec + $0.diskWritePerSec) > ($1.diskReadPerSec + $1.diskWritePerSec)
            }
            if trackEnergy {
                Self.topKInsert(into: &nrg, capacity: limit, value: p) { $0.energyImpact > $1.energyImpact }
            }
        }
        for p in networkProcesses {
            Self.topKInsert(into: &net, capacity: limit, value: p) {
                ($0.bytesInPerSec + $0.bytesOutPerSec) > ($1.bytesInPerSec + $1.bytesOutPerSec)
            }
        }
        return ProcessLeaders(cpu: cpu, memory: mem, disk: dsk, network: net, energy: nrg)
    }

    private static func topKInsert<T>(
        into array: inout [T],
        capacity: Int,
        value: T,
        isGreater: (T, T) -> Bool
    ) {
        if array.count < capacity {
            array.append(value)
            var i = array.count - 1
            while i > 0 && isGreater(array[i], array[i - 1]) {
                array.swapAt(i, i - 1)
                i -= 1
            }
            return
        }
        let lastIdx = capacity - 1
        if !isGreater(value, array[lastIdx]) { return }
        array[lastIdx] = value
        var i = lastIdx
        while i > 0 && isGreater(array[i], array[i - 1]) {
            array.swapAt(i, i - 1)
            i -= 1
        }
    }
}
