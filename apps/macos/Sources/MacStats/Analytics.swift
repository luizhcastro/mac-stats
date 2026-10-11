import Foundation

/// Anonymous usage pings to Umami: at most one event per name per UTC day, tagged with a random
/// per-install id so Umami can track retention. No-op when the build has no Umami config
/// (`bundle.sh` without UMAMI_* env, i.e. local builds) or the user opts out in Settings.
@MainActor
enum Analytics {
    static let enabledKey = "analytics.enabled"
    private static let idKey = "analytics.installID"
    private static let sentKey = "analytics.lastSent"

    private static let host = Bundle.main.object(forInfoDictionaryKey: "MacStatsUmamiHost") as? String ?? ""
    private static let websiteID = Bundle.main.object(forInfoDictionaryKey: "MacStatsUmamiWebsiteID") as? String ?? ""
    private static var inFlight: Set<String> = []

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func track(_ name: String) {
        guard !host.isEmpty, !websiteID.isEmpty, isEnabled, !inFlight.contains(name),
              let url = URL(string: host + "/api/send") else { return }
        let today = ISO8601DateFormatter.string(from: Date(), timeZone: .gmt, formatOptions: .withFullDate)
        let sent = UserDefaults.standard.dictionary(forKey: sentKey) as? [String: String] ?? [:]
        guard sent[name] != today else { return }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "x86_64"
        #endif
        let body: [String: Any] = [
            "type": "event",
            "payload": [
                "website": websiteID,
                "id": installID,
                "hostname": "app",
                "url": "/app",
                "name": name,
                "language": Locale.preferredLanguages.first ?? "en",
                "data": ["version": version, "macOS": "\(os.majorVersion).\(os.minorVersion)", "arch": arch],
            ],
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Umami drops bot-looking user agents and parses OS from this, so mimic a Mac browser UA.
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) MacStats/\(version)", forHTTPHeaderField: "User-Agent")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        inFlight.insert(name)
        Task {
            let ok = (try? await URLSession.shared.data(for: req)).map { ($0.1 as? HTTPURLResponse)?.statusCode == 200 } ?? false
            inFlight.remove(name)
            guard ok else { return }
            var sent = UserDefaults.standard.dictionary(forKey: sentKey) as? [String: String] ?? [:]
            sent[name] = today
            UserDefaults.standard.set(sent, forKey: sentKey)
        }
    }

    private static var installID: String {
        if let id = UserDefaults.standard.string(forKey: idKey) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: idKey)
        return id
    }
}
