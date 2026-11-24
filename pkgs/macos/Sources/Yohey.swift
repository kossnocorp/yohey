import AppKit
import CoreGraphics
import IOKit.ps
import IOKit.pwr_mgt
import SwiftUI

@main
struct Yohey: App {
    @StateObject private var monitor = Monitor()

    var body: some Scene {
        // Start the sampler when the scene is installed, before the first click.
        let monitor = self.monitor
        return MenuBarExtra("Yohey", systemImage: "bell.badge") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Yohey").font(.headline)
                Toggle("Sound reminders", isOn: $monitor.enabled)
                Toggle("Flash screen at reminders", isOn: $monitor.flashEnabled)
                HStack {
                    Picker("Reminder sound", selection: $monitor.soundName) {
                        ForEach(monitor.soundNames, id: \.self) { Text($0).tag($0) }
                    }
                    Button { monitor.chime() } label: { Image(systemName: "play.fill") }
                        .accessibilityLabel("Preview reminder sound")
                        .help("Play the selected sound")
                }
                volumeSlider("Start volume", $monitor.startVolume)
                volumeSlider("End volume", $monitor.endVolume)
                Picker("Start reminders", selection: $monitor.startSeconds) {
                    ForEach(Monitor.startOptions, id: \.self) { seconds in
                        Text(seconds < 60 ? "\(seconds) sec before lock" : "\(seconds / 60) min before lock")
                            .tag(seconds)
                    }
                }
                Stepper("Number of reminders: \(monitor.reminderCount)",
                        value: $monitor.reminderCount, in: 1...25)
                Picker("Reminder spacing", selection: $monitor.spacing) {
                    ForEach(ReminderSpacing.allCases, id: \.self) { Text($0.label).tag($0) }
                }.disabled(monitor.reminderCount == 1)
                HStack {
                    Toggle("Match system settings", isOn: $monitor.matchesSystem)
                        .toggleStyle(.checkbox)
                    Spacer()
                    Button { monitor.syncLimits() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(monitor.syncing)
                    .accessibilityLabel("Refresh from system settings")
                    .help("Copy display-off timers and the password delay from System Settings")
                }
                Group {
                    Stepper("On battery: \(duration(monitor.batteryMinutes))",
                            value: $monitor.batteryMinutes, in: 0...max(120, monitor.batteryMinutes))
                    Stepper("On power adapter: \(duration(monitor.adapterMinutes))",
                            value: $monitor.adapterMinutes, in: 0...max(120, monitor.adapterMinutes))
                    Picker("Require password", selection: $monitor.delay) {
                        ForEach(monitor.delayOptions, id: \.self) { Text($0.label).tag($0) }
                    }
                }
                .disabled(monitor.matchesSystem)
                .foregroundStyle(monitor.matchesSystem ? .secondary : .primary)
                if let error = monitor.syncError { Text(error).font(.caption) }
                Text("Power source: \(monitor.power.rawValue)").font(.caption)
                GroupBox("Estimated time remaining") {
                    Grid(alignment: .leading, verticalSpacing: 4) {
                        GridRow {
                            Text("Display off")
                            Text(monitor.displayClock)
                        }
                            .help("macOS exposes the display-off timer. Brightness may dim earlier.")
                        GridRow {
                            Text("Password lock")
                            Text(monitor.lockClock)
                        }
                    }.monospacedDigit().padding(3)
                    if let reason = monitor.displayHoldReason {
                        Text(reason).font(.caption)
                    }
                }
                Text(monitor.status).font(.caption).foregroundStyle(.secondary)
                Link("Open Lock Screen Settings…",
                     destination: URL(string: "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension")!)
                Divider()
                HStack {
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                }
            }.padding().frame(width: 290)
        }.menuBarExtraStyle(.window)
    }

    private func duration(_ minutes: Int) -> String { minutes == 0 ? "Never" : "\(minutes) min" }

    private func volumeSlider(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Slider(value: value, in: 0...1, step: 0.05) { Text(label) }
            Text(value.wrappedValue.formatted(.percent)).monospacedDigit()
        }
    }
}

private enum PowerSource: String {
    case adapter = "Power adapter", battery = "Battery", ups = "UPS", unknown = "Unavailable"

    static func current() -> Self {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue()
        else { return .unknown }
        switch type as String {
        case kIOPSACPowerValue: return .adapter
        case kIOPSBatteryPowerValue: return .battery
        case "UPS Power": return .ups
        default: return .unknown
        }
    }
}

