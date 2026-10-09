import Foundation

/// 类目按数组顺序展示；数值/时间是实际坐标，不能被适配器悄悄转成等距索引。
public enum ChartDomain: Codable, Equatable, Sendable {
    case categories([ChartCategory])
    case numeric
    case time
}

/// 显示文字不充当身份。同名类目可以通过不同 ID 区分。
public struct ChartCategory: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    /// ID 非空且在 domain 内唯一。
    public init(id: String, label: String) { self.id = id; self.label = label }
}

/// 时间坐标统一为 Unix 秒；引擎需要毫秒时仅由适配器转换。
public enum ChartCoordinate: Codable, Equatable, Hashable, Sendable {
    case category(String)
    case number(Double)
    case unixSeconds(Double)
}

/// 一个有稳定身份的原始采样。nil 是缺测，0 是有效值，负数不进行预拆分。
public struct ChartSample: Codable, Equatable, Sendable {
    public var id: String
    public var coordinate: ChartCoordinate
    public var value: Double?
    /// 不参与绘制的业务上下文。适配结果通过原始采样身份查回，禁止解释为引擎配置。
    public var metadata: [String: String]
    /// 样本 ID 在所属系列内唯一；组合 (seriesID, sampleID) 是跨更新身份。
    public init(id: String, coordinate: ChartCoordinate, value: Double?, metadata: [String: String] = [:]) {
        self.id = id; self.coordinate = coordinate; self.value = value; self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey { case id, coordinate, value, metadata }
    /// 显式写出 JSON null，便于 Swift/OC/其他平台区分采样缺测和整个采样不存在。
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(value, forKey: .value)
        try container.encode(metadata, forKey: .metadata)
    }
}

/// 几何图元；曲线是 interpolation，水平柱是 orientation，均不增加厂商类型字符串。
public enum ChartMark: String, Codable, Sendable { case line, area, bar }

/// 线性、单调曲线及三种阶梯；不使用 spline/areaspline 等厂商类型组合。
public enum ChartInterpolation: String, Codable, CaseIterable, Sendable {
    case linear, monotone, stepBefore, stepAfter, stepCenter
}

/// 空位数按 domain 内缺少的类目计数；不补值、不改变原始采样。
public enum ChartMissingValuePolicy: Codable, Equatable, Sendable {
    case breakPath
    case connect
    case connectUpTo(missingCategoryCount: Int)
}

/// 数据、业务身份、数学绑定与外观各自明确；不持有底层库对象。
public struct ChartSeriesSpecification: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var mark: ChartMark
    public var valueAxisID: String
    public var groupID: String?
    public var stackID: String?
    public var samples: [ChartSample]
    public var unit: String?
    public var valuePresentation: ChartValuePresentation
    public var interpolation: ChartInterpolation
    public var missingValues: ChartMissingValuePolicy
    public var appearance: ChartSeriesAppearance
    public var isVisible: Bool
    public var showsInLegend: Bool

    /// 类目样本允许稀疏、乱序，适配时按 category ID 对齐；数值/时间样本须严格递增。
    /// 未给 stackID 时不参与堆叠；业务 groupID 不影响数学。
    public init(id: String, name: String, mark: ChartMark, valueAxisID: String,
                samples: [ChartSample], groupID: String? = nil, stackID: String? = nil,
                unit: String? = nil, valuePresentation: ChartValuePresentation = .init(),
                interpolation: ChartInterpolation = .linear, missingValues: ChartMissingValuePolicy = .breakPath,
                appearance: ChartSeriesAppearance = .init(), isVisible: Bool = true, showsInLegend: Bool = true) {
        self.id = id; self.name = name; self.mark = mark; self.valueAxisID = valueAxisID
        self.samples = samples; self.groupID = groupID; self.stackID = stackID; self.unit = unit
        self.valuePresentation = valuePresentation; self.interpolation = interpolation
        self.missingValues = missingValues; self.appearance = appearance
        self.isVisible = isVisible; self.showsInLegend = showsInLegend
    }
}
