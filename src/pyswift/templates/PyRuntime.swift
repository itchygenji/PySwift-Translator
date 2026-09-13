import Foundation

public indirect enum PyValue: Codable, CustomStringConvertible, Equatable {
    case none
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case list([PyValue])
    case dict([String: PyValue])

    private enum CodingKeys: String, CodingKey { case type, value }
    private enum Kind: String, Codable { case none, bool, int, double, string, list, dict }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .none: self = .none
        case .bool: self = .bool(try c.decode(Bool.self, forKey: .value))
        case .int: self = .int(try c.decode(Int64.self, forKey: .value))
        case .double: self = .double(try c.decode(Double.self, forKey: .value))
        case .string: self = .string(try c.decode(String.self, forKey: .value))
        case .list: self = .list(try c.decode([PyValue].self, forKey: .value))
        case .dict: self = .dict(try c.decode([String: PyValue].self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try c.encode(Kind.none, forKey: .type)
        case .bool(let v): try c.encode(Kind.bool, forKey: .type); try c.encode(v, forKey: .value)
        case .int(let v): try c.encode(Kind.int, forKey: .type); try c.encode(v, forKey: .value)
        case .double(let v): try c.encode(Kind.double, forKey: .type); try c.encode(v, forKey: .value)
        case .string(let v): try c.encode(Kind.string, forKey: .type); try c.encode(v, forKey: .value)
        case .list(let v): try c.encode(Kind.list, forKey: .type); try c.encode(v, forKey: .value)
        case .dict(let v): try c.encode(Kind.dict, forKey: .type); try c.encode(v, forKey: .value)
        }
    }

    public var description: String {
        switch self {
        case .none: return "None"
        case .bool(let v): return v ? "True" : "False"
        case .int(let v): return String(v)
        case .double(let v):
            if v.isFinite && v.rounded() == v { return String(format: "%.1f", v) }
            return String(v)
        case .string(let v): return v
        case .list(let v): return "[" + v.map { $0.repr }.joined(separator: ", ") + "]"
        case .dict(let v):
            let body = v.keys.sorted().map { "\(PyValue.string($0).repr): \(v[$0]!.repr)" }.joined(separator: ", ")
            return "{" + body + "}"
        }
    }

    public var repr: String {
        switch self {
        case .string(let s): return "\"" + s.replacingOccurrences(of: "\"", with: "\\\"") + "\""
        default: return description
        }
    }

    public var truthy: Bool {
        switch self {
        case .none: return false
        case .bool(let v): return v
        case .int(let v): return v != 0
        case .double(let v): return v != 0
        case .string(let v): return !v.isEmpty
        case .list(let v): return !v.isEmpty
        case .dict(let v): return !v.isEmpty
        }
    }

    public var intValue: Int64 {
        switch self {
        case .int(let v): return v
        case .double(let v): return Int64(v)
        case .bool(let v): return v ? 1 : 0
        case .string(let v): return Int64(v) ?? 0
        default: return 0
        }
    }

    public var doubleValue: Double {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        case .bool(let v): return v ? 1 : 0
        case .string(let v): return Double(v) ?? 0
        default: return 0
        }
    }

    public var stringValue: String {
        if case .string(let v) = self { return v }
        return description
    }

    public subscript(_ key: PyValue) -> PyValue {
        get {
            switch (self, key) {
            case (.list(let values), .int(let i)):
                let idx = pyNormalizeIndex(Int(i), count: values.count)
                return (0..<values.count).contains(idx) ? values[idx] : .none
            case (.string(let value), .int(let i)):
                let chars = Array(value)
                let idx = pyNormalizeIndex(Int(i), count: chars.count)
                return (0..<chars.count).contains(idx) ? .string(String(chars[idx])) : .none
            case (.dict(let values), _): return values[key.stringValue] ?? .none
            default: return .none
            }
        }
        set {
            switch (self, key) {
            case (.list(var values), .int(let i)):
                let idx = pyNormalizeIndex(Int(i), count: values.count)
                if (0..<values.count).contains(idx) { values[idx] = newValue; self = .list(values) }
            case (.dict(var values), _): values[key.stringValue] = newValue; self = .dict(values)
            default: break
            }
        }
    }

    public mutating func pyAppend(_ value: PyValue) {
        if case .list(var values) = self { values.append(value); self = .list(values) }
    }

    public mutating func pyExtend(_ value: PyValue) {
        if case .list(var values) = self { values.append(contentsOf: pyIterable(value)); self = .list(values) }
    }

    public mutating func pyInsert(_ index: PyValue, _ value: PyValue) {
        if case .list(var values) = self {
            let i = max(0, min(Int(index.intValue), values.count))
            values.insert(value, at: i); self = .list(values)
        }
    }

    @discardableResult public mutating func pyPop(_ index: PyValue = .int(-1)) -> PyValue {
        if case .list(var values) = self, !values.isEmpty {
            let i = pyNormalizeIndex(Int(index.intValue), count: values.count)
            if (0..<values.count).contains(i) { let result = values.remove(at: i); self = .list(values); return result }
        }
        return .none
    }

    public func pyUpper() -> PyValue { .string(stringValue.uppercased()) }
    public func pyLower() -> PyValue { .string(stringValue.lowercased()) }
    public func pyStrip() -> PyValue { .string(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) }
    public func pyReplace(_ old: PyValue, _ new: PyValue) -> PyValue { .string(stringValue.replacingOccurrences(of: old.stringValue, with: new.stringValue)) }
    public func pyStartswith(_ prefix: PyValue) -> PyValue { .bool(stringValue.hasPrefix(prefix.stringValue)) }
    public func pyEndswith(_ suffix: PyValue) -> PyValue { .bool(stringValue.hasSuffix(suffix.stringValue)) }
    public func pySplit(_ separator: PyValue = .none) -> PyValue {
        if case .none = separator { return .list(stringValue.split(whereSeparator: { $0.isWhitespace }).map { .string(String($0)) }) }
        return .list(stringValue.components(separatedBy: separator.stringValue).map { .string($0) })
    }
    public func pyFind(_ needle: PyValue) -> PyValue {
        guard let r = stringValue.range(of: needle.stringValue) else { return .int(-1) }
        return .int(Int64(stringValue.distance(from: stringValue.startIndex, to: r.lowerBound)))
    }
    public mutating func pyRemove(_ value: PyValue) {
        if case .list(var values) = self, let i = values.firstIndex(of: value) { values.remove(at: i); self = .list(values) }
    }
    public mutating func pyReverse() { if case .list(let values) = self { self = .list(Array(values.reversed())) } }
    public mutating func pySort() { if case .list(let values) = self { self = .list(values.sorted { $0.description < $1.description }) } }
    public func pyKeys() -> PyValue { if case .dict(let d) = self { return .list(d.keys.sorted().map { .string($0) }) }; return .list([]) }
    public func pyValues() -> PyValue { if case .dict(let d) = self { return .list(d.keys.sorted().compactMap { d[$0] }) }; return .list([]) }
    public func pyItems() -> PyValue { if case .dict(let d) = self { return .list(d.keys.sorted().map { .list([.string($0), d[$0]!]) }) }; return .list([]) }
    public func pyGet(_ key: PyValue, _ defaultValue: PyValue = .none) -> PyValue { if case .dict(let d) = self { return d[key.stringValue] ?? defaultValue }; return defaultValue }
}