@MainActor
private final class Monitor: NSObject, ObservableObject {
    let soundNames: [String]
    @Published var soundName: String {
        didSet {
            guard oldValue != soundName else { return }
            UserDefaults.standard.set(soundName, forKey: "soundName")
            chime()
        }
    }
    private var playingSound: NSSound?
    static let startOptions = [15, 30, 60, 120, 300, 600]
    @Published var startVolume: Double {
        didSet { UserDefaults.standard.set(startVolume, forKey: "startVolume") }
    }
    @Published var endVolume: Double {
        didSet { UserDefaults.standard.set(endVolume, forKey: "endVolume") }
    }
    @Published var startSeconds: Int {
        didSet { UserDefaults.standard.set(startSeconds, forKey: "startSeconds"); reset() }
    }
    @Published var reminderCount: Int {
        didSet { UserDefaults.standard.set(reminderCount, forKey: "reminderCount"); reset() }
    }
    @Published var spacing: ReminderSpacing {
        didSet { UserDefaults.standard.set(spacing.rawValue, forKey: "reminderSpacing"); reset() }
    }
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "enabled"); reset() }
    }
    @Published var flashEnabled: Bool {
        didSet { UserDefaults.standard.set(flashEnabled, forKey: "flashEnabled"); reset() }
    }
    @Published var batteryMinutes: Int {
        didSet { UserDefaults.standard.set(batteryMinutes, forKey: "batteryMinutes"); reset() }
    }
    @Published var adapterMinutes: Int {
        didSet { UserDefaults.standard.set(adapterMinutes, forKey: "adapterMinutes"); reset() }
    }
    @Published var delay: PasswordDelay {
        didSet { UserDefaults.standard.set(delay.stored, forKey: "passwordDelay"); reset() }
    }
    var delayOptions: [PasswordDelay] {
        var values = [0, 5, 60, 300, 900, 3600, 14400, 28800]
        if case .seconds(let n) = delay, !values.contains(n) { values.append(n) }
        return (delay == .unknown ? [.unknown] : []) + values.sorted().map(PasswordDelay.seconds) + [.off]
    }
    private var saverSeconds: Double?
    private var timeline = LockTimeline()
    private var displayHeldAwake = false
    private var nextOwnerCheck: TimeInterval = 0
    @Published private(set) var displayHoldReason: String?
    @Published private(set) var displayClock = "—"
    @Published private(set) var lockClock = "—"
    @Published private(set) var power = PowerSource.unknown
    @Published var matchesSystem: Bool {
        didSet {
            UserDefaults.standard.set(matchesSystem, forKey: "matchesSystem")
            configureSync()
        }
    }
    @Published private(set) var syncing = false
    @Published private(set) var syncError: String?
    private var syncTask: Task<Void, Never>?
    private var syncTimer: Timer?
    private var powerNotifications: CFRunLoopSource?
    @Published private(set) var status = "Monitoring idle time…"
    private var schedule = WarningSchedule()
    private var suspended = Set<String>()
    private var timer: Timer?

    override init() {
        let defaults = UserDefaults.standard
        let files = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? []
        let names = files.filter { $0.hasSuffix(".aiff") }.map { String($0.dropLast(5)) }.sorted()
        let defaultSound = "Sosumi"
        soundNames = names.isEmpty ? [defaultSound] : names
        let preferred = defaults.string(forKey: "soundName") ?? defaultSound
        soundName = soundNames.contains(preferred) ? preferred : (soundNames.contains(defaultSound) ? defaultSound : soundNames[0])
        let previous = defaults.object(forKey: "minutes") as? Int
        defaults.register(defaults: ["enabled": true, "matchesSystem": true, "batteryMinutes": previous ?? 2,
                                     "adapterMinutes": previous ?? 10, "volume": 1.0,
                                     "startSeconds": 60, "reminderCount": 3])
        let previousVolume = defaults.double(forKey: "volume")
        defaults.register(defaults: ["startVolume": previousVolume, "endVolume": previousVolume])
        startVolume = min(1, max(0, defaults.double(forKey: "startVolume")))
        endVolume = min(1, max(0, defaults.double(forKey: "endVolume")))
        let start = defaults.integer(forKey: "startSeconds")
        startSeconds = Self.startOptions.contains(start) ? start : 60
        reminderCount = min(25, max(1, defaults.integer(forKey: "reminderCount")))
        spacing = ReminderSpacing(rawValue: defaults.string(forKey: "reminderSpacing") ?? "") ?? .gentle
        enabled = defaults.bool(forKey: "enabled")
        flashEnabled = defaults.bool(forKey: "flashEnabled")
        matchesSystem = defaults.bool(forKey: "matchesSystem")
        delay = PasswordDelay(stored: defaults.object(forKey: "passwordDelay") as? Int)
        batteryMinutes = max(0, defaults.integer(forKey: "batteryMinutes"))
        adapterMinutes = max(0, defaults.integer(forKey: "adapterMinutes"))
        super.init()
        schedule = WarningSchedule(start: startSeconds, count: reminderCount, spacing: spacing)
        powerNotifications = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<Monitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in monitor.refreshPower() }
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let powerNotifications {
            CFRunLoopAddSource(CFRunLoopGetMain(), powerNotifications, .commonModes)
        }
        refreshPower()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(self, selector: #selector(stateChanged), name: name, object: nil)
        }
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked",
                     "com.apple.screensaver.didstart", "com.apple.screensaver.didstop"] {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(stateChanged),
                name: Notification.Name(name), object: nil)
        }
        let timer = Timer(timeInterval: 1, target: self, selector: #selector(sample),
                          userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        configureSync()
        sample()
    }

    private func configureSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        syncTask?.cancel()
        syncing = false
        syncError = nil
        guard matchesSystem else { return }
        syncLimits()
        let timer = Timer(timeInterval: 60, target: self, selector: #selector(syncLimits),
                          userInfo: nil, repeats: true)
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    @objc func syncLimits() {
        guard !syncing else { return }
        syncing = true
        syncTask = Task {
            let (limits, password, saver) = await Task.detached(priority: .utility) {
                // A missing preference isn't a deadline. An observed saver start
                // still anchors the grace period even without this estimate.
                let domain = "com.apple.screensaver" as CFString
                let timer = (CFPreferencesCopyValue("idleTime" as CFString, domain,
                    kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
                    ?? CFPreferencesCopyAppValue("idleTime" as CFString, domain)) as? NSNumber
                return (DisplayLimits.read(), PasswordDelay.read(), timer?.doubleValue)
            }.value
            guard !Task.isCancelled else { return }
            syncing = false
            if delay != password { delay = password }
            if saverSeconds != saver { saverSeconds = saver; reset() }
            guard let limits else {
                syncError = "Couldn’t read the system display-off timers."
                return
            }
            syncError = password == .unknown ? "Password delay unavailable. Turn off matching to set it manually." : nil
            if let value = limits.battery, batteryMinutes != value { batteryMinutes = value }
            if let value = limits.adapter, adapterMinutes != value { adapterMinutes = value }
        }
    }

    @objc private func stateChanged(_ note: Notification) {
        switch note.name {
        case NSWorkspace.screensDidSleepNotification:
            timeline.begin(.displayOff, now: ProcessInfo.processInfo.systemUptime)
        case NSWorkspace.screensDidWakeNotification: timeline.end(.displayOff)
        case Notification.Name("com.apple.screensaver.didstart"):
            timeline.begin(.screenSaver, now: ProcessInfo.processInfo.systemUptime)
        case Notification.Name("com.apple.screensaver.didstop"): timeline.end(.screenSaver)
        case NSWorkspace.willSleepNotification: suspended.insert("sleep")
        case NSWorkspace.didWakeNotification:
            timeline = LockTimeline()
            suspended.remove("sleep")
            refreshPower()
            if matchesSystem { syncLimits() }
        case NSWorkspace.sessionDidResignActiveNotification: suspended.insert("session")
        case NSWorkspace.sessionDidBecomeActiveNotification: suspended.remove("session")
        case Notification.Name("com.apple.screenIsLocked"): suspended.insert("lock")
        case Notification.Name("com.apple.screenIsUnlocked"):
            suspended.remove("lock")
            timeline = LockTimeline()
        default: return
        }
        reset()
    }

    private func refreshPower() {
        let current = PowerSource.current()
        guard current != power else { return }
        power = current
        if matchesSystem, syncTimer != nil { syncLimits() }
        reset()
    }

    private func reset() {
        schedule = WarningSchedule(start: startSeconds, count: reminderCount, spacing: spacing)
        sample()
    }
    func chime() { play(volume: endVolume) }

    private func play(volume: Double) {
        playingSound?.stop()
        guard volume > 0 else { return }
        let url = URL(fileURLWithPath: "/System/Library/Sounds")
            .appendingPathComponent(soundName).appendingPathExtension("aiff")
        playingSound = NSSound(contentsOf: url, byReference: true)
        playingSound?.volume = Float(volume)
        playingSound?.play()
    }

    @objc private func sample() {
        guard suspended.isEmpty else {
            displayHoldReason = nil
            displayClock = "—"
            lockClock = suspended.contains("lock") ? "Locked" : "—"
            status = "Reminders paused"
            return
        }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
            eventType: CGEventType(rawValue: UInt32.max)!)
        guard idle.isFinite, idle >= 0 else {
            displayClock = "—"; lockClock = "—"; status = "Idle time unavailable"; return
        }
        if let held = Self.readDisplayAssertion(), held != displayHeldAwake {
            displayHeldAwake = held
            nextOwnerCheck = 0
            // Start from current idle time; don't replay a boundary from before the change.
            schedule = WarningSchedule(start: startSeconds, count: reminderCount, spacing: spacing)
        }
        let display = power == .unknown || displayHeldAwake ? nil : Double(power == .adapter ? adapterMinutes : batteryMinutes) * 60
        let deadline = timeline.limit(now: ProcessInfo.processInfo.systemUptime, idle: idle,
                                      display: display, saver: saverSeconds, delay: delay)
        if timeline.displayIsOff { displayClock = "Off" }
        else if displayHeldAwake { displayClock = "Kept awake" }
        else { displayClock = display.map { $0 == 0 ? "Never" : clock($0 - idle) } ?? "Unknown" }
        if displayHeldAwake && !timeline.displayIsOff {
            let now = ProcessInfo.processInfo.systemUptime
            if displayHoldReason == nil || now >= nextOwnerCheck {
                let names = Self.displayAssertionOwners()
                displayHoldReason = "Kept awake by \(names.isEmpty ? "an app" : names.formatted(.list(type: .and)))."
                nextOwnerCheck = now + 5
            }
        } else if displayHoldReason != nil { displayHoldReason = nil }
        let pausedByApp = displayHeldAwake && deadline == nil && delay != .off && delay != .unknown
        lockClock = deadline.map { clock($0 - idle) } ?? (delay == .off ? "Never" : pausedByApp ? "Paused" : "—")
        guard enabled || flashEnabled else { status = "Reminders off"; return }
        guard let limit = deadline else {
            status = delay == .unknown ? "Waiting for password delay" :
                (delay == .off ? "No automatic password requirement" :
                    pausedByApp ? "Reminders resume automatically." :
                    "Waiting for display off or screen saver")
            return
        }
        if let volume = schedule.chimeVolume(idle: idle, limit: limit, from: startVolume, to: endVolume) {
            if enabled { play(volume: volume) }
            if flashEnabled && !timeline.displayIsOff { flashScreens() }
        }
        if let boundary = schedule.nextBoundary(idle: idle, limit: limit) {
            // Wake for fractional boundaries without polling rapidly all day.
            let remaining = boundary - idle
            if remaining < 1 { timer?.fireDate = Date(timeIntervalSinceNow: max(0.02, remaining)) }
            status = "Next reminder in \(Int(ceil(boundary - idle)))s if idle"
        } else { status = "Waiting for activity" }
    }

    private func flashScreens() {
        for screen in NSScreen.screens {
            let overlay = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                   backing: .buffered, defer: false)
            overlay.isReleasedWhenClosed = false
            overlay.isOpaque = false
            overlay.backgroundColor = .white
            overlay.alphaValue = 0.18
            overlay.hasShadow = false
            overlay.ignoresMouseEvents = true
            overlay.level = .screenSaver
            overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            overlay.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                overlay.animator().alphaValue = 0
            } completionHandler: {
                overlay.close()
            }
        }
    }

    private static func readDisplayAssertion() -> Bool? {
        var snapshot: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&snapshot) == kIOReturnSuccess,
              let assertions = snapshot?.takeRetainedValue() as NSDictionary?,
              let level = assertions[kIOPMAssertPreventUserIdleDisplaySleep] as? NSNumber
        else { return nil }
        return level.boolValue
    }

    private static func displayAssertionOwners() -> [String] {
        var snapshot: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&snapshot) == kIOReturnSuccess,
              let processes = snapshot?.takeRetainedValue() as? [NSNumber: [NSDictionary]]
        else { return [] }
        var names = Set<String>()
        for (pid, assertions) in processes where assertions.contains(where: {
            ($0[kIOPMAssertionTypeKey] as? String) == kIOPMAssertPreventUserIdleDisplaySleep &&
            ($0[kIOPMAssertionLevelKey] as? NSNumber)?.boolValue == true
        }) {
            if let name = NSRunningApplication(processIdentifier: pid.int32Value)?.localizedName {
                names.insert(name)
            } else {
                var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
                if proc_name(pid.int32Value, &buffer, UInt32(buffer.count)) > 0 {
                    names.insert(String(cString: buffer))
                }
            }
        }
        return names.sorted()
    }

    private func clock(_ seconds: Double) -> String {
        let n = Int(ceil(max(0, seconds)))
        return String(format: "%d:%02d", n / 60, n % 60)
    }
}
