import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let stats: SystemStats
    private let prefs: DisplayPreferences
    private let snapshot: MenuBarSnapshot
    private var hostingView: NSHostingView<MenuBarLabel>?
    private var cancellables: Set<AnyCancellable> = []
    private var pendingSnapshot: [BarMetric]?

    init(stats: SystemStats, prefs: DisplayPreferences) {
        self.stats = stats
        self.prefs = prefs
        self.snapshot = MenuBarSnapshot(selected: prefs.selected)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(stats: stats, prefs: prefs)
        )

        configureButton()

        prefs.$selected
            .dropFirst()
            .sink { [weak self] newValue in
                DispatchQueue.main.async {
                    self?.handlePrefsChange(newValue)
                }
            }
            .store(in: &cancellables)
    }

    private func handlePrefsChange(_ newValue: [BarMetric]) {
        if popover.isShown {
            pendingSnapshot = newValue
        } else {
            applySnapshot(newValue)
        }
    }

    private func applySnapshot(_ newValue: [BarMetric]) {
        snapshot.selected = newValue
        resizeButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let label = MenuBarLabel(stats: stats, snapshot: snapshot)
        let host = NSHostingView(rootView: label)
        host.translatesAutoresizingMaskIntoConstraints = false
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(host)
        let barHeight = NSStatusBar.system.thickness
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 6),
            host.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -6),
            host.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            host.heightAnchor.constraint(equalToConstant: barHeight)
        ])
        hostingView = host
        button.target = self
        button.action = #selector(togglePopover(_:))
        resizeButton()
    }

    private func resizeButton() {
        guard let host = hostingView else { return }
        host.layoutSubtreeIfNeeded()
        let fitting = host.intrinsicContentSize
        let width = max(fitting.width, host.fittingSize.width)
        statusItem.length = width + 12
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
        if let pending = self.pendingSnapshot {
            self.pendingSnapshot = nil
            self.applySnapshot(pending)
        }
    }
}

private final class PopoverDelegate: NSObject, NSPopoverDelegate {
    let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func popoverDidClose(_ notification: Notification) { onClose() }
}
