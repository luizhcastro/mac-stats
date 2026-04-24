import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let stats: SystemStats
    private let prefs: DisplayPreferences
    private var hostingView: NSHostingView<MenuBarLabel>?
    private var cancellables: Set<AnyCancellable> = []
    private var pendingResize = false

    init(stats: SystemStats, prefs: DisplayPreferences) {
        self.stats = stats
        self.prefs = prefs

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(stats: stats, prefs: prefs)
        )

        configureButton()

        prefs.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.requestResize()
                }
            }
            .store(in: &cancellables)
    }

    private func requestResize() {
        if popover.isShown {
            pendingResize = true
        } else {
            resizeButton()
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let label = MenuBarLabel(stats: stats, prefs: prefs)
        let host = NSHostingView(rootView: label)
        host.translatesAutoresizingMaskIntoConstraints = false
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 6),
            host.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -6),
            host.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        hostingView = host
        button.target = self
        button.action = #selector(togglePopover(_:))
        resizeButton()
    }

    private func resizeButton() {
        guard let host = hostingView else { return }
        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        statusItem.length = fitting.width + 12
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let button = statusItem.button else { return }
        popover.delegate = popoverDelegate
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.becomeKey()
    }

    private lazy var popoverDelegate: PopoverDelegate = PopoverDelegate { [weak self] in
        guard let self else { return }
        if self.pendingResize {
            self.pendingResize = false
            self.resizeButton()
        }
    }
}

private final class PopoverDelegate: NSObject, NSPopoverDelegate {
    let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func popoverDidClose(_ notification: Notification) { onClose() }
}
