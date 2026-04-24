# MacStats — Agent Guide

Native macOS menu bar system monitor. Inspired by iStat Menus. Personal use, not App Store.

## Product context

- Replace macOS Activity Monitor for quick glances at CPU/RAM/Disk/Network/Battery.
- Menu bar first: compact metrics always visible; dropdown for detail.
- Per-process tops (CPU/RAM/Disk) so the user can spot hogs without opening Activity Monitor.
- Target audience: the repo owner. No localization, no onboarding, no telemetry.

### Non-goals

- App Store distribution (no sandboxing, no notarization pipeline).
- Cross-platform. macOS 13+ only (uses modern SwiftUI APIs + IOKit).
- Network-per-process. Requires root/NEPacketTunnelProvider entitlement — deferred.
- GPU/thermal deep metrics. SMC keys are private API — deferred until needed.

## Stack

- Swift 6.3 + SwiftUI + AppKit (`NSStatusItem` for menu bar, SwiftUI for content).
- Swift Package Manager (no Xcode project). `Package.swift` is the source of truth.
- macOS 13+ deployment target.
- No external dependencies.

## Build / run

```bash
./Scripts/run.sh           # debug bundle + launch
./Scripts/bundle.sh release  # release .app
swift build -c debug       # compile only
pkill -x MacStats          # kill running instance
```

`run.sh` wraps the SPM binary into a proper `.app` with `Info.plist` (sets `LSUIElement=true` so the app has no Dock icon). `bundle.sh` also copies `Resources/AppIcon.icns` into the bundle and wires `CFBundleIconFile = AppIcon` so Finder / About show the MacStats icon.

When iterating, kill before rebuild (`pkill -x MacStats`). If a change looks like it didn't apply, run `swift package clean` — SPM has occasionally served stale binaries in this repo.

## Architecture

```
Sources/MacStats/
├── MacStatsApp.swift          # @main, AppDelegate creates StatusBarController
├── StatusBarController.swift  # owns N NSStatusItems (one per metric) + shared NSPopover
├── SystemStats.swift          # @MainActor ObservableObject, 1s timer aggregates all monitors
├── DisplayPreferences.swift   # which metrics show in menu bar (UserDefaults-backed)
├── MenuBarSnapshot.swift      # frozen copy of selected metrics for the status bar
├── Formatters.swift           # byte/rate/percent formatting
├── Monitors/                  # stateless-ish samplers, one per hardware domain
│   ├── CPUMonitor.swift       # host_statistics HOST_CPU_LOAD_INFO
│   ├── MemoryMonitor.swift    # host_statistics64 HOST_VM_INFO64
│   ├── NetworkMonitor.swift   # getifaddrs + if_data
│   ├── DiskMonitor.swift      # IOKit IOBlockStorageDriver + volume resource values
│   ├── BatteryMonitor.swift   # IOPowerSources
│   └── ProcessMonitor.swift   # libproc: proc_listpids + proc_pidinfo + proc_pid_rusage
└── Views/
    ├── SingleMetricLabel.swift   # one metric in the menu bar (icon above compact value)
    ├── MenuBarContentView.swift  # dropdown / popover content (header + sections + prefs + quit)
    ├── MenuBarPrefsView.swift    # checkboxes for which metrics show in bar
    └── TopProcessesView.swift    # tabbed top processes (CPU/RAM/Disk)

Resources/
└── AppIcon.icns               # built via iconutil from design_handoff_macstats_logo/

design_handoff_macstats_logo/  # canonical icon source (SVG + sized PNGs + README)
```

### Data flow

1. `SystemStats` owns a `Timer` firing every 1s on the main thread.
2. Each tick calls `sample()` on every monitor and publishes results via `@Published`.
3. `ProcessMonitor` samples every 2 ticks (every 2s) to cut overhead — iterating all PIDs on every tick was expensive.
4. Monitors that need deltas (CPU, network, disk, processes) store a `prior` sample and compute rates.

### Menu bar rendering

- **One `NSStatusItem` per metric** (CPU, RAM, Disk). Not a single item with a multi-slot label. This lets macOS hide items individually under width pressure instead of collapsing the whole group at once. Each item owns an `NSHostingView<SingleMetricLabel>`.
- All three items are **created once at launch** and toggled via `item.isVisible` when the user checks/unchecks a metric. Recreating items on every toggle turned out to be flaky (items occasionally failed to reappear).
- Items share **one `NSPopover`** (`behavior = .transient`, no animation). Clicking any item's button opens the popover anchored to that button.
- Popover closes on outside click via a **global `NSEvent.addGlobalMonitorForEvents`** monitor for `leftMouseDown`/`rightMouseDown`. `.transient` alone is unreliable, especially when items get hidden.
- Menu bar label uses `Font.system(size: 9, weight: .bold).monospacedDigit()` with compact suffixes (`99%`, `9.9G`, `1.2M`) and fixed-width frames per metric.

