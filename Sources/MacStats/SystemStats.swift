import Foundation

enum ThermalLevel: UInt8, Sendable {
    case nominal, fair, serious, critical, unknown

    var label: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        case .unknown: return "Unknown"
        }
    }

    static func current() -> ThermalLevel {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .unknown
        }
    }
}

struct ProcessLeaders: Sendable {
    var cpu: [ProcessMonitor.ProcStat]
    var memory: [ProcessMonitor.ProcStat]
    var disk: [ProcessMonitor.ProcStat]
    var network: [NetworkProcessMonitor.ProcStat]
    var energy: [ProcessMonitor.ProcStat]

    static let empty = ProcessLeaders(cpu: [], memory: [], disk: [], network: [], energy: [])
}

enum HistoryRange: String, Sendable, CaseIterable, Identifiable {
    case minute, hour, day
    var id: String { rawValue }
    var label: String {
        switch self {
        case .minute: return "1m"
        case .hour:   return "1h"
        case .day:    return "24h"
        }
    }
}

struct MetricSeries: Sendable {
    var minute: [Double]
    var hour: [Double]
    var day: [Double]

    func values(for range: HistoryRange) -> [Double] {
        switch range {
        case .minute: return minute
        case .hour:   return hour
        case .day:    return day
        }
    }

    static let empty = MetricSeries(
        minute: Array(repeating: 0, count: 60),
        hour: Array(repeating: 0, count: 360),
        day: Array(repeating: 0, count: 1440)
    )
}

struct MetricHistory: Sendable {
    var cpu: MetricSeries
    var memoryPercent: MetricSeries
    var networkIn: MetricSeries
    var networkOut: MetricSeries
    var diskRead: MetricSeries
    var diskWrite: MetricSeries
    var temperature: MetricSeries
    var batteryPercent: [Double]
    var batteryWattage: [Double]

    static let empty = MetricHistory(
        cpu: .empty,
        memoryPercent: .empty,
        networkIn: .empty,
        networkOut: .empty,
        diskRead: .empty,
        diskWrite: .empty,
        temperature: .empty,
        batteryPercent: Array(repeating: 0, count: 60),
        batteryWattage: Array(repeating: 0, count: 60)
    )
}

struct SystemSnapshot: Sendable {
    var cpu: CPUMonitor.Sample
    var memory: MemoryMonitor.Sample
    var network: NetworkMonitor.Sample
    var wifi: WiFiInfo
    var publicIP: String?
    var battery: BatteryMonitor.Sample
    var disk: DiskMonitor.Sample
    var temperature: TemperatureMonitor.Sample
    var gpu: GPUMonitor.Sample
    var fans: FanMonitor.Sample
    var thermal: ThermalLevel
    var history: MetricHistory
    var processLeaders: ProcessLeaders
    var allProcesses: [ProcessMonitor.ProcStat]
    var processGeneration: UInt64

    static let empty = SystemSnapshot(
        cpu: .empty,
        memory: .empty,
        network: NetworkMonitor.Sample(bytesInPerSec: 0, bytesOutPerSec: 0, totalIn: 0, totalOut: 0, interfaces: []),
        wifi: .empty,
        publicIP: nil,
        battery: .empty,
        disk: DiskMonitor.Sample(readPerSec: 0, writePerSec: 0, totalRead: 0, totalWritten: 0, capacityBytes: 0, freeBytes: 0, volumes: []),
        temperature: .empty,
        gpu: .empty,
        fans: .empty,
        thermal: .unknown,
        history: .empty,
        processLeaders: .empty,
        allProcesses: [],
        processGeneration: 0
    )
}