private func pyNormalizeIndex(_ index: Int, count: Int) -> Int { index < 0 ? count + index : index }

public func + (lhs: PyValue, rhs: PyValue) -> PyValue {
    switch (lhs, rhs) {
    case (.string(let a), _): return .string(a + rhs.stringValue)
    case (_, .string(let b)): return .string(lhs.stringValue + b)
    case (.list(let a), .list(let b)): return .list(a + b)
    case (.int(let a), .int(let b)): return .int(a + b)
    default: return .double(lhs.doubleValue + rhs.doubleValue)
    }
}
public func - (lhs: PyValue, rhs: PyValue) -> PyValue { if case (.int(let a), .int(let b)) = (lhs, rhs) { return .int(a-b) }; return .double(lhs.doubleValue-rhs.doubleValue) }
public func * (lhs: PyValue, rhs: PyValue) -> PyValue {
    if case (.int(let a), .int(let b)) = (lhs, rhs) { return .int(a*b) }
    if case (.string(let s), .int(let n)) = (lhs, rhs) { return .string(String(repeating: s, count: max(0, Int(n)))) }
    if case (.int(let n), .string(let s)) = (lhs, rhs) { return .string(String(repeating: s, count: max(0, Int(n)))) }
    return .double(lhs.doubleValue*rhs.doubleValue)
}
public func / (lhs: PyValue, rhs: PyValue) -> PyValue { .double(lhs.doubleValue/rhs.doubleValue) }
public func % (lhs: PyValue, rhs: PyValue) -> PyValue { .int(lhs.intValue % rhs.intValue) }
public prefix func - (value: PyValue) -> PyValue { if case .int(let v) = value { return .int(-v) }; return .double(-value.doubleValue) }