### Freezing the menu bar while the popover is open

Toggling `DisplayPreferences` while the popover is visible is buffered via `MenuBarSnapshot`:

1. `StatusBarController` subscribes to `prefs.$selected`.
2. While the popover is shown, changes go into `pendingSnapshot` instead of updating `snapshot.selected` / `item.isVisible`.
3. On `popoverDidClose`, the pending snapshot is flushed and visibility is applied.

Without this, the status item layout would shift during a popover session, causing focus loss and popover drift.

## Non-obvious technical decisions

### `proc_pid_rusage` pointer shape

Darwin headers declare `typedef void *rusage_info_t;` and `int proc_pid_rusage(int, int, rusage_info_t *)`. The `rusage_info_t *` is misleading — the kernel writes struct data **directly** to the passed pointer, not through double indirection. The struct is `rusage_info_v2`.

In Swift this imports as `UnsafeMutablePointer<rusage_info_t?>`. Passing `&someStruct` naively causes the kernel to overrun the stack (`__stack_chk_fail` / SIGABRT) because the kernel writes ~144 bytes starting at the "pointer variable" rather than at the struct.

Correct shape in `ProcessMonitor.swift`:

```swift
let bufSize = max(MemoryLayout<rusage_info_v2>.size, 4096)
let raw = UnsafeMutableRawPointer.allocate(byteCount: bufSize, alignment: 16)
defer { raw.deallocate() }
raw.initializeMemory(as: UInt8.self, repeating: 0, count: bufSize)
let casted = UnsafeMutablePointer<rusage_info_t?>(OpaquePointer(raw))
let ret = proc_pid_rusage(pid, RUSAGE_INFO_V2, casted)
```

If you ever refactor process sampling, preserve this shape. The heap buffer + `OpaquePointer` cast is load-bearing.

### `proc_listpids` slack

The two-call pattern (probe size, then fetch) races against process creation. A PID spawning between the calls can cause a buffer overflow. Always allocate extra slack bytes (see `listPids()` — uses `probe + 1024 * sizeof(pid)` slack) and clamp the result to the buffer capacity.

### Fonts

Use `.font(.system(size: N))` with `.monospacedDigit()` — not `.system(design: .monospaced)`. Full monospaced design looks wrong in the menu bar; digit-only monospacing keeps SF for labels and fixes value-width jitter.

### Recreating vs hiding status items

Calling `NSStatusBar.system.removeStatusItem(...)` and then creating a new `NSStatusItem` to re-add it worked in isolation but was unreliable in practice — newly re-added items occasionally failed to appear. Keep all items alive for the app's lifetime and toggle `isVisible` instead.

### MenuBarExtra vs NSStatusItem

SwiftUI `MenuBarExtra` was tried first. It collapses complex label layouts: only one child of a multi-view `HStack` typically survives into the menu bar. `NSStatusItem` with an embedded `NSHostingView` is the reliable path.

## App icon

- Canonical source: `design_handoff_macstats_logo/assets/macstats-icon.svg` (hand-authored, see the folder's README for design tokens / geometry).
- Sized PNGs are in `design_handoff_macstats_logo/assets/png/`.
- Compiled `.icns` at `Resources/AppIcon.icns`. Rebuild it from the PNGs via `iconutil -c icns MacStats.iconset` (see the handoff README for the exact `.iconset` layout).
- `bundle.sh` copies the `.icns` into `Contents/Resources/AppIcon.icns` and sets `CFBundleIconFile = AppIcon`.
- The dropdown header in `MenuBarContentView` loads the same icon via `NSImage(named: "AppIcon")`.
- No mono/template variant for the menu bar; the colored bar glyphs come from SF Symbols in `SingleMetricLabel`.

## Adding a new monitor

1. New file in `Monitors/` exposing `struct Sample` + `func sample() -> Sample`.
2. Add `@Published` field + instance + tick call in `SystemStats`.
3. Add a section in `MenuBarContentView` if it needs dropdown UI.
4. If it should be toggleable in the menu bar:
   - Add a case to `BarMetric` in `DisplayPreferences.swift` (the `MenuBarPrefsView` checkbox list updates automatically).
   - Extend `SingleMetricLabel` with the new `case` (icon, text, slot width).
   - Extend `StatusBarController.buildAllStatusItems` so the new metric gets its own `NSStatusItem`.

## Working on this codebase

- Test changes by running the app; there are no unit tests. SwiftUI Previews would require Xcode project (currently SPM-only).
- User runs macOS 26 / Apple Silicon. APIs verified there.
- Crash reports land in `~/Library/Logs/DiagnosticReports/Retired/MacStats-*.ips`. Parse with `python3 -c 'import json; ...'` and inspect triggered thread frames for source lines.
- Commits must not include `Co-Authored-By` (per global user rules). Keep commits granular and in English.
