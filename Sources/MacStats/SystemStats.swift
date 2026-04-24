import Foundation
import Combine

@MainActor
final class SystemStats: ObservableObject {
    @Published var cpu = CPUMonitor.Sample(usage: 0, user: 0, system: 0, idle: 0)
    @Published var memory = MemoryMonitor.Sample(totalBytes: 0, usedBytes: 0, activeBytes: 0, wiredBytes: 0, compressedBytes: 0, freeBytes: 0, pressurePercent: 0)
    @Published var network = NetworkMonitor.Sample(bytesInPerSec: 0, bytesOutPerSec: 0, totalIn: 0, totalOut: 0)
    @Published var battery = BatteryMonitor.Sample(percent: 0, isCharging: false, isPluggedIn: false, timeToEmptyMinutes: nil, timeToFullMinutes: nil, hasBattery: false)
    @Published var disk = DiskMonitor.Sample(readPerSec: 0, writePerSec: 0, totalRead: 0, totalWritten: 0, capacityBytes: 0, freeBytes: 0)
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var processes: [ProcessMonitor.ProcStat] = []

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let diskMonitor = DiskMonitor()
    private let processMonitor = ProcessMonitor()
    private var timer: Timer?
    private var tickCount = 0

    init() {
        _ = cpuMonitor.sample()
        _ = networkMonitor.sample()
        _ = diskMonitor.sample()
        _ = processMonitor.sample()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    deinit { timer?.invalidate() }

    private func tick() {
        cpu = cpuMonitor.sample()
        memory = memoryMonitor.sample()
        network = networkMonitor.sample()
        battery = batteryMonitor.sample()
        disk = diskMonitor.sample()
        cpuHistory.removeFirst()
        cpuHistory.append(cpu.usage)
        tickCount += 1
        if tickCount % 2 == 0 {
            processes = processMonitor.sample()
        }
    }
}
