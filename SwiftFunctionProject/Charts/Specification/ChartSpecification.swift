import Foundation

/// 与绘图库无关的轴系图表描述。只保存输入意图，不保存累计值、格式化缓存或 UIView。
/// 可在任意线程构造/复制；同一可变变量仍需调用方同步。schemaVersion 用于持久化演进。
public struct ChartSpecification: Codable, Equatable, Sendable {
    /// 最新可读取版本。构造器仍默认 v1，新增边界语义须显式选择 v2。
    public static let latestSchemaVersion: Int = 4
    public var schemaVersion: Int = 1
    public var id: String
    public var title: String?
    public var orientation: ChartOrientation
    public var domain: ChartDomain
    public var domainAppearance: ChartAxisAppearance
    /// schema v4：类目标签候选间隔，须正整数；nil 自动。不抽样数据或改变网格。
    /// 按绝对类目索引取模；空间不足可按其整数倍避让。仅适用于 categories 域。
    public var categoryLabelInterval: Int?
    /// 按展示顺序排列；系列通过 ID 绑定，不能通过数组下标绑定。
    public var valueAxes: [ChartAxisSpecification]
    public var groups: [ChartGroupSpecification]
    public var series: [ChartSeriesSpecification]
    public var stacking: ChartStackingPolicy
    /// v1 固定 independent；v2 及以后在 JSON 中必须显式保存此字段。
    public var stackedAreaBoundary: ChartStackedAreaBoundary
    public var showsLegend: Bool

    /// 创建描述；通过 validate() 或适配器检查引用、数值和目标能力后使用。
    public init(id: String, title: String? = nil, orientation: ChartOrientation = .vertical,
                domain: ChartDomain, valueAxes: [ChartAxisSpecification],
                series: [ChartSeriesSpecification], groups: [ChartGroupSpecification] = [],
                stacking: ChartStackingPolicy = .none, showsLegend: Bool = true,
                domainAppearance: ChartAxisAppearance = .init(),
                schemaVersion: Int = 1, stackedAreaBoundary: ChartStackedAreaBoundary = .independent,
                categoryLabelInterval: Int? = nil) {
        self.schemaVersion = schemaVersion; self.stackedAreaBoundary = stackedAreaBoundary
        self.categoryLabelInterval = categoryLabelInterval
        self.id = id; self.title = title; self.orientation = orientation; self.domain = domain
        self.valueAxes = valueAxes; self.series = series; self.groups = groups
        self.stacking = stacking; self.showsLegend = showsLegend; self.domainAppearance = domainAppearance
    }

    /// 校验后编码为可持久化 JSON；缺测为 nil，不编码 NaN/Infinity。
    public func jsonData() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// 解码并校验版本及数据契约；不把未知版本当成当前版本使用。
    public static func decodeJSON(_ data: Data) throws -> ChartSpecification {
        let result = try JSONDecoder().decode(Self.self, from: data)
        try result.validate()
        return result
    }
}

/// 类目轴的屏幕方向；水平图仍然保留“domain / value”语义。
public enum ChartOrientation: String, Codable, Sendable { case vertical, horizontal }

/// 业务展示分组；不会因此求和、堆叠或转换单位。
public struct ChartGroupSpecification: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    /// ID 必须非空且在图表中唯一，名称可以重复。
    public init(id: String, name: String) { self.id = id; self.name = name }
}

/// 数学堆叠。组键由值轴 ID、图形族（柱 / 线面积）和 series.stackID 共同确定。
/// nil stackID 始终独立。sum 分别累计正负；百分比分母为同组可见贡献绝对值之和。
public enum ChartStackingPolicy: Codable, Equatable, Sendable {
    case none
    case sum
    case percentOfAbsoluteTotal
    case percentOfFixedTotal(Double)
}

/// 线/面积数学堆叠在采样点之间的边界语义；不改变原始样本、业务身份或命中值。
/// 非 independent 需要 schema v2 或更高、启用数学堆叠且至少有一个带 stackID 的线/面积系列。
/// 隐藏系列仍构成有效配置；柱族和未参与堆叠的系列不受此策略影响。
public enum ChartStackedAreaBoundary: String, Codable, CaseIterable, Sendable {
    /// 累计边界分别插值，保留 v1 外观，不保证相邻薄层不会交叉。
    case independent
    /// 插值自身厚度后沿已有基线叠加；保留逐系列缺测策略。
    /// 自动百分比插值采样份额；无法共享基线的组可兼容回退，不保证全域无重叠。
    case followBaseline
    /// 分别累计插值后的正负贡献；同组任何可见参与系列缺测即统一断段。
    /// 优先于逐系列 missingValues；纯折线也参与，零值归正链，隐藏系列不参与断段。
    /// 自动百分比分母是组内贡献绝对值之和；不将正负各拉满 100%。
    /// 数值/精度预算不足时可整组降级为共享直线，但不得退回独立边界。
    case diverging
}
