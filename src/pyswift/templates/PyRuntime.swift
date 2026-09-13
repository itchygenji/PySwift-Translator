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

    public static func == (lhs: PyValue, rhs: PyValue) -> Bool {
        if lhs.isNumber && rhs.isNumber {
            return lhs.doubleValue == rhs.doubleValue
        }
        switch (lhs, rhs) {
        case (.none, .none): return true
        case (.string(let a), .string(let b)): return a == b
        case (.list(let a), .list(let b)): return a == b
        case (.dict(let a), .dict(let b)): return a == b
        default: return false
        }
    }

    public var isNumber: Bool {
        switch self {
        case .bool, .int, .double: return true
        default: return false
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
        case .string(let s):
            let escaped = s
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            return "'" + escaped + "'"
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
            let raw = Int(index.intValue)
            let i = raw < 0 ? max(0, values.count + raw) : min(raw, values.count)
            values.insert(value, at: i)
            self = .list(values)
        }
    }

    @discardableResult public mutating func pyPop(_ index: PyValue = .int(-1)) -> PyValue {
        if case .list(var values) = self, !values.isEmpty {
            let i = pyNormalizeIndex(Int(index.intValue), count: values.count)
            if (0..<values.count).contains(i) {
                let result = values.remove(at: i)
                self = .list(values)
                return result
            }
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
        if case .none = separator {
            return .list(stringValue.split(whereSeparator: { $0.isWhitespace }).map { .string(String($0)) })
        }
        return .list(stringValue.components(separatedBy: separator.stringValue).map { .string($0) })
    }
    public func pyFind(_ needle: PyValue) -> PyValue {
        guard let r = stringValue.range(of: needle.stringValue) else { return .int(-1) }
        return .int(Int64(stringValue.distance(from: stringValue.startIndex, to: r.lowerBound)))
    }
    public mutating func pyRemove(_ value: PyValue) {
        if case .list(var values) = self, let i = values.firstIndex(of: value) {
            values.remove(at: i)
            self = .list(values)
        }
    }
    public mutating func pyReverse() {
        if case .list(let values) = self { self = .list(Array(values.reversed())) }
    }
    public mutating func pySort(reverse: PyValue = .bool(false)) {
        if case .list(let values) = self {
            let sorted = values.sorted { pyLessThan($0, $1) }
            self = .list(reverse.truthy ? Array(sorted.reversed()) : sorted)
        }
    }
    public func pyKeys() -> PyValue {
        if case .dict(let d) = self { return .list(d.keys.sorted().map { .string($0) }) }
        return .list([])
    }
    public func pyValues() -> PyValue {
        if case .dict(let d) = self { return .list(d.keys.sorted().compactMap { d[$0] }) }
        return .list([])
    }
    public func pyItems() -> PyValue {
        if case .dict(let d) = self { return .list(d.keys.sorted().map { .list([.string($0), d[$0]!]) }) }
        return .list([])
    }
    public func pyGet(_ key: PyValue, _ defaultValue: PyValue = .none) -> PyValue {
        if case .dict(let d) = self { return d[key.stringValue] ?? defaultValue }
        return defaultValue
    }
}

private func pyNormalizeIndex(_ index: Int, count: Int) -> Int { index < 0 ? count + index : index }

private func pyLessThan(_ lhs: PyValue, _ rhs: PyValue) -> Bool {
    if lhs.isNumber && rhs.isNumber { return lhs.doubleValue < rhs.doubleValue }
    switch (lhs, rhs) {
    case (.string(let a), .string(let b)): return a < b
    case (.list(let a), .list(let b)):
        for (x, y) in zip(a, b) {
            if x == y { continue }
            return pyLessThan(x, y)
        }
        return a.count < b.count
    default:
        // Mixed incomparable Python 3 types would raise TypeError. The translator
        // documents that runtime exception fidelity is still incomplete; this
        // deterministic fallback keeps generated Swift buildable.
        return lhs.description < rhs.description
    }
}

