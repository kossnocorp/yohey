struct LockTimeline {
    enum Trigger: Hashable { case displayOff, screenSaver }
    private var triggers: Set<Trigger> = []
    private var started: Double?

    var displayIsOff: Bool { triggers.contains(.displayOff) }

    mutating func begin(_ trigger: Trigger, now: Double) {
        triggers.insert(trigger)
        if started == nil { started = now }
    }

    mutating func end(_ trigger: Trigger) {
        triggers.remove(trigger)
        if triggers.isEmpty { started = nil }
    }

    /// `limit` is expressed in seconds from the last input, like WarningSchedule.
    mutating func limit(now: Double, idle: Double, display: Double?, saver: Double?,
                        delay: PasswordDelay) -> Double? {
        // Input after an observed transition ends that idle cycle, even if
        // the corresponding wake/stop notification hasn't arrived yet.
        if let started, now - idle > started + 0.1 { self = Self() }
        guard case .seconds(let grace) = delay else { return nil }
        if let started { return idle + Double(grace) - (now - started) }
        return [display, saver].compactMap { $0 }.filter { $0 > 0 }.min().map { $0 + Double(grace) }
    }
}
