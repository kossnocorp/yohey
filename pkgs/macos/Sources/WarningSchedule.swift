enum ReminderSpacing: String, CaseIterable {
    // Keep the original stored values so existing choices survive the rename.
    case steady = "Evenly spaced"
    case gentle = "Closer near lock"
    case urgent = "Urgent build-up"

    var label: String {
        switch self {
        case .steady: return "Steady"
        case .gentle: return "Gentle build-up"
        case .urgent: return "Urgent build-up"
        }
    }
}

struct WarningSchedule {
    private var previous: Double?
    private let leads: [Double]

    init(start: Int = 60, count: Int = 3, spacing: ReminderSpacing = .gentle) {
        let total = Double(start), n = Double(count)
        let average = total / n
        // The gaps sum to the window, including the last gap before lock.
        // Accelerating uses an arithmetic progression (3:2:1 by default).
        // Keep even its shortest gap audible in a dense schedule.
        let floor = min(average, 0.35)
        let shortest = max(floor, 2 * average / (n + 1))
        let step = count == 1 ? 0 : 2 * (average - shortest) / (n - 1)
        leads = (1...count).reversed().map { index in
            let k = Double(index)
            if index == count { return total }
            switch spacing {
            case .steady: return k * average
            case .gentle: return k * shortest + k * (k - 1) * step / 2
            case .urgent:
                // Reserve an audible minimum gap, then shape the rest with cubic ease-out.
                let u = k / n
                return k * floor + (total - n * floor) * u * u * u
            }
        }
    }

    func nextBoundary(idle: Double, limit: Double) -> Double? {
        leads.lazy.map { limit - $0 }.first { $0 > idle }
    }

    /// Wake once just before a distant boundary to establish the baseline used by
    /// chimeVolume. Input may restart an idle cycle while we're asleep, so never
    /// sleep past the first reachable reminder of a fresh cycle.
    func nextCheck(idle: Double, limit: Double) -> Double? {
        guard let first = nextBoundary(idle: 0, limit: limit) else { return nil }
        let wait = min(first, nextBoundary(idle: idle, limit: limit).map { $0 - idle } ?? first)
        return max(0.02, wait > 2 ? wait - 1 : wait)
    }

    /// Sample once per second. A gap, an input reset, or a new schedule
    /// establishes a baseline rather than replaying a missed warning.
    mutating func chimeVolume(idle: Double, limit: Double, from start: Double, to end: Double) -> Double? {
        defer { previous = idle }
        guard let previous, idle >= previous, idle - previous <= 3,
              idle < limit else { return nil }
        guard let lead = leads.last(where: { lead in
            let boundary = limit - lead
            return previous < boundary && boundary <= idle
        }), let first = leads.first, let last = leads.last else { return nil }
        // Use the spacing curve's timestamps, normalized between the first and
        // last chimes (rather than the lock itself), for the volume envelope.
        if lead == last { return end } // a single reminder uses end volume
        let progress = (first - lead) / (first - last)
        return start + (end - start) * progress
    }
}