public func + (lhs: PyValue, rhs: PyValue) -> PyValue {
    switch (lhs, rhs) {
    case (.string(let a), .string(let b)): return .string(a + b)
    case (.list(let a), .list(let b)): return .list(a + b)
    case (.int(let a), .int(let b)): return .int(a + b)
    default: return .double(lhs.doubleValue + rhs.doubleValue)
    }
}
public func - (lhs: PyValue, rhs: PyValue) -> PyValue {
    if case (.int(let a), .int(let b)) = (lhs, rhs) { return .int(a - b) }
    return .double(lhs.doubleValue - rhs.doubleValue)
}
public func * (lhs: PyValue, rhs: PyValue) -> PyValue {
    if case (.int(let a), .int(let b)) = (lhs, rhs) { return .int(a * b) }
    if case (.string(let s), .int(let n)) = (lhs, rhs) { return .string(String(repeating: s, count: max(0, Int(n)))) }
    if case (.int(let n), .string(let s)) = (lhs, rhs) { return .string(String(repeating: s, count: max(0, Int(n)))) }
    return .double(lhs.doubleValue * rhs.doubleValue)
}
public func / (lhs: PyValue, rhs: PyValue) -> PyValue { .double(lhs.doubleValue / rhs.doubleValue) }
public func % (lhs: PyValue, rhs: PyValue) -> PyValue { pyModulo(lhs, rhs) }
public prefix func - (value: PyValue) -> PyValue {
    if case .int(let v) = value { return .int(-v) }
    return .double(-value.doubleValue)
}

public func pyModulo(_ a: PyValue, _ b: PyValue) -> PyValue {
    if case (.int(let x), .int(let y)) = (a, b) {
        if y == 0 { return .none }
        var r = x % y
        if r != 0 && ((r < 0) != (y < 0)) { r += y }
        return .int(r)
    }
    let divisor = b.doubleValue
    if divisor == 0 { return .none }
    let dividend = a.doubleValue
    return .double(dividend - floor(dividend / divisor) * divisor)
}
public func pyPow(_ a: PyValue, _ b: PyValue) -> PyValue { .double(pow(a.doubleValue, b.doubleValue)) }
public func pyFloorDiv(_ a: PyValue, _ b: PyValue) -> PyValue {
    if case (.int(let x), .int(let y)) = (a, b), y != 0 {
        return .int(Int64(floor(Double(x) / Double(y))))
    }
    return .double(floor(a.doubleValue / b.doubleValue))
}
public func pyEq(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a == b) }
public func pyNe(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a != b) }
public func pyLt(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(pyLessThan(a, b)) }
public func pyLe(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a == b || pyLessThan(a, b)) }
public func pyGt(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(pyLessThan(b, a)) }
public func pyGe(_ a: PyValue, _ b: PyValue) -> PyValue { .bool(a == b || pyLessThan(b, a)) }
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
    switch value {
    case .string(let v): return .int(Int64(v.count))
    case .list(let v): return .int(Int64(v.count))
    case .dict(let v): return .int(Int64(v.count))
    default: return .int(0)
    }
}
public func pyInt(_ value: PyValue) -> PyValue { .int(value.intValue) }
public func pyFloat(_ value: PyValue) -> PyValue { .double(value.doubleValue) }
public func pyStr(_ value: PyValue) -> PyValue { .string(value.description) }
public func pyBool(_ value: PyValue) -> PyValue { .bool(value.truthy) }
public func pyAbs(_ value: PyValue) -> PyValue {
    if case .int(let v) = value { return .int(Swift.abs(v)) }
    return .double(Swift.abs(value.doubleValue))
}
public func pySum(_ value: PyValue) -> PyValue { pyIterable(value).reduce(.int(0), +) }
public func pyMin(_ value: PyValue) -> PyValue { pyIterable(value).min { pyLessThan($0, $1) } ?? .none }
public func pyMax(_ value: PyValue) -> PyValue { pyIterable(value).max { pyLessThan($0, $1) } ?? .none }
public func pyRound(_ value: PyValue, digits: PyValue = .int(0)) -> PyValue {
    let p = pow(10.0, Double(digits.intValue))
    return .double((value.doubleValue * p).rounded() / p)
}
public func pyAny(_ value: PyValue) -> PyValue { .bool(pyIterable(value).contains { $0.truthy }) }
public func pyAll(_ value: PyValue) -> PyValue { .bool(pyIterable(value).allSatisfy { $0.truthy }) }
public func pySorted(_ value: PyValue, reverse: PyValue = .bool(false)) -> PyValue {
    let values = pyIterable(value).sorted { pyLessThan($0, $1) }
    return .list(reverse.truthy ? Array(values.reversed()) : values)
}
public func pyReversed(_ value: PyValue) -> PyValue { .list(Array(pyIterable(value).reversed())) }