@MainActor
final class SystemStats: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.empty

    private let sampler = StatsSampler()
    private var samplingTask: Task<Void, Never>?
    private var detailRetainCount = 0
    private var fullProcessListRetainCount = 0
    private var networkProcessRetainCount = 0

    var cpu: CPUMonitor.Sample { snapshot.cpu }
    var memory: MemoryMonitor.Sample { snapshot.memory }
    var network: NetworkMonitor.Sample { snapshot.network }
    var wifi: WiFiInfo { snapshot.wifi }
    var publicIP: String? { snapshot.publicIP }
    var battery: BatteryMonitor.Sample { snapshot.battery }
    var disk: DiskMonitor.Sample { snapshot.disk }
    var temperature: TemperatureMonitor.Sample { snapshot.temperature }
    var gpu: GPUMonitor.Sample { snapshot.gpu }
    var fans: FanMonitor.Sample { snapshot.fans }
    var thermal: ThermalLevel { snapshot.thermal }
    var history: MetricHistory { snapshot.history }
    var cpuHistory: [Double] { snapshot.history.cpu.minute }
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

    func retainNetworkProcessSampling() {
        networkProcessRetainCount += 1
        if networkProcessRetainCount == 1 {
            Task { [sampler] in
                await sampler.setNetworkProcessSamplingEnabled(true)
            }
        }
    }

    func releaseNetworkProcessSampling() {
        guard networkProcessRetainCount > 0 else { return }
        networkProcessRetainCount -= 1
        if networkProcessRetainCount == 0 {
            Task { [sampler] in
                await sampler.setNetworkProcessSamplingEnabled(false)
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

    func setTemperatureAlwaysOn(_ enabled: Bool) {
        Task { [sampler] in
            await sampler.setTemperatureAlwaysOn(enabled)
        }
    }

    private func refresh(forceDetailRefresh: Bool = false) async {
        snapshot = await sampler.sample(forceDetailRefresh: forceDetailRefresh)
    }
}

private struct MetricRings {
    static let minuteCapacity = 60
    static let hourCapacity = 360
    static let dayCapacity = 1440
    static let hourDownsampleEvery = 10
    static let dayDownsampleEvery = 60

    var minute: [Double]
    var hour: [Double]
    var day: [Double]
    var minuteHead = 0
    var hourHead = 0
    var dayHead = 0
    var hourSum: Double = 0
    var hourCount: Int = 0
    var daySum: Double = 0
    var dayCount: Int = 0

    init() {
        minute = [Double](repeating: 0, count: Self.minuteCapacity)
        hour = [Double](repeating: 0, count: Self.hourCapacity)
        day = [Double](repeating: 0, count: Self.dayCapacity)
    }

    mutating func append(_ v: Double) {
        minute[minuteHead] = v
        minuteHead = (minuteHead + 1) % Self.minuteCapacity

        hourSum += v
        hourCount += 1
        if hourCount >= Self.hourDownsampleEvery {
            hour[hourHead] = hourSum / Double(hourCount)
            hourHead = (hourHead + 1) % Self.hourCapacity
            hourSum = 0
            hourCount = 0
        }

        daySum += v
        dayCount += 1
        if dayCount >= Self.dayDownsampleEvery {
            day[dayHead] = daySum / Double(dayCount)
            dayHead = (dayHead + 1) % Self.dayCapacity
            daySum = 0
            dayCount = 0
        }
    }

    func snapshot() -> MetricSeries {
        MetricSeries(
            minute: linearized(minute, head: minuteHead),
            hour: linearized(hour, head: hourHead),
            day: linearized(day, head: dayHead)
        )
    }

    private func linearized(_ ring: [Double], head: Int) -> [Double] {
        let cap = ring.count
        var out = [Double](repeating: 0, count: cap)
        for i in 0..<cap { out[i] = ring[(head + i) % cap] }
        return out
    }
}

private actor StatsSampler {
    private static let processRefreshIntervalTicks = 2
    private static let batteryRefreshIntervalTicks = 30
    private static let temperatureRefreshIntervalTicks = 5
    private static let gpuRefreshIntervalTicks = 5
    private static let fanRefreshIntervalTicks = 5
    private static let historyCapacity = 60

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let diskMonitor = DiskMonitor()
    private let processMonitor = ProcessMonitor()
    private let networkProcessMonitor = NetworkProcessMonitor()
    private let temperatureMonitor = TemperatureMonitor()
    private let wifiMonitor = WiFiMonitor()
    private let gpuMonitor = GPUMonitor()
    private let fanMonitor = FanMonitor()

    private var tickCount = 0
    private var detailSamplingEnabled = false
    private var energyTrackingEnabled = false
    private var fullProcessListEnabled = false
    private var networkProcessSamplingEnabled = false
    private var temperatureAlwaysOn = false

    private var cpuRings = MetricRings()
    private var memRings = MetricRings()
    private var netInRings = MetricRings()
    private var netOutRings = MetricRings()
    private var diskReadRings = MetricRings()
    private var diskWriteRings = MetricRings()
    private var temperatureRings = MetricRings()

    private var batteryPercentRing = [Double](repeating: 0, count: StatsSampler.historyCapacity)
    private var batteryWattageRing = [Double](repeating: 0, count: StatsSampler.historyCapacity)
    private var batteryRingHead = 0

    private var lastBattery = BatteryMonitor.Sample.empty
    private var lastBatterySampleTick: Int?
    private var lastTemperature = TemperatureMonitor.Sample.empty
    private var lastTemperatureSampleTick: Int?
    private var lastGPU = GPUMonitor.Sample.empty
    private var lastGPUSampleTick: Int?
    private var lastFans = FanMonitor.Sample.empty
    private var lastFansSampleTick: Int?
    private var lastProcessLeaders = ProcessLeaders.empty
    private var lastProcessList: [ProcessMonitor.ProcStat] = []
    private var processGeneration: UInt64 = 0

    private var publicIP: String?
    private var publicIPFetchedAt: Date?
    private var publicIPInFlight = false
    private var lastWiFi = WiFiInfo.empty
    private static let publicIPTTL: TimeInterval = 600

    init() {
        _ = cpuMonitor.sample()
        _ = networkMonitor.sample()
        _ = diskMonitor.sample(includeVolumeStats: false)
    }

    func setDetailSamplingEnabled(_ enabled: Bool) {
        detailSamplingEnabled = enabled
    }

    func setTemperatureAlwaysOn(_ enabled: Bool) {
        temperatureAlwaysOn = enabled
    }

    func setNetworkProcessSamplingEnabled(_ enabled: Bool) {
        guard networkProcessSamplingEnabled != enabled else { return }
        networkProcessSamplingEnabled = enabled
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
        let cpu = cpuMonitor.sample(includeCores: detailSamplingEnabled)
        let memory = memoryMonitor.sample()
        let network = networkMonitor.sample(includeInterfaceDetail: detailSamplingEnabled)
        let wifi = detailSamplingEnabled ? wifiMonitor.sample() : lastWiFi
        if detailSamplingEnabled { lastWiFi = wifi }
        let disk = diskMonitor.sample(
            includeVolumeStats: detailSamplingEnabled,
            forceVolumeStatsRefresh: forceDetailRefresh
        )

        if detailSamplingEnabled {
            maybeFetchPublicIP()
        }

        tickCount += 1
        let memTotal = max(memory.totalBytes, 1)
        let memPercent = Double(memory.usedBytes) / Double(memTotal) * 100.0
        let tempPoint = lastTemperature.cpuCelsius > 0
            ? lastTemperature.cpuCelsius
            : lastTemperature.maxCelsius
        cpuRings.append(cpu.usage)
        memRings.append(memPercent)
        netInRings.append(network.bytesInPerSec)
        netOutRings.append(network.bytesOutPerSec)
        diskReadRings.append(disk.readPerSec)
        diskWriteRings.append(disk.writePerSec)
        temperatureRings.append(max(tempPoint, 0))

        if detailSamplingEnabled && shouldRefreshBattery(force: forceDetailRefresh) {
            lastBattery = batteryMonitor.sample()
            lastBatterySampleTick = tickCount
            if lastBattery.hasBattery {
                batteryPercentRing[batteryRingHead] = lastBattery.percent
                let raw = lastBattery.wattage ?? 0
                let signed = lastBattery.isCharging ? raw : -raw
                batteryWattageRing[batteryRingHead] = signed
                batteryRingHead = (batteryRingHead + 1) % Self.historyCapacity
            }
        }

        if (detailSamplingEnabled || temperatureAlwaysOn) && shouldRefreshTemperature(force: forceDetailRefresh) {
            lastTemperature = temperatureMonitor.sample()
            lastTemperatureSampleTick = tickCount
        }

        if detailSamplingEnabled && shouldRefreshGPU(force: forceDetailRefresh) {
            lastGPU = gpuMonitor.sample()
            lastGPUSampleTick = tickCount
        }

        if detailSamplingEnabled && shouldRefreshFans(force: forceDetailRefresh) {
            lastFans = fanMonitor.sample()
            lastFansSampleTick = tickCount
        }

        let thermal = ThermalLevel.current()

        if detailSamplingEnabled && shouldRefreshProcesses(force: forceDetailRefresh) {
            var processes = processMonitor.sample()
            let netProcesses = networkProcessSamplingEnabled
                ? networkProcessMonitor.sample()
                : []
            if fullProcessListEnabled {
                mergeNetworkRates(into: &processes, networkProcesses: netProcesses)
                lastProcessList = processes
            }
            lastProcessLeaders = buildProcessLeaders(
                from: processes,
                networkProcesses: netProcesses,
                limit: 8,
                trackEnergy: energyTrackingEnabled
            )
            processGeneration &+= 1
        }

        let history: MetricHistory = detailSamplingEnabled
            ? MetricHistory(
                cpu: cpuRings.snapshot(),
                memoryPercent: memRings.snapshot(),
                networkIn: netInRings.snapshot(),
                networkOut: netOutRings.snapshot(),
                diskRead: diskReadRings.snapshot(),
                diskWrite: diskWriteRings.snapshot(),
                temperature: temperatureRings.snapshot(),
                batteryPercent: linearized(batteryPercentRing, head: batteryRingHead),
                batteryWattage: linearized(batteryWattageRing, head: batteryRingHead)
            )
            : .empty

        return SystemSnapshot(
            cpu: cpu,
            memory: memory,
            network: network,
            wifi: wifi,
            publicIP: publicIP,
            battery: lastBattery,
            disk: disk,
            temperature: lastTemperature,
            gpu: lastGPU,
            fans: lastFans,
            thermal: thermal,
            history: history,
            processLeaders: lastProcessLeaders,
            allProcesses: lastProcessList,
            processGeneration: processGeneration
        )
    }

    private func maybeFetchPublicIP() {
        if publicIPInFlight { return }
        let now = Date()
        let stale = publicIPFetchedAt.map { now.timeIntervalSince($0) > Self.publicIPTTL } ?? true
        guard stale else { return }
        publicIPInFlight = true
        Task { [weak self] in
            let ip = await StatsSampler.fetchPublicIP()
            await self?.applyPublicIP(ip)
        }
    }

    private func applyPublicIP(_ ip: String?) {
        publicIPInFlight = false
        publicIPFetchedAt = Date()
        if let ip { publicIP = ip }
    }

    private static func fetchPublicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let s = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        } catch {
            return nil
        }
    }

    private func linearized(_ ring: [Double], head: Int) -> [Double] {
        let cap = Self.historyCapacity
        var out = [Double](repeating: 0, count: cap)
        for i in 0..<cap {
            out[i] = ring[(head + i) % cap]
        }
        return out
    }

    private func shouldRefreshBattery(force: Bool) -> Bool {
        if force { return true }
        guard let lastBatterySampleTick else { return true }
        return tickCount - lastBatterySampleTick >= Self.batteryRefreshIntervalTicks
    }

    private func shouldRefreshTemperature(force: Bool) -> Bool {
        if force { return true }
        guard let lastTemperatureSampleTick else { return true }
        return tickCount - lastTemperatureSampleTick >= Self.temperatureRefreshIntervalTicks
    }

    private func shouldRefreshGPU(force: Bool) -> Bool {
        if force { return true }
        guard let lastGPUSampleTick else { return true }
        return tickCount - lastGPUSampleTick >= Self.gpuRefreshIntervalTicks
    }

    private func shouldRefreshFans(force: Bool) -> Bool {
        if force { return true }
        guard let lastFansSampleTick else { return true }
        return tickCount - lastFansSampleTick >= Self.fanRefreshIntervalTicks
    }

    private func shouldRefreshProcesses(force: Bool) -> Bool {
        force || tickCount % Self.processRefreshIntervalTicks == 0
    }

    private func mergeNetworkRates(
        into processes: inout [ProcessMonitor.ProcStat],
        networkProcesses: [NetworkProcessMonitor.ProcStat]
    ) {
        guard !networkProcesses.isEmpty else { return }
        var byPid: [Int32: (Double, Double)] = [:]
        byPid.reserveCapacity(networkProcesses.count)
        for n in networkProcesses { byPid[n.id] = (n.bytesInPerSec, n.bytesOutPerSec) }
        for i in processes.indices {
            if let net = byPid[processes[i].id] {
                processes[i].netInPerSec = net.0
                processes[i].netOutPerSec = net.1
            }
        }
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