public func pyPow(_ a: PyValue, _ b: PyValue) -> PyValue { .double(pow(a.doubleValue, b.doubleValue)) }
public func pyFloorDiv(_ a: PyValue, _ b: PyValue) -> PyValue { .int(Int64(floor(a.doubleValue / b.doubleValue))) }
public func pyEq(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a == b) }
public func pyNe(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a != b) }
public func pyLt(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a.doubleValue < b.doubleValue) }
public func pyLe(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a.doubleValue <= b.doubleValue) }
public func pyGt(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a.doubleValue > b.doubleValue) }
public func pyGe(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a.doubleValue >= b.doubleValue) }
public func pyContains(_ container: PyValue, _ item: PyValue) -> PyValue {
    switch container {
    case .list(let v): return .bool(v.contains(item))
    case .string(let s): return .bool(s.contains(item.stringValue))
    case .dict(let d): return .bool(d[item.stringValue] != nil)
    default: return .bool(false)
    }
}
public func pyNot(_ value: PyValue) -> PyValue { .bool(!value.truthy) }
public func pyBitAnd(_ a: PyValue, _ b: PyValue) -> PyValue { .int(a.intValue & b.intValue) }
public func pyBitOr(_ a: PyValue, _ b: PyValue) -> PyValue { .int(a.intValue | b.intValue) }
public func pyBitXor(_ a: PyValue, _ b: PyValue) -> PyValue { .int(a.intValue ^ b.intValue) }
public func pyLShift(_ a: PyValue, _ b: PyValue) -> PyValue { .int(a.intValue << b.intValue) }
public func pyRShift(_ a: PyValue, _ b: PyValue) -> PyValue { .int(a.intValue >> b.intValue) }
public func pyInvert(_ value: PyValue) -> PyValue { .int(~value.intValue) }
public func pyAnd(_ lhs: PyValue, _ rhs: () -> PyValue) -> PyValue { lhs.truthy ? rhs() : lhs }
public func pyOr(_ lhs: PyValue, _ rhs: () -> PyValue) -> PyValue { lhs.truthy ? lhs : rhs() }

public func pyPrint(_ values: [PyValue], sep: String = " ", end: String = "\n") {
    let text = values.map { $0.description }.joined(separator: sep) + end
    FileHandle.standardOutput.write(text.data(using: .utf8)!)
}
public func pyLen(_ value: PyValue) -> PyValue {
    switch value { case .string(let v): return .int(Int64(v.count)); case .list(let v): return .int(Int64(v.count)); case .dict(let v): return .int(Int64(v.count)); default: return .int(0) }
}
public func pyInt(_ value: PyValue) -> PyValue { .int(value.intValue) }
public func pyFloat(_ value: PyValue) -> PyValue { .double(value.doubleValue) }
public func pyStr(_ value: PyValue) -> PyValue { .string(value.description) }
public func pyBool(_ value: PyValue) -> PyValue { .bool(value.truthy) }
public func pyAbs(_ value: PyValue) -> PyValue { if case .int(let v) = value { return .int(Swift.abs(v)) }; return .double(Swift.abs(value.doubleValue)) }
public func pySum(_ value: PyValue) -> PyValue { pyIterable(value).reduce(.int(0), +) }
public func pyMin(_ value: PyValue) -> PyValue { pyIterable(value).min { $0.doubleValue < $1.doubleValue } ?? .none }
public func pyMax(_ value: PyValue) -> PyValue { pyIterable(value).max { $0.doubleValue < $1.doubleValue } ?? .none }
public func pyRound(_ value: PyValue, digits: PyValue = .int(0)) -> PyValue { let p = pow(10.0, Double(digits.intValue)); return .double((value.doubleValue*p).rounded()/p) }
public func pyAny(_ value: PyValue) -> PyValue { .bool(pyIterable(value).contains { $0.truthy }) }
public func pyAll(_ value: PyValue) -> PyValue { .bool(pyIterable(value).allSatisfy { $0.truthy }) }
public func pySorted(_ value: PyValue, reverse: PyValue = .bool(false)) -> PyValue { let values = pyIterable(value).sorted { $0.description < $1.description }; return .list(reverse.truthy ? Array(values.reversed()) : values) }
public func pyReversed(_ value: PyValue) -> PyValue { .list(Array(pyIterable(value).reversed())) }