public func pyInput(_ prompt: PyValue = .string("")) -> PyValue {
    if !prompt.stringValue.isEmpty { pyPrint([prompt], end: "") }
    return .string(readLine() ?? "")
}

public func pyRange(_ start: PyValue, _ stop: PyValue? = nil, _ step: PyValue = .int(1)) -> PyValue {
    let a: Int64
    let b: Int64
    if let stop = stop { a = start.intValue; b = stop.intValue } else { a = 0; b = start.intValue }
    let s = step.intValue
    if s == 0 { return .list([]) }
    var out: [PyValue] = []
    var i = a
    if s > 0 {
        while i < b { out.append(.int(i)); i += s }
    } else {
        while i > b { out.append(.int(i)); i += s }
    }
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
public func pyEnumerate(_ value: PyValue, start: PyValue = .int(0)) -> PyValue {
    .list(pyIterable(value).enumerated().map { .list([.int(Int64($0.offset) + start.intValue), $0.element]) })
}
public func pyZip(_ values: [PyValue]) -> PyValue {
    let arrays = values.map(pyIterable)
    let n = arrays.map(\.count).min() ?? 0
    return .list((0..<n).map { i in .list(arrays.map { $0[i] }) })
}

private func pyClamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
    min(max(value, lower), upper)
}

