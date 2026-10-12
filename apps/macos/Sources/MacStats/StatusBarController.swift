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
    private var labelModels: [BarMetric: MetricLabelModel] = [:]
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
        // Native popover animation: grows out of the menu bar arrow.
        popover.animates = true

        buildAllStatusItems()
        applyVisibility()
        syncTemperatureAlwaysOn(prefs.selected)

        stats.$snapshot
            .sink { [weak self] snap in self?.updateLabels(snap) }
            .store(in: &cancellables)

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

            let model = MetricLabelModel()
            model.text = SingleMetricLabel.text(for: metric, in: stats.snapshot)
            labelModels[metric] = model
            let label = SingleMetricLabel(model: model, metric: metric)
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
        updateLabels(stats.snapshot)
    }

    /// Formats only the visible metrics and publishes a label only when its
    /// string changed.
    private func updateLabels(_ snap: SystemSnapshot) {
        for metric in snapshot.selected where metric != .appIcon {
            guard let model = labelModels[metric] else { continue }
            let text = SingleMetricLabel.text(for: metric, in: snap)
            if model.text != text { model.text = text }
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
        // Re-anchoring reopens on the next runloop hop, which needs the close
        // to finish now: skip the close animation, keep the open one.
        if reanchor { popover.animates = false }
        closePopover()
        popover.animates = true
        guard reanchor else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.openPopover(anchoredTo: sender, focus: metric)
            self.stats.releaseDetailSampling()
            self.stats.releaseNetworkProcessSampling()
        }
    }

    private func openPopover(anchoredTo button: NSStatusBarButton, focus: BarMetric) {
        Analytics.track("popover_open")
        stats.retainDetailSampling()
        stats.retainNetworkProcessSampling()
        popover.delegate = popoverDelegate
        let host = NSHostingController(
            rootView: MenuBarContentView(stats: stats, prefs: prefs, focus: focus, openWindow: { [weak self] in
                self?.closePopover()
                self?.openWindow()
            })
        )
        // Collapsing / expanding sections resizes the popover.
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
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
