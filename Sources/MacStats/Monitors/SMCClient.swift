import Foundation
import IOKit

private struct SMCKeyData_vers_t {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCKeyData_pLimitData_t {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyData_keyInfo_t {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCKeyData_t {
    var key: UInt32 = 0
    var vers = SMCKeyData_vers_t()
    var pLimitData = SMCKeyData_pLimitData_t()
    var keyInfo = SMCKeyData_keyInfo_t()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

enum SMCDataType: String {
    case ui8  = "ui8 "
    case ui16 = "ui16"
    case ui32 = "ui32"
    case sp78 = "sp78"
    case flt  = "flt "
    case fpe2 = "fpe2"
    case fp1f = "fp1f"
    case fp4c = "fp4c"
    case fp5b = "fp5b"
    case fp6a = "fp6a"
    case fp79 = "fp79"
    case fp88 = "fp88"
    case fp97 = "fp97"
    case si8  = "si8 "
    case si16 = "si16"
}

struct SMCKeyValue {
    let dataType: String
    let bytes: [UInt8]

    func asDouble() -> Double? {
        guard let type = SMCDataType(rawValue: dataType) else {
            return Self.fallbackNumeric(bytes: bytes, dataType: dataType)
        }
        switch type {
        case .ui8:
            return bytes.count >= 1 ? Double(bytes[0]) : nil
        case .ui16:
            guard bytes.count >= 2 else { return nil }
            let v = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(v)
        case .ui32:
            guard bytes.count >= 4 else { return nil }
            let v = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
            return Double(v)
        case .si8:
            return bytes.count >= 1 ? Double(Int8(bitPattern: bytes[0])) : nil
        case .si16:
            guard bytes.count >= 2 else { return nil }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw))
        case .sp78:
            guard bytes.count >= 2 else { return nil }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw)) / 256.0
        case .flt:
            guard bytes.count >= 4 else { return nil }
            var f: Float = 0
            withUnsafeMutableBytes(of: &f) { ptr in
                ptr[0] = bytes[0]; ptr[1] = bytes[1]; ptr[2] = bytes[2]; ptr[3] = bytes[3]
            }
            return Double(f)
        case .fpe2:
            guard bytes.count >= 2 else { return nil }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4.0
        case .fp1f, .fp4c, .fp5b, .fp6a, .fp79, .fp88, .fp97:
            guard bytes.count >= 2 else { return nil }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            let frac: Double
            switch type {
            case .fp1f: frac = 32768
            case .fp4c: frac = 4096
            case .fp5b: frac = 2048
            case .fp6a: frac = 1024
            case .fp79: frac = 512
            case .fp88: frac = 256
            case .fp97: frac = 128
            default: frac = 1
            }
            return Double(raw) / frac
        }
    }

    private static func fallbackNumeric(bytes: [UInt8], dataType: String) -> Double? {
        guard bytes.count >= 2 else {
            return bytes.count == 1 ? Double(bytes[0]) : nil
        }
        let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        return Double(raw)
    }
}

final class SMCClient {
    private static let kSMCHandleYPCEvent: UInt32 = 2
    private static let kSMCReadKey: UInt8 = 5
    private static let kSMCGetKeyInfo: UInt8 = 9

    private(set) var isOpen = false
    private var connection: io_connect_t = 0
    private var keyInfoCache: [UInt32: SMCKeyData_keyInfo_t] = [:]

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        var conn: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &conn)
        if result == kIOReturnSuccess {
            connection = conn
            isOpen = true
        }
    }

    deinit {
        if isOpen {
            IOServiceClose(connection)
        }
    }

    static func encode(_ key: String) -> UInt32 {
        precondition(key.count == 4)
        let bytes = Array(key.utf8)
        return (UInt32(bytes[0]) << 24)
             | (UInt32(bytes[1]) << 16)
             | (UInt32(bytes[2]) << 8)
             |  UInt32(bytes[3])
    }

    static func decodeFourCC(_ value: UInt32) -> String {
        let b: [UInt8] = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
        return String(bytes: b, encoding: .ascii) ?? ""
    }

    func readKey(_ keyString: String) -> SMCKeyValue? {
        guard isOpen, keyString.count == 4 else { return nil }
        let key = Self.encode(keyString)

        let keyInfo: SMCKeyData_keyInfo_t
        if let cached = keyInfoCache[key] {
            keyInfo = cached
        } else {
            var info = SMCKeyData_t()
            info.key = key
            info.data8 = Self.kSMCGetKeyInfo
            guard call(input: &info) else { return nil }
            keyInfo = info.keyInfo
            keyInfoCache[key] = keyInfo
        }
        let dataSize = keyInfo.dataSize
        let dataType = keyInfo.dataType
        guard dataSize > 0, dataSize <= 32 else { return nil }

        var read = SMCKeyData_t()
        read.key = key
        read.keyInfo.dataSize = dataSize
        read.data8 = Self.kSMCReadKey
        guard call(input: &read) else { return nil }

        var out = [UInt8](repeating: 0, count: Int(dataSize))
        withUnsafePointer(to: read.bytes) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 32) { raw in
                for i in 0..<Int(dataSize) { out[i] = raw[i] }
            }
        }
        return SMCKeyValue(dataType: Self.decodeFourCC(dataType), bytes: out)
    }

    private func call(input: inout SMCKeyData_t) -> Bool {
        let inSize = MemoryLayout<SMCKeyData_t>.size
        var outSize = inSize
        var output = SMCKeyData_t()
        let result = withUnsafePointer(to: &input) { inPtr -> kern_return_t in
            withUnsafeMutablePointer(to: &output) { outPtr -> kern_return_t in
                IOConnectCallStructMethod(
                    connection,
                    Self.kSMCHandleYPCEvent,
                    inPtr, inSize,
                    outPtr, &outSize
                )
            }
        }
        guard result == kIOReturnSuccess else { return false }
        if output.result != 0 { return false }
        input = output
        return true
    }
}
