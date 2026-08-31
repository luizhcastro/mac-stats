import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController {
    private let popover: NSPopover
    private let stats: SystemStats
    private let prefs: DisplayPreferences
    private let snapshot: MenuBarSnapshot
    private let openWindow: () -> Void
    private var statusItems: [BarMetric: NSStatusItem] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private var pendingSnapshot: [BarMetric]?
    private var outsideClickMonitor: Any?
    private weak var anchorButton: NSStatusBarButton?

    init(stats: SystemStats, prefs: DisplayPreferences, openWindow: @escaping () -> Void) {
        self.stats = stats
        self.prefs = prefs
        self.snapshot = MenuBarSnapshot(selected: prefs.selected)
        self.openWindow = openWindow

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false

        buildAllStatusItems()
        applyVisibility()
        syncTemperatureAlwaysOn(prefs.selected)

        prefs.$selected
            .dropFirst()
            .sink { [weak self] newValue in
                DispatchQueue.main.async {
                    self?.handlePrefsChange(newValue)
                    self?.syncTemperatureAlwaysOn(newValue)
                }
            }
            .store(in: &cancellables)
    }

    private func syncTemperatureAlwaysOn(_ selected: [BarMetric]) {
        stats.setTemperatureAlwaysOn(selected.contains(.temperature))
    }

    private func buildAllStatusItems() {
        let order: [BarMetric] = [.appIcon, .network, .disk, .ram, .temperature, .cpu]
        for metric in order {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.autosaveName = "macstats.\(metric.rawValue)"
            guard let button = item.button else { continue }

            let label = SingleMetricLabel(stats: stats, metric: metric)
            let host = NSHostingView(rootView: label)
            host.translatesAutoresizingMaskIntoConstraints = false
            button.subviews.forEach { $0.removeFromSuperview() }
            button.addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 0),
                host.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 0),
                host.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                host.heightAnchor.constraint(equalToConstant: NSStatusBar.system.thickness)
            ])

            host.layoutSubtreeIfNeeded()
            let fitting = max(host.intrinsicContentSize.width, host.fittingSize.width)
            item.length = fitting

            button.target = self
            button.action = #selector(statusItemClicked(_:))

            statusItems[metric] = item
        }
    }

    private func applyVisibility() {
        let selected = Set(snapshot.selected)
        for (metric, item) in statusItems {
            item.isVisible = selected.contains(metric)
        }
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
        applyVisibility()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let metric = statusItems.first { $0.value.button === sender }?.key ?? .cpu
        guard popover.isShown else {
            openPopover(anchoredTo: sender, focus: metric)
            return
        }
        let reanchor = anchorButton !== sender
        if reanchor {
            stats.retainDetailSampling()
            stats.retainNetworkProcessSampling()
        }
        closePopover()
        guard reanchor else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.openPopover(anchoredTo: sender, focus: metric)
            self.stats.releaseDetailSampling()
            self.stats.releaseNetworkProcessSampling()
        }
    }

    private func openPopover(anchoredTo button: NSStatusBarButton, focus: BarMetric) {
        stats.retainDetailSampling()
        stats.retainNetworkProcessSampling()
        popover.delegate = popoverDelegate
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(stats: stats, prefs: prefs, focus: focus, openWindow: { [weak self] in
                self?.closePopover()
                self?.openWindow()
            })
        )
        anchorButton = button
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.becomeKey()
        installOutsideClickMonitor()
    }

    private func closePopover() {
        popover.performClose(nil)
        removeOutsideClickMonitor()
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    private lazy var popoverDelegate: PopoverDelegate = PopoverDelegate { [weak self] in
        guard let self else { return }
        self.removeOutsideClickMonitor()
        self.stats.releaseDetailSampling()
        self.stats.releaseNetworkProcessSampling()
        self.popover.contentViewController = nil
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