public func pyInput(_ prompt: PyValue = .string("")) -> PyValue { if !prompt.stringValue.isEmpty { pyPrint([prompt], end: "") }; return .string(readLine() ?? "") }

public func pyRange(_ start: PyValue, _ stop: PyValue? = nil, _ step: PyValue = .int(1)) -> PyValue {
    let a: Int64; let b: Int64
    if let stop = stop { a = start.intValue; b = stop.intValue } else { a = 0; b = start.intValue }
    let s = step.intValue
    if s == 0 { return .list([]) }
    var out: [PyValue] = []; var i = a
    if s > 0 { while i < b { out.append(.int(i)); i += s } }
    else { while i > b { out.append(.int(i)); i += s } }
    return .list(out)
}
public func pyIterable(_ value: PyValue) -> [PyValue] {
    switch value {
    case .list(let v): return v
    case .string(let s): return s.map { .string(String($0)) }
    case .dict(let d): return d.keys.sorted().map { .string($0) }
    default: return []
    }
}
public func pyEnumerate(_ value: PyValue, start: PyValue = .int(0)) -> PyValue { .list(pyIterable(value).enumerated().map { .list([.int(Int64($0.offset)+start.intValue), $0.element]) }) }
public func pyZip(_ values: [PyValue]) -> PyValue {
    let arrays = values.map(pyIterable); let n = arrays.map(\.count).min() ?? 0
    return .list((0..<n).map { i in .list(arrays.map { $0[i] }) })
}

public func pySlice(_ value: PyValue, _ start: PyValue = .none, _ stop: PyValue = .none, _ step: PyValue = .none) -> PyValue {
    let items = pyIterable(value); let count = items.count
    let s = start == .none ? 0 : pyNormalizeIndex(Int(start.intValue), count: count)
    let e = stop == .none ? count : pyNormalizeIndex(Int(stop.intValue), count: count)
    let st = step == .none ? 1 : Int(step.intValue)
    if st == 0 { return .list([]) }
    var result: [PyValue] = []; var i = s
    if st > 0 { while i < min(e, count) && i >= 0 { result.append(items[i]); i += st } }
    else { var j = min(i, count-1); while j > e && j >= 0 && j < count { result.append(items[j]); j += st } }
    if case .string = value { return .string(result.map(\.stringValue).joined()) }
    return .list(result)
}

public func pyMathSqrt(_ x: PyValue) -> PyValue { .double(sqrt(x.doubleValue)) }
public func pyMathSin(_ x: PyValue) -> PyValue { .double(sin(x.doubleValue)) }
public func pyMathCos(_ x: PyValue) -> PyValue { .double(cos(x.doubleValue)) }
public func pyMathTan(_ x: PyValue) -> PyValue { .double(tan(x.doubleValue)) }
public func pyMathFloor(_ x: PyValue) -> PyValue { .int(Int64(floor(x.doubleValue))) }
public func pyMathCeil(_ x: PyValue) -> PyValue { .int(Int64(ceil(x.doubleValue))) }
public let pyMathPi = PyValue.double(Double.pi)

public func pySleep(_ seconds: PyValue) { Thread.sleep(forTimeInterval: seconds.doubleValue) }
public func pyRandom() -> PyValue { .double(Double.random(in: 0..<1)) }
public func pyRandint(_ a: PyValue, _ b: PyValue) -> PyValue { .int(Int64.random(in: a.intValue...b.intValue)) }

public let pySysArgv = PyValue.list(CommandLine.arguments.map { .string($0) })
public func pyGetenv(_ key: PyValue, _ defaultValue: PyValue = .none) -> PyValue { ProcessInfo.processInfo.environment[key.stringValue].map(PyValue.string) ?? defaultValue }
public func pyGetcwd() -> PyValue { .string(FileManager.default.currentDirectoryPath) }
public func pyExists(_ path: PyValue) -> PyValue { .bool(FileManager.default.fileExists(atPath: path.stringValue)) }
public func pyMkdir(_ path: PyValue) -> PyValue { try? FileManager.default.createDirectory(atPath: path.stringValue, withIntermediateDirectories: true); return .none }
public func pyPathJoin(_ values: [PyValue]) -> PyValue { .string(values.map(\.stringValue).reduce("") { $0.isEmpty ? $1 : URL(fileURLWithPath: $0).appendingPathComponent($1).path }) }

