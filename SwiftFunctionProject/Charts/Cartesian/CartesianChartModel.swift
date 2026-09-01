import Foundation
import UIKit

/// 堆叠配置（阶段 1：普通堆叠 + 扩展点预留）
public enum StackConfig: Equatable {
    /// 不堆叠（默认）
    case none
    /// 普通堆叠（阶段 1 实现）
    case normal
    /// 百分比堆叠：每列按该列 |v| 总和归一（每列必满 100%，Highcharts 同款）
    case percent
    /// 百分比堆叠（统一基准）：所有列按固定 max 归一——列合计可不满/超过 100%，
    /// 适合"对照统一目标/阈值"的占比形态
    case percentFixed(max: Double)
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
    /// 系列线条虚线样式（nil = 跟随主题 lineDashStyle；"实际/预测"区分用）
    public var lineDashStyle: LineDashStyle?
    /// 数据点标记符号（nil = 跟随主题 pointSymbol；多系列形状区分）
    public var pointSymbol: PointMarkerSymbol?
    /// 空值（数据中的 `.nan`）是否跨空连线：false = 断线留缺口（默认，Highcharts 同款）；
    /// true = 忽略空值直接连到下一个有效点。柱状/条形忽略本参数（空值恒不画柱）。
    public var connectNulls: Bool
    /// 逐柱/逐条颜色（Column/Bar 消费；nil = 系列色）。按类目索引循环取色——
    /// 传调色板即 AAChartKit colorByPoint 形态。负值柱优先系列 negativeColor。
    public var barColors: [UIColor]?
    /// 数据标签（数值标注）系列级开关：nil = 跟随主题 showsDataLabels
    /// （数值显示系列原值——堆叠时也标各段自身值，位置在累计后的点/段上）。
    public var dataLabelsEnabled: Bool?
    /// 绑定哪个值轴（0 = 主轴/左，1 = 次轴/右；Bar 水平图仅支持主轴）。
    public var yAxisIndex: Int
    /// clamp 后的有效轴索引（仅 1 绑次轴，其余——含越界——回落主轴 0）。
    public var effectiveYAxisIndex: Int { yAxisIndex == 1 ? 1 : 0 }

    public init(name: String, data: [Double], color: UIColor? = nil, negativeColor: UIColor? = nil,
                yAxisIndex: Int = 0, lineDashStyle: LineDashStyle? = nil,
                connectNulls: Bool = false, pointSymbol: PointMarkerSymbol? = nil,
                dataLabelsEnabled: Bool? = nil,
                barColors: [UIColor]? = nil) {
        self.name = name
        self.data = data
        self.color = color
        self.negativeColor = negativeColor
        self.yAxisIndex = yAxisIndex
        self.lineDashStyle = lineDashStyle
        self.connectNulls = connectNulls
        self.pointSymbol = pointSymbol
        self.dataLabelsEnabled = dataLabelsEnabled
        self.barColors = barColors
    }
}


/// 标线（阈值线；Highcharts plotLines / Charts LimitLine 同款）。
/// 值轴语义：垂直图 = 绘图区内水平横线，水平图（Bar）= 竖线；画在系列之上。
/// 数值超出当前值域时自动不画（缩放平移后跟随显隐）。
public struct CartesianPlotLine {
    /// 标线数值（按 `yAxisIndex` 绑定值轴）
    public var value: Double
    /// 绑定值轴（0 = 主轴，1 = 次轴；水平图仅主轴）
    public var yAxisIndex: Int
    public var color: UIColor
    public var lineWidth: CGFloat
    public var dashStyle: LineDashStyle
    /// 标线旁文字（nil = 无标签；颜色随线色）
    public var label: String?

    public init(value: Double, yAxisIndex: Int = 0,
                color: UIColor = .systemRed, lineWidth: CGFloat = 1,
                dashStyle: LineDashStyle = .solid, label: String? = nil) {
        self.value = value
        self.yAxisIndex = yAxisIndex
        self.color = color
        self.lineWidth = lineWidth
        self.dashStyle = dashStyle
        self.label = label
    }
}

