import Foundation

struct ProcessLeaders: Sendable {
    var cpu: [ProcessMonitor.ProcStat]
    var memory: [ProcessMonitor.ProcStat]
    var disk: [ProcessMonitor.ProcStat]
    var network: [NetworkProcessMonitor.ProcStat]

    static let empty = ProcessLeaders(cpu: [], memory: [], disk: [], network: [])
}

struct SystemSnapshot: Sendable {
    var cpu: CPUMonitor.Sample
    var memory: MemoryMonitor.Sample
    var network: NetworkMonitor.Sample
    var battery: BatteryMonitor.Sample
    var disk: DiskMonitor.Sample
    var cpuHistory: [Double]
    var processLeaders: ProcessLeaders

    static let empty = SystemSnapshot(
        cpu: CPUMonitor.Sample(usage: 0, user: 0, system: 0, idle: 0),
        memory: MemoryMonitor.Sample(totalBytes: 0, usedBytes: 0, activeBytes: 0, wiredBytes: 0, compressedBytes: 0, freeBytes: 0, pressurePercent: 0),
        network: NetworkMonitor.Sample(bytesInPerSec: 0, bytesOutPerSec: 0, totalIn: 0, totalOut: 0),
        battery: BatteryMonitor.Sample(percent: 0, isCharging: false, isPluggedIn: false, timeToEmptyMinutes: nil, timeToFullMinutes: nil, hasBattery: false),
        disk: DiskMonitor.Sample(readPerSec: 0, writePerSec: 0, totalRead: 0, totalWritten: 0, capacityBytes: 0, freeBytes: 0),
        cpuHistory: Array(repeating: 0, count: 60),
        processLeaders: .empty
    )
}

@MainActor
final class SystemStats: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.empty

    private let sampler = StatsSampler()
    private var samplingTask: Task<Void, Never>?

    var cpu: CPUMonitor.Sample { snapshot.cpu }
    var memory: MemoryMonitor.Sample { snapshot.memory }
    var network: NetworkMonitor.Sample { snapshot.network }
    var battery: BatteryMonitor.Sample { snapshot.battery }
    var disk: DiskMonitor.Sample { snapshot.disk }
    var cpuHistory: [Double] { snapshot.cpuHistory }
    var processLeaders: ProcessLeaders { snapshot.processLeaders }

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

    func setDetailSamplingEnabled(_ enabled: Bool) {
        if enabled {
            Task { [weak self] in
                guard let self else { return }
                await sampler.setDetailSamplingEnabled(true)
                await refresh(forceDetailRefresh: true)
            }
            return
        }

        Task { [sampler] in
            await sampler.setDetailSamplingEnabled(false)
        }
    }

    private func refresh(forceDetailRefresh: Bool = false) async {
        snapshot = await sampler.sample(forceDetailRefresh: forceDetailRefresh)
    }
}

private actor StatsSampler {
    private static let processRefreshIntervalTicks = 2
    private static let batteryRefreshIntervalTicks = 30

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let diskMonitor = DiskMonitor()
    private let processMonitor = ProcessMonitor()
    private let networkProcessMonitor = NetworkProcessMonitor()
    private var tickCount = 0
    private var detailSamplingEnabled = false
    private static let cpuHistoryCapacity = 60
    private var cpuHistoryRing = [Double](repeating: 0, count: StatsSampler.cpuHistoryCapacity)
    private var cpuHistoryHead = 0
    private var lastBattery = BatteryMonitor.Sample(percent: 0, isCharging: false, isPluggedIn: false, timeToEmptyMinutes: nil, timeToFullMinutes: nil, hasBattery: false)
    private var lastBatterySampleTick: Int?
    private var lastProcessLeaders = ProcessLeaders.empty

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

    func sample(forceDetailRefresh: Bool = false) -> SystemSnapshot {
        let cpu = cpuMonitor.sample()
        let memory = memoryMonitor.sample()
        let network = networkMonitor.sample()
        let disk = diskMonitor.sample(
            includeVolumeStats: detailSamplingEnabled,
            forceVolumeStatsRefresh: forceDetailRefresh
        )

        tickCount += 1
        cpuHistoryRing[cpuHistoryHead] = cpu.usage
        cpuHistoryHead = (cpuHistoryHead + 1) % Self.cpuHistoryCapacity

        if detailSamplingEnabled && shouldRefreshBattery(force: forceDetailRefresh) {
            lastBattery = batteryMonitor.sample()
            lastBatterySampleTick = tickCount
        }

        if detailSamplingEnabled && shouldRefreshProcesses(force: forceDetailRefresh) {
            let processes = processMonitor.sample()
            let netProcesses = networkProcessMonitor.sample()
            lastProcessLeaders = buildProcessLeaders(from: processes, networkProcesses: netProcesses, limit: 8)
        }

        return SystemSnapshot(
            cpu: cpu,
            memory: memory,
            network: network,
            battery: lastBattery,
            disk: disk,
            cpuHistory: linearizedCPUHistory(),
            processLeaders: lastProcessLeaders
        )
    }

    private func linearizedCPUHistory() -> [Double] {
        let cap = Self.cpuHistoryCapacity
        var out = [Double](repeating: 0, count: cap)
        for i in 0..<cap {
            out[i] = cpuHistoryRing[(cpuHistoryHead + i) % cap]
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

    private func buildProcessLeaders(
        from processes: [ProcessMonitor.ProcStat],
        networkProcesses: [NetworkProcessMonitor.ProcStat],
        limit: Int
    ) -> ProcessLeaders {
        var cpu: [ProcessMonitor.ProcStat] = []
        var mem: [ProcessMonitor.ProcStat] = []
        var dsk: [ProcessMonitor.ProcStat] = []
        var net: [NetworkProcessMonitor.ProcStat] = []
        cpu.reserveCapacity(limit)
        mem.reserveCapacity(limit)
        dsk.reserveCapacity(limit)
        net.reserveCapacity(limit)
        for p in processes {
            Self.topKInsert(into: &cpu, capacity: limit, value: p) { $0.cpuPercent > $1.cpuPercent }
            Self.topKInsert(into: &mem, capacity: limit, value: p) { $0.memoryBytes > $1.memoryBytes }
            Self.topKInsert(into: &dsk, capacity: limit, value: p) {
                ($0.diskReadPerSec + $0.diskWritePerSec) > ($1.diskReadPerSec + $1.diskWritePerSec)
            }
        }
        for p in networkProcesses {
            Self.topKInsert(into: &net, capacity: limit, value: p) {
                ($0.bytesInPerSec + $0.bytesOutPerSec) > ($1.bytesInPerSec + $1.bytesOutPerSec)
            }
        }
        return ProcessLeaders(cpu: cpu, memory: mem, disk: dsk, network: net)
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
