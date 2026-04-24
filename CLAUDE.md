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

`run.sh` wraps the SPM binary into a proper `.app` with `Info.plist` (sets `LSUIElement=true` so the app has no Dock icon).

When iterating, kill before rebuild (`pkill -x MacStats`). If a change looks like it didn't apply, run `swift package clean` — SPM has occasionally served stale binaries in this repo.

## Architecture

```
Sources/MacStats/
├── MacStatsApp.swift          # @main, AppDelegate creates StatusBarController
├── StatusBarController.swift  # NSStatusItem + NSHostingView + NSPopover
├── SystemStats.swift          # @MainActor ObservableObject, 1s timer aggregates all monitors
├── DisplayPreferences.swift   # which metrics show in menu bar (UserDefaults-backed)
├── Formatters.swift           # byte/rate/percent formatting
├── Monitors/                  # stateless-ish samplers, one per hardware domain
│   ├── CPUMonitor.swift       # host_statistics HOST_CPU_LOAD_INFO
│   ├── MemoryMonitor.swift    # host_statistics64 HOST_VM_INFO64
│   ├── NetworkMonitor.swift   # getifaddrs + if_data
│   ├── DiskMonitor.swift      # IOKit IOBlockStorageDriver + volume resource values
│   ├── BatteryMonitor.swift   # IOPowerSources
│   └── ProcessMonitor.swift   # libproc: proc_listpids + proc_pidinfo + proc_pid_rusage
└── Views/
    ├── MenuBarLabel.swift         # what shows in the menu bar itself
    ├── MenuBarContentView.swift   # dropdown / popover content
    ├── MenuBarPrefsView.swift     # checkboxes for which metrics show in bar
    └── TopProcessesView.swift     # tabbed top processes (CPU/RAM/Disk)
```

### Data flow

1. `SystemStats` owns a `Timer` firing every 1s on the main thread.
2. Each tick calls `sample()` on every monitor and publishes results via `@Published`.
3. `ProcessMonitor` samples every 2 ticks (every 2s) to cut overhead — iterating all PIDs on every tick was expensive.
4. Monitors that need deltas (CPU, network, disk, processes) store a `prior` sample and compute rates.

### Menu bar rendering

- `NSStatusItem` (not SwiftUI `MenuBarExtra`). `MenuBarExtra` collapses complex label layouts — multi-metric HStacks did not render correctly.
- Menu bar label is a `NSHostingView<MenuBarLabel>` pinned inside the status item button.
- Popover (`NSPopover`, behavior `.transient`) hosts the SwiftUI content.

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

### Menu bar jitter / popover drift

Two earlier UX bugs and their fixes:

- **Icon width jitter** (e.g. `1%` → `100%` changing width, hiding neighbor status items): every metric slot has a **fixed-width `Text` frame** in `MenuBarLabel.swift`. Values are padded / capped (`99%` max) so widths are stable within a slot.
- **Popover drift when toggling metrics**: changing which metrics are shown resizes the status item. If the popover is open, `NSPopover` tracks its anchor view and the popover slides around, losing focus. Fix in `StatusBarController.swift`: status-item resize is **deferred** while the popover is shown; pending resize flushes on `popoverDidClose`. The in-session popover stays locked in place.

### Fonts

Use `.font(.system(size: N))` with `.monospacedDigit()` — not `.system(design: .monospaced)`. Full monospaced design looks wrong in the menu bar; digit-only monospacing keeps SF for labels and fixes value-width jitter.

## Adding a new monitor

1. New file in `Monitors/` exposing `struct Sample` + `func sample() -> Sample`.
2. Add `@Published` field + instance + tick call in `SystemStats`.
3. Add a section in `MenuBarContentView` if it needs dropdown UI.
4. If it should be toggleable in the menu bar: add a case to `BarMetric` (`DisplayPreferences.swift`), extend `MenuBarLabel`, and extend `MenuBarPrefsView`.

## Working on this codebase

- Test changes by running the app; there are no unit tests. SwiftUI Previews would require Xcode project (currently SPM-only).
- User runs macOS 26 / Apple Silicon. APIs verified there.
- Crash reports land in `~/Library/Logs/DiagnosticReports/Retired/MacStats-*.ips`. Parse with `python3 -c 'import json; ...'` and inspect triggered thread frames for source lines.
- Commits must not include `Co-Authored-By` (per global user rules).
