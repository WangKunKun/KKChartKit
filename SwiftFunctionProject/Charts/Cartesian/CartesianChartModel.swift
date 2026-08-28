import Foundation
import UIKit

/// 堆叠配置（阶段 1：普通堆叠 + 扩展点预留）
public enum StackConfig: Equatable {
    /// 不堆叠（默认）
    case none
    /// 普通堆叠（阶段 1 实现）
    case normal
    /// 百分比堆叠（预留，阶段 X）
    case percent
    /// 分组堆叠（预留，阶段 X）
    case grouped(groupCount: Int)
}

/// 轴类型。阶段 0 仅实现 `.category` 的渲染；`.value` 为阶段 5 散点图预留。
public enum CartesianAxisKind {
    /// 类目轴。`labels` 为空时自动生成数字标签 "1"..."n"（n = 最长 series 点数）。
    case category(labels: [String])
    /// 数值轴（阶段 5 实现 x 向数值映射；阶段 0 按类目处理）。
    case value
}

/// 轴配置（x/y 通用）。
public struct CartesianAxisModel {
    public var kind: CartesianAxisKind
    /// 显式值域下界；nil = 自动（y 轴自动时走 nice scale，x 轴自动按类目数）。
    public var min: Double?
    /// 显式值域上界；nil = 自动。
    public var max: Double?
    /// 显式刻度步长；nil = 自动（nice step）。显式时须与 min/max 同显式，否则忽略。
    public var tickInterval: Double?
    /// 目标刻度数量（nice scale 依据；实际 ±1~2。nil = 默认 6）。
    public var tickCount: Int?
    /// 完全显式刻度值（最高优先级；域外值被过滤）。类目轴忽略。
    public var tickPositions: [Double]?
    /// 刻度文本自定义（nil = 内置去尾零格式）。
    public var labelFormatter: ((Double) -> String)?
    /// 该轴是否画网格（nil = 主轴跟随 theme、次轴默认关）。
    public var showsGridlines: Bool?

    public init(kind: CartesianAxisKind,
                min: Double? = nil, max: Double? = nil, tickInterval: Double? = nil,
                tickCount: Int? = nil, tickPositions: [Double]? = nil,
                labelFormatter: ((Double) -> String)? = nil, showsGridlines: Bool? = nil) {
        self.kind = kind
        self.min = min
        self.max = max
        self.tickInterval = tickInterval
        self.tickCount = tickCount
        self.tickPositions = tickPositions
        self.labelFormatter = labelFormatter
        self.showsGridlines = showsGridlines
    }
}

/// 单个数据系列（阶段 0：等距数值数组，按索引对位类目）。
public struct CartesianSeriesElement {
    public var name: String
    public var data: [Double]
    /// nil → 用主题默认系列色。
    public var color: UIColor?
    /// 负值数据点的覆盖颜色（nil = 使用 color）
    public var negativeColor: UIColor?

    public init(name: String, data: [Double], color: UIColor? = nil, negativeColor: UIColor? = nil) {
        self.name = name
        self.data = data
        self.color = color
        self.negativeColor = negativeColor
    }
}

/// 轴系图表数据（折线/柱状等共用）。
public struct CartesianChartModel: HYMChartModel {
    public var title: String?
    public var series: [CartesianSeriesElement]
    public var xAxis: CartesianAxisModel
    public var yAxis: CartesianAxisModel
    /// 堆叠配置（nil = 不堆叠）
    public var stacking: StackConfig?

    public init(title: String? = nil,
                series: [CartesianSeriesElement],
                xAxis: CartesianAxisModel = CartesianAxisModel(kind: .category(labels: [])),
                yAxis: CartesianAxisModel = CartesianAxisModel(kind: .value),
                stacking: StackConfig? = nil) {
        self.title = title
        self.series = series
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.stacking = stacking
    }

    /// 最长 series 的点数（类目数）。
    public var maxPointCount: Int {
        series.map { $0.data.count }.max() ?? 0
    }

    /// 所有 series 数据的全局 (min, max)；任一有效数据都没有时为 nil。
    /// 堆叠模式下使用累计值计算边界，确保 Y 轴刻度尺适应堆叠后的数据范围。
    public var dataBounds: (min: Double, max: Double)? {
        let dataToUse: [[Double]]
        if stacking == .normal {
            dataToUse = CartesianGeometry.stackedValues(series: series)
        } else {
            dataToUse = series.map { $0.data }
        }

        let flat = dataToUse.flatMap { $0 }
        guard let lo = flat.min(), let hi = flat.max() else { return nil }
        return (lo, hi)
    }

    /// 实际生效的类目标签：显式非空优先；否则自动 "1"..."n"（1-based，用户友好）。
    /// 锯齿 series（各系列长度不一）时以最长 series 为准；短系列的空位语义由渲染层决定。
    /// 空 series 返回 []（`1...0` 会触发 Range 构造崩溃，必须先判空）。
    public var categoryLabels: [String] {
        if case .category(let labels) = xAxis.kind, !labels.isEmpty {
            return Array(labels.prefix(maxPointCount))
        }
        guard maxPointCount > 0 else { return [] }
        return (1...maxPointCount).map { String($0) }
    }
}