/// 轴系图表数据（折线/柱状等共用）。
public struct CartesianChartModel: HYMChartModel {
    public var title: String?
    public var series: [CartesianSeriesElement]
    public var xAxis: CartesianAxisModel
    public var yAxis: CartesianAxisModel
    /// 次值轴（右）。nil = 单轴（现状）。Bar（水平图）暂不支持，传了会被忽略（DEBUG 断言）。
    public var secondaryYAxis: CartesianAxisModel?
    /// 堆叠配置（nil = 不堆叠）
    public var stacking: StackConfig?
    /// 标线（阈值参考线，画在系列之上；可为多条）
    public var plotLines: [CartesianPlotLine]

    public init(title: String? = nil,
                series: [CartesianSeriesElement],
                xAxis: CartesianAxisModel = CartesianAxisModel(kind: .category(labels: [])),
                yAxis: CartesianAxisModel = CartesianAxisModel(kind: .value),
                secondaryYAxis: CartesianAxisModel? = nil,
                stacking: StackConfig? = nil,
                plotLines: [CartesianPlotLine] = []) {
        self.title = title
        self.series = series
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.secondaryYAxis = secondaryYAxis
        self.stacking = stacking
        self.plotLines = plotLines
    }

    /// 最长 series 的点数（类目数）。
    public var maxPointCount: Int {
        series.map { $0.data.count }.max() ?? 0
    }

    /// 指定值轴的绑定系列全局 (min, max)；堆叠模式下按轴分组累计后取边界。
    /// 任一有效数据都没有时为 nil。轴无绑定系列时：显式 min/max 由渲染层兜底，此处返回 nil。
    public func dataBounds(yAxisIndex: Int = 0) -> (min: Double, max: Double)? {
        let group = series.filter { $0.effectiveYAxisIndex == yAxisIndex }
        guard !group.isEmpty else { return nil }
        let dataToUse: [[Double]]
        switch stacking {
        case .normal:
            dataToUse = CartesianGeometry.stackedValuesByAxis(series: group)
        case .percent:
            dataToUse = CartesianGeometry.stackedPercentValues(series: group)
        case .percentFixed(let max):
            dataToUse = CartesianGeometry.stackedPercentValues(series: group, fixedMax: max)
        default:
            dataToUse = group.map { $0.data }
        }
        let flat = dataToUse.flatMap { $0 }.filter { $0.isFinite }
        guard let lo = flat.min(), let hi = flat.max() else { return nil }
        return (lo, hi)
    }

    /// 是否处于堆叠形态（normal / percent / percentFixed）。
    public var isStacked: Bool {
        switch stacking {
        case .normal, .percent, .percentFixed: return true
        default: return false
        }
    }

    /// 渲染用累计数据（normal → 符号链累计；percent 系 → 百分比累计；其余原值）。与系列同序。
    public var stackedDrawValues: [[Double]] {
        switch stacking {
        case .normal: return CartesianGeometry.stackedValuesByAxis(series: series)
        case .percent: return CartesianGeometry.stackedPercentValues(series: series)
        case .percentFixed(let max):
            return CartesianGeometry.stackedPercentValues(series: series, fixedMax: max)
        default: return series.map { $0.data }
        }
    }

    /// 堆叠基准原值（面积下边界/柱基准 = 累计 − 本值）：percent 系为归一化原值，否则原值。
    public func rawBaseValues(forSeries seriesIndex: Int) -> [Double] {
        guard seriesIndex < series.count else { return [] }
        switch stacking {
        case .percent:
            return CartesianGeometry.percentNormalizedValues(series: series)[seriesIndex]
        case .percentFixed(let max):
            return CartesianGeometry.percentNormalizedValues(series: series, fixedMax: max)[seriesIndex]
        default:
            return series[seriesIndex].data
        }
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
