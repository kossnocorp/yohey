import Foundation

struct DisplayLimits: Equatable {
    var battery: Int?
    var adapter: Int?

    init(_ output: String) {
        var profile = ""
        for line in output.split(whereSeparator: \.isNewline) {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasSuffix(":") { profile = text; continue }
            let fields = text.split(whereSeparator: \.isWhitespace)
            guard fields.count == 2, fields[0] == "displaysleep",
                  let minutes = Int(fields[1]), minutes >= 0 else { continue }
            switch profile {
            case "Battery Power:": battery = minutes
            case "AC Power:": adapter = minutes
            default: break
            }
        }
    }

    static func read() -> Self? {
        guard let text = commandOutput("/usr/bin/pmset", ["-g", "custom"]) else { return nil }
        let limits = Self(text)
        return limits.battery != nil || limits.adapter != nil ? limits : nil
    }
}

private func commandOutput(_ path: String, _ arguments: [String]) -> String? {
    let task = Process(), pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = arguments
    task.standardOutput = pipe
    task.standardError = pipe // sysadminctl writes its status to stderr
    do { try task.run() } catch { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    return task.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
}

enum PasswordDelay: Hashable {
    case unknown, off, seconds(Int)

    init(stored: Int?) {
        switch stored {
        case -1: self = .off
        case let value? where value >= 0: self = .seconds(value)
        default: self = .unknown
        }
    }

    var stored: Int? {
        switch self {
        case .off: return -1
        case .unknown: return nil
        case .seconds(let n): return n
        }
    }

    init(status: String) {
        let words = status.split(whereSeparator: \.isWhitespace)
        if words.suffix(3) == ["screenLock", "is", "off"] { self = .off }
        else if words.suffix(4) == ["screenLock", "delay", "is", "immediate"] { self = .seconds(0) }
        else if words.dropLast(2).suffix(3) == ["screenLock", "delay", "is"],
                words.last == "seconds", let n = words.dropLast().last.flatMap({ Int($0) }), n >= 0 {
            self = n == Int(Int32.max) ? .off : .seconds(n)
        } else { self = .unknown }
    }

    static func read() -> Self {
        Self(status: commandOutput("/usr/sbin/sysadminctl", ["-screenLock", "status"]) ?? "")
    }

    var label: String {
        switch self {
        case .unknown: return "Unknown"
        case .off: return "Never"
        case .seconds(0): return "Immediately"
        case .seconds(let n): return n % 60 == 0 ? "\(n / 60) min" : "\(n) sec"
        }
    }
}
