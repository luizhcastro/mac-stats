import Foundation
import Sparkle

/// Sparkle updater. Scheduled checks that find an update while the user isn't looking surface as a
/// banner in the popover (gentle reminder) instead of stealing focus from a menu bar app; clicking
/// it, or "Check for Updates…", hands off to Sparkle's download / install / relaunch UI.
@MainActor
final class UpdateChecker: NSObject, ObservableObject, @preconcurrency SPUStandardUserDriverDelegate {
    static let shared = UpdateChecker()

    @Published private(set) var availableVersion: String?

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self
    )

    func start() {
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !handleShowingUpdate { availableVersion = update.displayVersionString }
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
    }
}
