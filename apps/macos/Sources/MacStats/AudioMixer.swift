import AppKit
import Accelerate
import CoreAudio

/// One app in the mixer: every CoreAudio process object it owns (main
/// process + helpers that play on its behalf, e.g. a browser's audio service).
struct MixerApp: Identifiable, Equatable {
    let id: String            // bundle id, or "proc:<executable>" for non-bundled processes
    let name: String
    let iconPath: String?     // bundle whose icon represents the row
    var objects: [AudioObjectID]
    var isPlaying: Bool
    var volume: Float
    var muted: Bool
}

/// Per-app volume via CoreAudio process taps (macOS 14.4+).
///
/// An app at 100% and unmuted is left alone. Anything else gets a
/// `TapEngine`: a private tap that mutes the app's own output plus a private
/// aggregate device whose IOProc copies the tapped audio to the default
/// output, scaled by the gain. Engines only run while the app is producing
/// output, so an idle app with a saved volume costs nothing.
///
/// No polling: the HAL notifies on process list, per-process running-output
/// and default-output changes.
@available(macOS 14.4, *)
@MainActor
final class AudioMixer: ObservableObject {
    static let shared = AudioMixer()

    /// Apps currently producing output, plus any with a non-default setting.
    @Published private(set) var apps: [MixerApp] = []
    /// Set when tap creation fails, usually because the user denied the
    /// System Audio Recording permission.
    @Published private(set) var tapFailed = false

    private var settings: [String: Setting]
    private var engines: [String: TapEngine] = [:]
    private var processListeners: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
    private var started = false
    private var viewers = 0
    private var pollTimer: Timer?
    private let ownPid = getpid()

    private struct Setting: Codable {
        var volume: Float = 1
        var muted = false
        var isDefault: Bool { volume >= 0.999 && !muted }
    }

