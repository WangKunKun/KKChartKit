import Foundation

// 明确的跨语言 JSON 协议，不把 Swift 关联值枚举的 _0/_1 合成键当成公共文件格式。
extension ChartDomain {
    private enum Keys: String, CodingKey { case kind, categories }
    private enum Kind: String, Codable { case category, numeric, time }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .category: self = .categories(try c.decode([ChartCategory].self, forKey: .categories))
        case .numeric: self = .numeric
        case .time: self = .time
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .categories(let values): try c.encode(Kind.category, forKey: .kind); try c.encode(values, forKey: .categories)
        case .numeric: try c.encode(Kind.numeric, forKey: .kind)
        case .time: try c.encode(Kind.time, forKey: .kind)
        }
    }
}

extension ChartCoordinate {
    private enum Keys: String, CodingKey { case kind, categoryID, value, unixSeconds }
    private enum Kind: String, Codable { case category, number, time }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .category: self = .category(try c.decode(String.self, forKey: .categoryID))
        case .number: self = .number(try c.decode(Double.self, forKey: .value))
        case .time: self = .unixSeconds(try c.decode(Double.self, forKey: .unixSeconds))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .category(let id): try c.encode(Kind.category, forKey: .kind); try c.encode(id, forKey: .categoryID)
        case .number(let value): try c.encode(Kind.number, forKey: .kind); try c.encode(value, forKey: .value)
        case .unixSeconds(let value): try c.encode(Kind.time, forKey: .kind); try c.encode(value, forKey: .unixSeconds)
        }
    }
}

extension ChartStackingPolicy {
    private enum Keys: String, CodingKey { case mode, total }
    private enum Mode: String, Codable { case none, sum, percentOfAbsoluteTotal, percentOfFixedTotal }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(Mode.self, forKey: .mode) {
        case .none: self = .none
        case .sum: self = .sum
        case .percentOfAbsoluteTotal: self = .percentOfAbsoluteTotal
        case .percentOfFixedTotal: self = .percentOfFixedTotal(try c.decode(Double.self, forKey: .total))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .none: try c.encode(Mode.none, forKey: .mode)
        case .sum: try c.encode(Mode.sum, forKey: .mode)
        case .percentOfAbsoluteTotal: try c.encode(Mode.percentOfAbsoluteTotal, forKey: .mode)
        case .percentOfFixedTotal(let total): try c.encode(Mode.percentOfFixedTotal, forKey: .mode); try c.encode(total, forKey: .total)
        }
    }
}

extension ChartMissingValuePolicy {
    private enum Keys: String, CodingKey { case mode, maximumMissingCategories }
    private enum Mode: String, Codable { case breakPath, connect, connectUpTo }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(Mode.self, forKey: .mode) {
        case .breakPath: self = .breakPath
        case .connect: self = .connect
        case .connectUpTo: self = .connectUpTo(missingCategoryCount: try c.decode(Int.self, forKey: .maximumMissingCategories))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .breakPath: try c.encode(Mode.breakPath, forKey: .mode)
        case .connect: try c.encode(Mode.connect, forKey: .mode)
        case .connectUpTo(let count): try c.encode(Mode.connectUpTo, forKey: .mode); try c.encode(count, forKey: .maximumMissingCategories)
        }
    }
}

extension ChartAreaFill {
    private enum Keys: String, CodingKey { case kind, color, top, bottom }
    private enum Kind: String, Codable { case solid, verticalGradient }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .solid: self = .solid(try c.decode(ChartRGBA.self, forKey: .color))
        case .verticalGradient: self = .verticalGradient(top: try c.decode(ChartRGBA.self, forKey: .top), bottom: try c.decode(ChartRGBA.self, forKey: .bottom))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .solid(let color): try c.encode(Kind.solid, forKey: .kind); try c.encode(color, forKey: .color)
        case .verticalGradient(let top, let bottom):
            try c.encode(Kind.verticalGradient, forKey: .kind); try c.encode(top, forKey: .top); try c.encode(bottom, forKey: .bottom)
        }
    }
}
