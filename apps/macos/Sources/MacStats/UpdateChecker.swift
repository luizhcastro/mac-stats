import Foundation

/// Polls the latest GitHub release and exposes it when it's newer than the running bundle.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    struct Release: Decodable {
        let tag_name: String
        let html_url: URL
        var version: String { tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name }
    }

    @Published private(set) var available: Release?

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    func check() async {
        guard let currentVersion,
              let url = URL(string: "https://api.github.com/repos/luizhcastro/mac-stats/releases/latest") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let release = try? JSONDecoder().decode(Release.self, from: data) else { return }
        available = release.version.compare(currentVersion, options: .numeric) == .orderedDescending ? release : nil
    }
}
