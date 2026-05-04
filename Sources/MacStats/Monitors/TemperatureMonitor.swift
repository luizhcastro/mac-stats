import Foundation
import IOKit

private let kHIDPage_AppleVendor: Int = 0xff00
private let kHIDUsage_AppleVendor_TemperatureSensor: Int = 0x0005
private let kIOHIDEventTypeTemperature: Int32 = 15

@_silgen_name("IOHIDEventSystemClientCreate")
private func _IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func _IOHIDEventSystemClientSetMatching(_ client: AnyObject, _ matching: CFDictionary)

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func _IOHIDEventSystemClientCopyServices(_ client: AnyObject) -> Unmanaged<CFArray>?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func _IOHIDServiceClientCopyProperty(_ service: AnyObject, _ property: CFString) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func _IOHIDServiceClientCopyEvent(_ service: AnyObject, _ type: Int32, _ options: UInt32, _ timestamp: UInt64) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDEventGetFloatValue")
private func _IOHIDEventGetFloatValue(_ event: AnyObject, _ field: Int32) -> Double

final class TemperatureMonitor {
    struct Sample: Sendable {
        var cpuCelsius: Double
        var gpuCelsius: Double
        var maxCelsius: Double
        var sensorCount: Int

        var hasReadings: Bool { sensorCount > 0 }

        static let empty = Sample(cpuCelsius: -1, gpuCelsius: -1, maxCelsius: 0, sensorCount: 0)
    }

    private enum Category: UInt8 { case other, cpu, gpu }

    private let client: AnyObject?
    private let services: [AnyObject]
    private let categories: [Category]
    private let temperatureField: Int32 = Int32(kIOHIDEventTypeTemperature) << 16

    init() {
        guard let unmanagedClient = _IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
            self.client = nil
            self.services = []
            self.categories = []
            return
        }
        let client = unmanagedClient.takeRetainedValue()

        let match: [String: Any] = [
            "PrimaryUsagePage": kHIDPage_AppleVendor,
            "PrimaryUsage": kHIDUsage_AppleVendor_TemperatureSensor
        ]
        _IOHIDEventSystemClientSetMatching(client, match as CFDictionary)

        guard let unmanagedServices = _IOHIDEventSystemClientCopyServices(client) else {
            self.client = client
            self.services = []
            self.categories = []
            return
        }

        let cfArray = unmanagedServices.takeRetainedValue()
        let count = CFArrayGetCount(cfArray)
        var services: [AnyObject] = []
        var categories: [Category] = []
        services.reserveCapacity(count)
        categories.reserveCapacity(count)

        for i in 0..<count {
            guard let raw = CFArrayGetValueAtIndex(cfArray, i) else { continue }
            let svc = unsafeBitCast(raw, to: AnyObject.self)
            services.append(svc)

            let nameRef = _IOHIDServiceClientCopyProperty(svc, "Product" as CFString)?.takeRetainedValue()
            let name = (nameRef as? String)?.uppercased() ?? ""
            categories.append(Self.classify(name: name))
        }

        self.client = client
        self.services = services
        self.categories = categories
    }

    private static func classify(name: String) -> Category {
        if name.contains("GPU") { return .gpu }
        if name.contains("CPU")
            || name.contains("PACC")
            || name.contains("EACC")
            || name.contains("PMP")
            || name.contains("SOC") {
            return .cpu
        }
        return .other
    }

    func sample() -> Sample {
        if services.isEmpty { return .empty }

        var cpuSum: Double = 0
        var cpuCount: Int = 0
        var gpuSum: Double = 0
        var gpuCount: Int = 0
        var maxVal: Double = 0
        var read: Int = 0

        for i in 0..<services.count {
            guard let unmanagedEvent = _IOHIDServiceClientCopyEvent(
                services[i],
                kIOHIDEventTypeTemperature,
                0,
                0
            ) else { continue }
            let event = unmanagedEvent.takeRetainedValue()
            let v = _IOHIDEventGetFloatValue(event, temperatureField)
            if v <= 0 || v > 200 { continue }

            read += 1
            if v > maxVal { maxVal = v }

            switch categories[i] {
            case .cpu:
                cpuSum += v
                cpuCount += 1
            case .gpu:
                gpuSum += v
                gpuCount += 1
            case .other:
                break
            }
        }

        return Sample(
            cpuCelsius: cpuCount > 0 ? cpuSum / Double(cpuCount) : -1,
            gpuCelsius: gpuCount > 0 ? gpuSum / Double(gpuCount) : -1,
            maxCelsius: maxVal,
            sensorCount: read
        )
    }
}