public func pyJSONDumps(_ value: PyValue) -> PyValue {
    guard let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) else { return .string("null") }
    return .string(text)
}
public func pyJSONLoads(_ value: PyValue) -> PyValue { guard let data = value.stringValue.data(using: .utf8), let decoded = try? JSONDecoder().decode(PyValue.self, from: data) else { return .none }; return decoded }

public final class PyFile {
    private let path: String
    private let mode: String
    private var handle: FileHandle?

    public init(_ path: PyValue, mode: PyValue = .string("r")) {
        self.path = path.stringValue; self.mode = mode.stringValue
        if self.mode.contains("w") { _ = FileManager.default.createFile(atPath: self.path, contents: Data()) }
        if self.mode.contains("a") && !FileManager.default.fileExists(atPath: self.path) { _ = FileManager.default.createFile(atPath: self.path, contents: Data()) }
        handle = self.mode.contains("r") ? FileHandle(forReadingAtPath: self.path) : FileHandle(forWritingAtPath: self.path)
        if self.mode.contains("a") { _ = try? handle?.seekToEnd() }
    }
    public func read() -> PyValue { guard let h = handle else { return .string("") }; try? h.seek(toOffset: 0); let d = (try? h.readToEnd()) ?? Data(); return .string(String(data: d, encoding: .utf8) ?? "") }
    public func readline() -> PyValue { let all = read().stringValue; return .string(all.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? "") }
    @discardableResult public func write(_ value: PyValue) -> PyValue { guard let d = value.stringValue.data(using: .utf8) else { return .int(0) }; try? handle?.write(contentsOf: d); return .int(Int64(d.count)) }
    public func close() { try? handle?.close() }
    deinit { close() }
}

private let pyWorkerFlag = "--pyswift-worker"
private let pyResultPrefix = "__PYSWIFT_RESULT__"

public func pyDecodeWorkerArgs(_ encoded: String) -> [PyValue] {
    guard let data = Data(base64Encoded: encoded), let values = try? JSONDecoder().decode([PyValue].self, from: data) else { return [] }
    return values
}
public func pyEmitWorkerResult(_ value: PyValue) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    Swift.print(pyResultPrefix + data.base64EncodedString())
}

public final class PyProcess {
    private let target: String
    private let args: [PyValue]
    private var process: Process?
    private var pipe: Pipe?
    public private(set) var result: PyValue = .none

    public init(target: String, args: [PyValue] = []) { self.target = target; self.args = args }
    public func start() {
        guard let data = try? JSONEncoder().encode(args) else { return }
        let p = Process(); let out = Pipe(); pipe = out
        p.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        p.arguments = [pyWorkerFlag, target, data.base64EncodedString()]
        p.standardOutput = out; p.standardError = FileHandle.standardError
        do { try p.run(); process = p } catch { fputs("PyProcess launch failed: \(error)\n", stderr) }
    }
    @discardableResult public func join() -> PyValue {
        process?.waitUntilExit()
        guard let pipe = pipe else { return result }
        let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        guard let text = String(data: data, encoding: .utf8) else { return result }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(line)
            if s.hasPrefix(pyResultPrefix), let data = Data(base64Encoded: String(s.dropFirst(pyResultPrefix.count))), let v = try? JSONDecoder().decode(PyValue.self, from: data) { result = v }
            else if !s.isEmpty { Swift.print(s) }
        }
        return result
    }
}

public final class PyPool {
    private let size: Int
    public init(processes: PyValue = .none) { self.size = max(1, processes == .none ? ProcessInfo.processInfo.activeProcessorCount : Int(processes.intValue)) }
    public func map(target: String, items: PyValue) -> PyValue {
        let values = pyIterable(items); var results = Array(repeating: PyValue.none, count: values.count)
        var index = 0
        while index < values.count {
            let end = min(values.count, index + size)
            let processes = (index..<end).map { PyProcess(target: target, args: [values[$0]]) }
            processes.forEach { $0.start() }
            for (offset, p) in processes.enumerated() { results[index + offset] = p.join() }
            index = end
        }
        return .list(results)
    }
    public func close() {}
    public func join() {}
}
