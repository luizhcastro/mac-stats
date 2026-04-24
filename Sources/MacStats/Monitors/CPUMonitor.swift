import Foundation
import Darwin

final class CPUMonitor {
    struct Sample {
        var usage: Double
        var user: Double
        var system: Double
        var idle: Double
    }

    private var previousLoad: host_cpu_load_info?

    func sample() -> Sample {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        var load = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else {
            return Sample(usage: 0, user: 0, system: 0, idle: 0)
        }

        defer { previousLoad = load }
        guard let prev = previousLoad else {
            return Sample(usage: 0, user: 0, system: 0, idle: 0)
        }

        let user = Double(load.cpu_ticks.0 - prev.cpu_ticks.0)
        let sys = Double(load.cpu_ticks.1 - prev.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2 - prev.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3 - prev.cpu_ticks.3)
        let total = user + sys + idle + nice
        guard total > 0 else {
            return Sample(usage: 0, user: 0, system: 0, idle: 0)
        }
        let used = (user + sys + nice) / total
        return Sample(
            usage: used * 100,
            user: (user + nice) / total * 100,
            system: sys / total * 100,
            idle: idle / total * 100
        )
    }
}