    private static let defaultsKey = "mixer.settings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([String: Setting].self, from: data) {
            settings = saved
        } else {
            settings = [:]
        }
    }

    func start() {
        guard !started else { return }
        started = true
        let system = AudioObjectID(kAudioObjectSystemObject)
        for selector in [kAudioHardwarePropertyProcessObjectList, kAudioHardwarePropertyDefaultOutputDevice] {
            var address = Self.address(selector)
            AudioObjectAddPropertyListenerBlock(system, &address, .main) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    if selector == kAudioHardwarePropertyDefaultOutputDevice {
                        // Engines are bound to the old device's UID.
                        self?.engines.removeAll()
                    }
                    self?.reconcile()
                }
            }
        }
        reconcile()
    }

    /// HAL notifications miss some transitions (Chromium's audio service),
    /// so poll once a second while a mixer view is on screen.
    func retainView() {
        viewers += 1
        reconcile()
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        }
    }

    func releaseView() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func setVolume(_ volume: Float, for id: String) {
        update(id) { $0.volume = min(max(volume, 0), 1) }
    }

    func setMuted(_ muted: Bool, for id: String) {
        update(id) { $0.muted = muted }
    }

    private func update(_ id: String, _ change: (inout Setting) -> Void) {
        var setting = settings[id] ?? Setting()
        change(&setting)
        settings[id] = setting.isDefault ? nil : setting
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
        if let engine = engines[id] {
            engine.gain = setting.muted ? 0 : setting.volume
        }
        reconcile()
    }

    /// Rebuilds the app list from the HAL and brings engines in line with it.
    private func reconcile() {
        let objects = Self.objectList(AudioObjectID(kAudioObjectSystemObject),
                                      kAudioHardwarePropertyProcessObjectList)
        syncProcessListeners(objects)

        var byOwner: [String: MixerApp] = [:]
        var order: [String] = []
        for object in objects {
            var pid: pid_t = 0
            guard Self.read(object, kAudioProcessPropertyPID, &pid), pid > 0, pid != ownPid,
                  let owner = Self.owner(of: pid) else { continue }
            var running: UInt32 = 0
            _ = Self.read(object, kAudioProcessPropertyIsRunningOutput, &running)
            let id = owner.id
            if byOwner[id] == nil {
                let setting = settings[id] ?? Setting()
                byOwner[id] = MixerApp(id: id, name: owner.name,
                                       iconPath: owner.iconPath, objects: [],
                                       isPlaying: false, volume: setting.volume, muted: setting.muted)
                order.append(id)
            }
            byOwner[id]!.objects.append(object)
            byOwner[id]!.isPlaying = byOwner[id]!.isPlaying || running != 0
        }

        let defaultUID = Self.defaultOutputUID()
        for (id, app) in byOwner {
            let setting = settings[id] ?? Setting()
            // Play back on the device the app itself chose (Discord on a
            // headset, a game on a USB DAC), not blindly the system default.
            guard !setting.isDefault, app.isPlaying,
                  let outputUID = Self.outputUID(of: app.objects) ?? defaultUID else {
                engines[id] = nil
                continue
            }
            let gain = setting.muted ? 0 : setting.volume
            if let engine = engines[id], engine.objects == app.objects, engine.outputUID == outputUID {
                engine.gain = gain
                continue
            }
            engines[id] = nil  // stop the stale one before tapping the same processes again
            if let engine = TapEngine(objects: app.objects, outputUID: outputUID, gain: gain) {
                engines[id] = engine
                tapFailed = false
            } else {
                tapFailed = true
            }
        }
        for id in engines.keys where byOwner[id] == nil {
            engines[id] = nil
        }

        // Like the Windows mixer: a Dock app gets a row once it has opened an
        // audio session (it's in the HAL process list), even while silent, so
        // its volume can be set ahead of time. Apps that never touched audio
        // (Finder, terminals) stay out; daemons and CLI tools only show while
        // playing or when they carry a saved setting.
        let openApps = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier))

        let next = order.compactMap { byOwner[$0] }
            .filter { $0.isPlaying || openApps.contains($0.id) || !(settings[$0.id] ?? Setting()).isDefault }
            .sorted {
                if $0.isPlaying != $1.isPlaying { return $0.isPlaying }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        if next != apps { apps = next }
    }

    /// Per-process listeners so the list follows apps starting / stopping
    /// playback. `IsRunningOutput` alone misses Chromium's audio service
    /// (Dia/Chrome helper never notified), so also watch `IsRunning` and the
    /// process's output devices.
    private static let processSelectors = [kAudioProcessPropertyIsRunningOutput,
                                           kAudioProcessPropertyIsRunning,
                                           kAudioProcessPropertyDevices]

    private func syncProcessListeners(_ objects: [AudioObjectID]) {
        let current = Set(objects)
        for (object, block) in processListeners where !current.contains(object) {
            for selector in Self.processSelectors {
                var address = Self.processAddress(selector)
                AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
            }
            processListeners[object] = nil
        }
        for object in objects where processListeners[object] == nil {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.reconcile() }
            }
            for selector in Self.processSelectors {
                var address = Self.processAddress(selector)
                AudioObjectAddPropertyListenerBlock(object, &address, .main, block)
            }
            processListeners[object] = block
        }
    }

    private static func processAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector,
                                   mScope: selector == kAudioProcessPropertyDevices
                                       ? kAudioObjectPropertyScopeOutput : kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    // MARK: - Process ownership

    @_silgen_name("responsibility_get_pid_responsible_for_pid")
    private static func responsiblePid(_ pid: pid_t) -> pid_t

    typealias Owner = (id: String, name: String, iconPath: String?)

    /// Apple daemons that play audio on an app's behalf, keyed by executable
    /// name. The HAL only sees the daemon, so map it back to the app the user
    /// knows. `systemsoundserverd` mixes every app's alert sounds and doesn't
    /// say who asked, so it gets one "System Sounds" row.
    private static let daemonOwners: [String: Owner] = [
        "systemsoundserverd": ("system.sounds", "System Sounds", "/System/Applications/System Settings.app"),
        "avconferenced": ("com.apple.FaceTime", "FaceTime", "/System/Applications/FaceTime.app"),
        "callservicesd": ("com.apple.FaceTime", "FaceTime", "/System/Applications/FaceTime.app"),
        "assistantd": ("com.apple.Siri", "Siri", "/System/Library/CoreServices/Siri.app"),
        "corespeechd": ("com.apple.Siri", "Siri", "/System/Library/CoreServices/Siri.app"),
        "usernoted": ("com.apple.notificationcenterui", "Notifications",
                      "/System/Library/CoreServices/NotificationCenter.app"),
    ]

    /// Which app a process plays on behalf of, in order:
    /// 1. the process itself if it's a regular app (a game spawned by Steam or
    ///    Terminal must not be filed under its launcher);
    /// 2. the responsibility chain, then the parent chain, up to a regular app
    ///    (`Google Chrome Helper` → Chrome);
    /// 3. a known Apple daemon → its app;
    /// 4. any helper living inside an `.app` bundle → the outermost bundle;
    /// 5. the bare executable (`afplay`, `say`), so every process making
    ///    sound shows up.
    private static func owner(of pid: pid_t) -> Owner? {
        var current = pid
        if NSRunningApplication(processIdentifier: pid)?.activationPolicy != .regular {
            current = responsiblePid(pid)
            if current <= 0 { current = pid }
        }
        for _ in 0..<8 {
            if let app = NSRunningApplication(processIdentifier: current),
               app.activationPolicy == .regular {
                let path = app.bundleURL?.path
                let name = app.localizedName ?? path.map(bundleName) ?? "pid \(current)"
                return (app.bundleIdentifier ?? "proc:\(name)", name, path)
            }
            var info = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.size)
            guard proc_pidinfo(current, PROC_PIDTBSDINFO, 0, &info, size) == size,
                  info.pbi_ppid > 1 else { break }
            current = pid_t(info.pbi_ppid)
        }

        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let path = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        let executable = URL(fileURLWithPath: path).lastPathComponent
        if let known = daemonOwners[executable] { return known }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        if let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            let bundlePath = components[...appIndex].joined(separator: "/")
            let name = bundleName(bundlePath)
            return (Bundle(path: bundlePath)?.bundleIdentifier ?? "proc:\(name)", name, bundlePath)
        }
        return ("proc:\(executable)", executable, nil)
    }

    private static func bundleName(_ bundlePath: String) -> String {
        let info = Bundle(path: bundlePath)?.infoDictionary
        return info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? URL(fileURLWithPath: bundlePath).deletingPathExtension().lastPathComponent
    }

    // MARK: - HAL helpers

    fileprivate static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    fileprivate static func read<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                    _ value: inout T) -> Bool {
        var address = address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        return withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0) == noErr
        }
    }

    private static func objectList(_ object: AudioObjectID,
                                   _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var address = address(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    private static func defaultOutputUID() -> String? {
        var device = AudioObjectID(0)
        guard read(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, &device),
              device != 0 else { return nil }
        return deviceUID(device)
    }

    /// The output device a running process of the app is playing to.
    private static func outputUID(of objects: [AudioObjectID]) -> String? {
        for object in objects {
            var running: UInt32 = 0
            guard read(object, kAudioProcessPropertyIsRunningOutput, &running), running != 0 else { continue }
            var address = processAddress(kAudioProcessPropertyDevices)
            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { continue }
            var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
            guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &devices) == noErr,
                  let device = devices.first, let uid = deviceUID(device) else { continue }
            return uid
        }
        return nil
    }

    private static func deviceUID(_ device: AudioObjectID) -> String? {
        var uid: Unmanaged<CFString>?
        guard read(device, kAudioDevicePropertyDeviceUID, &uid), let uid else { return nil }
        return uid.takeRetainedValue() as String
    }
}