public func pySlice(_ value: PyValue, _ start: PyValue = .none, _ stop: PyValue = .none, _ step: PyValue = .none) -> PyValue {
    let items = pyIterable(value)
    let count = items.count
    let stride = step == .none ? 1 : Int(step.intValue)
    if stride == 0 { return .list([]) }

    var result: [PyValue] = []
    if stride > 0 {
        var first: Int
        if start == .none {
            first = 0
        } else {
            first = Int(start.intValue)
            if first < 0 { first += count }
            first = pyClamp(first, 0, count)
        }

        var last: Int
        if stop == .none {
            last = count
        } else {
            last = Int(stop.intValue)
            if last < 0 { last += count }
            last = pyClamp(last, 0, count)
        }

        var i = first
        while i < last {
            result.append(items[i])
            i += stride
        }
    } else {
        var first: Int
        if start == .none {
            first = count - 1
        } else {
            first = Int(start.intValue)
            if first < 0 { first += count }
            first = pyClamp(first, -1, count - 1)
        }

        var last: Int
        if stop == .none {
            last = -1
        } else {
            last = Int(stop.intValue)
            if last < 0 { last += count }
            last = pyClamp(last, -1, count - 1)
        }

        var i = first
        while i > last && i >= 0 && i < count {
            result.append(items[i])
            i += stride
        }
    }

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
public func pyGetenv(_ key: PyValue, _ defaultValue: PyValue = .none) -> PyValue {
    ProcessInfo.processInfo.environment[key.stringValue].map(PyValue.string) ?? defaultValue
}
public func pyGetcwd() -> PyValue { .string(FileManager.default.currentDirectoryPath) }
public func pyExists(_ path: PyValue) -> PyValue { .bool(FileManager.default.fileExists(atPath: path.stringValue)) }
public func pyMkdir(_ path: PyValue) -> PyValue {
    try? FileManager.default.createDirectory(atPath: path.stringValue, withIntermediateDirectories: true)
    return .none
}
public func pyPathJoin(_ values: [PyValue]) -> PyValue {
    .string(values.map(\.stringValue).reduce("") { $0.isEmpty ? $1 : URL(fileURLWithPath: $0).appendingPathComponent($1).path })
}

private indirect enum PyJSONValue: Codable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([PyJSONValue])
    case object([String: PyJSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int64.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([PyJSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: PyJSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    init(_ value: PyValue) {
        switch value {
        case .none: self = .null
        case .bool(let v): self = .bool(v)
        case .int(let v): self = .int(v)
        case .double(let v): self = .double(v)
        case .string(let v): self = .string(v)
        case .list(let v): self = .array(v.map(PyJSONValue.init))
        case .dict(let v): self = .object(v.mapValues(PyJSONValue.init))
        }
    }

    var pyValue: PyValue {
        switch self {
        case .null: return .none
        case .bool(let v): return .bool(v)
        case .int(let v): return .int(v)
        case .double(let v): return .double(v)
        case .string(let v): return .string(v)
        case .array(let v): return .list(v.map(\.pyValue))
        case .object(let v): return .dict(v.mapValues(\.pyValue))
        }
    }
}

public func pyJSONDumps(_ value: PyValue) -> PyValue {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(PyJSONValue(value)), let text = String(data: data, encoding: .utf8) else {
        return .string("null")
    }
    return .string(text)
}
public func pyJSONLoads(_ value: PyValue) -> PyValue {
    guard let data = value.stringValue.data(using: .utf8), let decoded = try? JSONDecoder().decode(PyJSONValue.self, from: data) else {
        return .none
    }
    return decoded.pyValue
}

public final class PyFile {
    private let path: String
    private let mode: String
    private var handle: FileHandle?

    public init(_ path: PyValue, mode: PyValue = .string("r")) {
        self.path = path.stringValue
        self.mode = mode.stringValue
        if self.mode.contains("w") { _ = FileManager.default.createFile(atPath: self.path, contents: Data()) }
        if self.mode.contains("a") && !FileManager.default.fileExists(atPath: self.path) {
            _ = FileManager.default.createFile(atPath: self.path, contents: Data())
        }
        handle = self.mode.contains("r") ? FileHandle(forReadingAtPath: self.path) : FileHandle(forWritingAtPath: self.path)
        if self.mode.contains("a") { _ = try? handle?.seekToEnd() }
    }

    public func read() -> PyValue {
        guard let h = handle else { return .string("") }
        let d = (try? h.readToEnd()) ?? Data()
        return .string(String(data: d, encoding: .utf8) ?? "")
    }

    public func readline() -> PyValue {
        guard let h = handle else { return .string("") }
        var data = Data()
        while true {
            guard let byte = try? h.read(upToCount: 1), !byte.isEmpty else { break }
            data.append(byte)
            if byte.first == 0x0A { break }
        }
        return .string(String(data: data, encoding: .utf8) ?? "")
    }

    @discardableResult public func write(_ value: PyValue) -> PyValue {
        guard let d = value.stringValue.data(using: .utf8) else { return .int(0) }
        try? handle?.write(contentsOf: d)
        return .int(Int64(d.count))
    }
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

    public init(target: String, args: [PyValue] = []) {
        self.target = target
        self.args = args
    }

    public func start() {
        guard let data = try? JSONEncoder().encode(args) else { return }
        let p = Process()
        let out = Pipe()
        pipe = out
        p.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        p.arguments = [pyWorkerFlag, target, data.base64EncodedString()]
        p.standardOutput = out
        p.standardError = FileHandle.standardError
        do {
            try p.run()
            process = p
        } catch {
            fputs("PyProcess launch failed: \(error)\n", stderr)
        }
    }

    @discardableResult public func join() -> PyValue {
        guard let pipe = pipe else { return result }
        // Drain stdout before waiting. Waiting first can deadlock when a worker
        // writes enough data to fill the OS pipe buffer.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process?.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return result }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(line)
            if s.hasPrefix(pyResultPrefix),
               let data = Data(base64Encoded: String(s.dropFirst(pyResultPrefix.count))),
               let v = try? JSONDecoder().decode(PyValue.self, from: data) {
                result = v
            } else if !s.isEmpty {
                pyPrint([.string(s)])
            }
        }
        return result
    }
}

public final class PyPool {
    private let size: Int
    public init(processes: PyValue = .none) {
        self.size = max(1, processes == .none ? ProcessInfo.processInfo.activeProcessorCount : Int(processes.intValue))
    }
    public func map(target: String, items: PyValue) -> PyValue {
        let values = pyIterable(items)
        var results = Array(repeating: PyValue.none, count: values.count)
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
