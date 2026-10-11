import Foundation
import CoreWLAN

struct WiFiInfo: Sendable {
    var ssid: String?
    var bssid: String?
    var rssi: Int
    var qualityPercent: Double
    var channel: Int?
    var bandGHz: Double?
    var channelWidthMHz: Int?
    var txRateMbps: Double
    var hardwareAddress: String?
    var isConnected: Bool
    var isEnabled: Bool

    static let empty = WiFiInfo(
        ssid: nil, bssid: nil, rssi: 0, qualityPercent: 0,
        channel: nil, bandGHz: nil, channelWidthMHz: nil,
        txRateMbps: 0, hardwareAddress: nil,
        isConnected: false, isEnabled: false
    )
}

final class WiFiMonitor {
    private let client = CWWiFiClient.shared()

    func sample() -> WiFiInfo {
        guard let iface = client.interface() else { return .empty }
        let isEnabled = iface.powerOn()
        guard isEnabled else {
            var info = WiFiInfo.empty
            info.isEnabled = false
            return info
        }

        let ssid = iface.ssid()
        let bssid = iface.bssid()
        let rssi = iface.rssiValue()
        let txRate = iface.transmitRate()
        let channel = iface.wlanChannel()
        let connected = ssid != nil

        var bandGHz: Double?
        var widthMHz: Int?
        var channelNumber: Int?
        if let ch = channel {
            channelNumber = Int(ch.channelNumber)
            switch ch.channelBand {
            case .band2GHz:    bandGHz = 2.4
            case .band5GHz:    bandGHz = 5.0
            case .band6GHz:    bandGHz = 6.0
            case .bandUnknown: bandGHz = nil
            @unknown default:  bandGHz = nil
            }
            switch ch.channelWidth {
            case .width20MHz:   widthMHz = 20
            case .width40MHz:   widthMHz = 40
            case .width80MHz:   widthMHz = 80
            case .width160MHz:  widthMHz = 160
            case .widthUnknown: widthMHz = nil
            @unknown default:   widthMHz = nil
            }
        }

        return WiFiInfo(
            ssid: ssid,
            bssid: bssid,
            rssi: Int(rssi),
            qualityPercent: connected ? Self.rssiToQuality(Int(rssi)) : 0,
            channel: channelNumber,
            bandGHz: bandGHz,
            channelWidthMHz: widthMHz,
            txRateMbps: txRate,
            hardwareAddress: iface.hardwareAddress(),
            isConnected: connected,
            isEnabled: true
        )
    }

    static func rssiToQuality(_ rssi: Int) -> Double {
        let clamped = max(-100, min(-50, rssi))
        return Double(clamped + 100) * 2.0
    }
}