/// Tap + private aggregate + IOProc for one app. Created and dropped on the
/// main actor; only `gain` is touched from the audio thread.
@available(macOS 14.4, *)
private final class TapEngine: @unchecked Sendable {
    let objects: [AudioObjectID]
    let outputUID: String
    private let gainBox: GainBox
    private var tapID = AudioObjectID(0)
    private var aggregateID = AudioObjectID(0)
    private var ioProc: AudioDeviceIOProcID?

    /// ponytail: plain Float shared with the IO thread. Aligned 32-bit stores
    /// don't tear on arm64/x86_64; swap for `Synchronization.Atomic` once the
    /// deployment target reaches macOS 15.
    private final class GainBox: @unchecked Sendable {
        var value: Float
        init(_ value: Float) { self.value = value }
    }

    var gain: Float {
        get { gainBox.value }
        set { gainBox.value = newValue }
    }

    private static let teardownQueue = DispatchQueue(label: "dev.luizcastro.macstats.mixer.teardown",
                                                     qos: .utility)

    init?(objects: [AudioObjectID], outputUID: String, gain: Float) {
        self.objects = objects
        self.outputUID = outputUID
        gainBox = GainBox(gain)

        let tap = CATapDescription(stereoMixdownOfProcesses: objects)
        tap.muteBehavior = .mutedWhenTapped
        tap.isPrivate = true
        guard AudioHardwareCreateProcessTap(tap, &tapID) == noErr, tapID != 0 else { return nil }

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MacStats Mixer",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tap.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
            kAudioAggregateDeviceTapAutoStartKey: true,
        ]
        guard AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID) == noErr,
              aggregateID != 0 else {
            stop()
            return nil
        }

        let box = gainBox
        let status = AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregateID, nil) { _, input, _, output, _ in
            let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            let outputs = UnsafeMutableAudioBufferListPointer(output)
            // The aggregate lists the output device's own input streams (if
            // any) before the tap, so the tap is the last input buffer.
            guard let source = inputs.last(where: { $0.mData != nil && $0.mNumberChannels > 0 }) else {
                TapEngine.silence(outputs)
                return
            }
            TapEngine.render(source, into: outputs, gain: box.value)
        }
        guard status == noErr, AudioDeviceStart(aggregateID, ioProc) == noErr else {
            stop()
            return nil
        }
    }

    deinit { stop() }

    private func stop() {
        let (tapID, aggregateID, ioProc) = (self.tapID, self.aggregateID, self.ioProc)
        (self.tapID, self.aggregateID, self.ioProc) = (0, 0, nil)
        // Stop synchronously: `mutedWhenTapped` keeps the app silent until the
        // tap read stops, so this hands the audio back right away. The destroy
        // calls can block on a wedged HAL, so they go off the main thread.
        if let ioProc, aggregateID != 0 { AudioDeviceStop(aggregateID, ioProc) }
        Self.teardownQueue.async {
            if let ioProc, aggregateID != 0 { AudioDeviceDestroyIOProcID(aggregateID, ioProc) }
            if aggregateID != 0 { AudioHardwareDestroyAggregateDevice(aggregateID) }
            if tapID != 0 { AudioHardwareDestroyProcessTap(tapID) }
        }
    }

    // MARK: - Render (audio thread: no allocation, no locks)

    private static func frames(_ buffer: AudioBuffer) -> Int {
        buffer.mNumberChannels == 0 ? 0
            : Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * Int(buffer.mNumberChannels))
    }

    private static func silence(_ outputs: UnsafeMutableAudioBufferListPointer) {
        for buffer in outputs {
            if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
        }
    }

    /// Copies interleaved Float32 tap audio into the output buffers, scaled.
    /// Output channel N takes tap channel N (mono taps feed both front
    /// channels); anything without a source is silenced.
    private static func render(_ source: AudioBuffer, into outputs: UnsafeMutableAudioBufferListPointer,
                               gain: Float) {
        guard let samples = source.mData?.assumingMemoryBound(to: Float.self) else {
            silence(outputs)
            return
        }
        let sourceChannels = Int(source.mNumberChannels)
        let sourceFrames = frames(source)
        var gain = gain
        var firstChannel = 0
        for buffer in outputs {
            let channels = Int(buffer.mNumberChannels)
            defer { firstChannel += channels }
            guard let data = buffer.mData else { continue }
            memset(data, 0, Int(buffer.mDataByteSize))
            let destination = data.assumingMemoryBound(to: Float.self)
            let count = vDSP_Length(min(sourceFrames, frames(buffer)))
            for channel in 0..<channels {
                let outChannel = firstChannel + channel
                let sourceChannel = outChannel < sourceChannels ? outChannel
                    : (sourceChannels == 1 && outChannel == 1 ? 0 : -1)
                guard sourceChannel >= 0 else { continue }
                vDSP_vsmul(samples + sourceChannel, vDSP_Stride(sourceChannels), &gain,
                           destination + channel, vDSP_Stride(channels), count)
            }
        }
    }
}
