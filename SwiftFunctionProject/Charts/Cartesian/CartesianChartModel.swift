import Foundation
import UIKit

/// 堆叠配置；同轴同图形族内再按系列 stackID 分组。
public enum StackConfig: Equatable {
    /// 不堆叠（默认）
    case none
    /// 普通堆叠，同轴同族同 stackID 内分别累计。
    case normal
    /// 百分比堆叠：各堆叠组按当前类目的 |v| 总和归一（正负共享分母）。
    case percent
    /// 百分比堆叠（统一基准）：所有列按固定 max 归一——列合计可不满/超过 100%，
    /// 适合"对照统一目标/阈值"的占比形态
    case percentFixed(max: Double)
    /// 普通分组堆叠：未设置 stackID 的系列按原始序号 % max(1, groupCount) 分组。
    /// 推荐 normal/percent + 显式 stackID，避免重排序改变分组。
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
    /// 刻度标签旋转角度（度，顺时针为正；默认 0 = 不旋转）。
    /// 仅作用于垂直图底部类目标签；数值轴与 Bar 左侧标签忽略。
    public var tickLabelRotation: CGFloat = 0
    public var style: CartesianAxisStyle
    /// 类目标签候选步长（绝对原始索引取模）；nil/非正数自动。
    /// 为避免重叠，空间不足时按该步长的整数倍继续抽稀；不改变刻度、网格或数据。
    public var categoryLabelInterval: Int?

    public init(kind: CartesianAxisKind,
                min: Double? = nil, max: Double? = nil, tickInterval: Double? = nil,
                tickCount: Int? = nil, tickPositions: [Double]? = nil,
                labelFormatter: ((Double) -> String)? = nil, showsGridlines: Bool? = nil,
                tickLabelRotation: CGFloat = 0, style: CartesianAxisStyle = .init(),
                categoryLabelInterval: Int? = nil) {
        self.kind = kind
        self.min = min
        self.max = max
        self.tickInterval = tickInterval
        self.tickCount = tickCount
        self.tickPositions = tickPositions
        self.labelFormatter = labelFormatter
        self.showsGridlines = showsGridlines
        self.tickLabelRotation = tickLabelRotation
        self.style = style; self.categoryLabelInterval = categoryLabelInterval
    }
}

/// 单个数据系列（阶段 0：等距数值数组，按索引对位类目）。
public struct CartesianSeriesElement {
    /// 跨更新保持稳定且唯一。SwiftUI 重建模型时应显式传入业务 ID。
    public var id: String
    public var isVisible: Bool
    public var showsInLegend: Bool
    /// 仅影响图例顺序；同值按原始系列顺序排列。
    public var aggregation: CartesianAggregation?
    public var unit: String?
    /// 业务组 ID；不改变数学堆叠。
    public var groupID: String?
    /// 每系列展示规则；nil 沿用容器模板。
    public var valueFormat: CartesianValueFormat?
    /// 混合图选择绘制形态；折线图也可选择默认连线/面积样式。
    public var kind: CartesianSeriesKind?
    /// 数学堆叠组；nil 为默认组，空字符串也是独立显式组。与 groupID 无关。
    public var stackID: String?
    /// false 时在任意堆叠模式下保持原值及零基线（例如混合图的目标线）。
    public var participatesInStack: Bool
    public var style: CartesianSeriesStyle
    var stackPartition: Int?
    var stackFamilyIsColumn: Bool?
    public var legendOrder: Int
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
    /// nil 兼容 connectNulls；非 nil 优先使用显式策略，仅影响折线/面积路径。
    public var gapPolicy: CartesianGapPolicy?
    /// 逐系列 X/Y 分区；线族连续裁色，柱/条按指定数值整段换色。nil 保持旧行为。
    public var colorZones: CartesianColorZones?
    /// 逐柱/逐条颜色（Column/Bar 消费；nil = 系列色）。按类目索引循环取色——
    /// 传调色板即 colorByPoint 形态。有效 colorZones 优先，其次为不同于系列色的 negativeColor。
    public var barColors: [UIColor]?
    /// 系列阴影（nil = 跟随主题 seriesShadow；两者皆 nil = 无阴影）。
    /// 作用于系列主体层：柱/条体、折线（Highcharts shadow 同款）。
    public var shadow: CartesianShadowStyle?
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
                barColors: [UIColor]? = nil,
                shadow: CartesianShadowStyle? = nil,
                id: String = UUID().uuidString, isVisible: Bool = true,
                showsInLegend: Bool = true, legendOrder: Int = 0,
                aggregation: CartesianAggregation? = nil, unit: String? = nil,
                groupID: String? = nil, valueFormat: CartesianValueFormat? = nil,
                kind: CartesianSeriesKind? = nil, stackID: String? = nil,
                participatesInStack: Bool = true, style: CartesianSeriesStyle = .init(),
                gapPolicy: CartesianGapPolicy? = nil, colorZones: CartesianColorZones? = nil) {
        self.kind = kind; self.stackID = stackID
        self.participatesInStack = participatesInStack; self.style = style
        self.id = id
        self.isVisible = isVisible
        self.showsInLegend = showsInLegend
        self.legendOrder = legendOrder
        self.aggregation = aggregation
        self.unit = unit
        self.groupID = groupID
        self.valueFormat = valueFormat
        self.name = name
        self.data = data
        self.color = color
        self.negativeColor = negativeColor
        self.yAxisIndex = yAxisIndex
        self.lineDashStyle = lineDashStyle
        self.connectNulls = connectNulls
        self.gapPolicy = gapPolicy
        self.colorZones = colorZones
        self.pointSymbol = pointSymbol
        self.dataLabelsEnabled = dataLabelsEnabled
        self.barColors = barColors
        self.shadow = shadow
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
    /// 标线旁文字（nil = 无标签；未覆盖文字颜色时跟随线色）
    public var label: String?
    public var labelStyle: CartesianAnnotationLabelStyle

    public init(value: Double, yAxisIndex: Int = 0,
                color: UIColor = .systemRed, lineWidth: CGFloat = 1,
                dashStyle: LineDashStyle = .solid, label: String? = nil,
                labelStyle: CartesianAnnotationLabelStyle = .init()) {
        self.value = value
        self.yAxisIndex = yAxisIndex
        self.color = color
        self.lineWidth = lineWidth
        self.dashStyle = dashStyle
        self.label = label; self.labelStyle = labelStyle
    }
}

/// 色带（值轴区间背景色块；Highcharts plotBands 同款）。
/// 值轴语义：垂直图 = 绘图区内水平横带，水平图（Bar）= 竖带；画在网格之上、系列之下。
/// 区间与当前值域无交集时自动不画（缩放平移后跟随显隐）；部分越界裁剪到绘图区。
public struct CartesianPlotBand {
    /// 区间下界（按 `yAxisIndex` 绑定值轴；from/to 大小不限，内部按 min/max）
    public var from: Double
    /// 区间上界
    public var to: Double
    /// 绑定值轴（0 = 主轴，1 = 次轴；水平图仅主轴）
    public var yAxisIndex: Int
    /// 带体颜色（建议半透明，如 `UIColor.systemGreen.withAlphaComponent(0.12)`）
    public var color: UIColor
    /// 带内文字（nil = 无标签；默认居中，文字默认取带色的不透明版）
    public var label: String?
    public var labelStyle: CartesianAnnotationLabelStyle

    public init(from: Double, to: Double, yAxisIndex: Int = 0,
                color: UIColor = UIColor.systemGreen.withAlphaComponent(0.12),
                label: String? = nil, labelStyle: CartesianAnnotationLabelStyle = .init()) {
        self.from = from
        self.to = to
        self.yAxisIndex = yAxisIndex
        self.color = color
        self.label = label; self.labelStyle = labelStyle
    }
}

/// 系列阴影样式（Highcharts shadow / Charts shadowColor 系同款）。
/// 作用于系列主体层（柱/条体复合 path、折线）；nil = 无阴影。
public struct CartesianShadowStyle {
    public var color: UIColor
    public var offsetX: CGFloat
    public var offsetY: CGFloat
    /// 模糊半径（Highcharts shadow.width 同义）
    public var blurRadius: CGFloat
    /// 阴影不透明度（0...1，与颜色自身 alpha 相乘）
    public var opacity: Float

    public init(color: UIColor = .black,
                offsetX: CGFloat = 0, offsetY: CGFloat = 2,
                blurRadius: CGFloat = 4, opacity: Float = 0.25) {
        self.color = color
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.blurRadius = max(0, blurRadius)
        self.opacity = min(1, max(0, opacity))
    }
}

/// 轴系图表数据（折线/柱状等共用）。
public struct CartesianChartModel: HYMChartModel {
    public var timeAxis: CartesianTimeAxis?
    public var timeGrouping: CartesianTimeGrouping?
    // 聚合渲染仍使用原始索引坐标；仅桶首索引承载绘制值。
    var timeBucketStride = 1
    // 固定柱宽时末尾不足一桶也占完整槽；元数据及原始数据不补点。
    var padsTimeBuckets = false
    var categoryLayoutCount: Int {
        padsTimeBuckets ? ((maxPointCount + timeBucketStride - 1) / timeBucketStride) * timeBucketStride : maxPointCount
    }
    var timeBucketMetadata: [[Int: CartesianTimeBucket]] = []
    func bucketAnchor(for index: Int) -> Int { index / timeBucketStride * timeBucketStride }
    func categoryPosition(_ index: Int) -> Double {
        Double(index) + (categorySpan(index) - 1) / 2
    }
    func categorySpan(_ index: Int) -> Double { Double(padsTimeBuckets ? timeBucketStride : min(timeBucketStride, maxPointCount - index)) }
    func timeBucket(series: Int, category: Int) -> CartesianTimeBucket? {
        guard timeBucketMetadata.indices.contains(series) else { return nil }
        return timeBucketMetadata[series][category]
    }

    public var title: String?
    /// 业务组元数据；重复 ID 时命中采用第一项，未找到则 groupName 为 nil。
    public var groups: [CartesianSeriesGroup]
    public var series: [CartesianSeriesElement]
    public var xAxis: CartesianAxisModel
    public var yAxis: CartesianAxisModel
    /// 次值轴（右）。nil = 单轴（现状）。Bar（水平图）暂不支持，传了会被忽略（DEBUG 断言）。
    public var secondaryYAxis: CartesianAxisModel?
    /// 堆叠配置（nil = 不堆叠）
    public var stacking: StackConfig?
    /// 标线（阈值参考线，画在系列之上；可为多条）
    public var plotLines: [CartesianPlotLine]
    /// 色带（区间背景色块，画在网格之上、系列之下；可为多条）
    public var plotBands: [CartesianPlotBand]

    public init(title: String? = nil,
                series: [CartesianSeriesElement],
                xAxis: CartesianAxisModel = CartesianAxisModel(kind: .category(labels: [])),
                yAxis: CartesianAxisModel = CartesianAxisModel(kind: .value),
                secondaryYAxis: CartesianAxisModel? = nil,
                stacking: StackConfig? = nil,
                plotLines: [CartesianPlotLine] = [],
                plotBands: [CartesianPlotBand] = [],
                timeAxis: CartesianTimeAxis? = nil, timeGrouping: CartesianTimeGrouping? = nil,
                groups: [CartesianSeriesGroup] = []) {
        self.groups = groups
        self.title = title
        self.series = series
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.secondaryYAxis = secondaryYAxis
        self.stacking = stacking
        self.plotLines = plotLines
        self.plotBands = plotBands
        self.timeAxis = timeAxis
        self.timeGrouping = timeGrouping
    }

    /// 最长 series 的点数（类目数）。
    public var maxPointCount: Int {
        series.map { $0.data.count }.max() ?? 0
    }

    /// 指定值轴的绑定系列全局 (min, max)；堆叠模式下按轴分组累计后取边界。
    /// 任一有效数据都没有时为 nil。轴无绑定系列时：显式 min/max 由渲染层兜底，此处返回 nil。
    public func dataBounds(yAxisIndex: Int = 0) -> (min: Double, max: Double)? {
        let values = stackedDrawValues
        let flat = series.indices.filter { series[$0].isVisible && series[$0].effectiveYAxisIndex == yAxisIndex }
            .flatMap { values.indices.contains($0) ? values[$0] : [] }.filter(\.isFinite)
        guard let lo = flat.min(), let hi = flat.max() else { return nil }
        return (lo, hi)
    }

    /// 是否处于堆叠形态（normal / percent / percentFixed / grouped）。
    public var isStacked: Bool {
        switch stacking {
        case .normal, .percent, .percentFixed, .grouped: return true
        default: return false
        }
    }

    /// 渲染用累计数据（normal → 符号链累计；percent 系 → 百分比累计；其余原值）。与系列同序。
    public var stackedDrawValues: [[Double]] {
        let series = renderingSeries
        switch stacking {
        case .normal, .grouped: return CartesianGeometry.stackedValuesByAxis(series: series)
        case .percent: return CartesianGeometry.stackedPercentValues(series: series)
        case .percentFixed(let max):
            return CartesianGeometry.stackedPercentValues(series: series, fixedMax: max)
        default: return series.map { $0.data }
        }
    }

    /// 一次性计算所有系列基准值，渲染/命中复用，避免逐柱归一化。
    var allBaseValues: [[Double]] {
        let series = renderingSeries
        switch stacking {
        case .percent: return CartesianGeometry.percentNormalizedValues(series: series)
        case .percentFixed(let max): return CartesianGeometry.percentNormalizedValues(series: series, fixedMax: max)
        default: return series.map(\.data)
        }
    }

    /// 堆叠基准原值（面积下边界/柱基准 = 累计 − 本值）：percent 系为归一化原值，否则原值。
    public func rawBaseValues(forSeries seriesIndex: Int) -> [Double] {
        guard series.indices.contains(seriesIndex) else { return [] }
        let series = renderingSeries
        switch stacking {
        case .percent:
            return CartesianGeometry.percentNormalizedValues(series: series)[seriesIndex]
        case .percentFixed(let max):
            return CartesianGeometry.percentNormalizedValues(series: series, fixedMax: max)[seriesIndex]
        default:
            return series[seriesIndex].data
        }
    }

    /// 保留系列/类目索引和颜色；隐藏数据用缺值占位，不参与数学运算。
    var renderingSeries: [CartesianSeriesElement] {
        series.enumerated().map { index, element in
            var result = element
            if case .grouped(let count) = stacking, result.stackID == nil {
                result.stackPartition = index % max(1, count)
            }
            if !element.isVisible { result.data = Array(repeating: .nan, count: element.data.count) }
            return result
        }
    }

    var usesMixedSeries = false
    func stackKey(for index: Int) -> CartesianStackKey {
        var element = series[index]
        if case .grouped(let count) = stacking, element.stackID == nil {
            element.stackPartition = index % max(1, count)
        }
        return element.stackKey
    }
    var columnSlots: [Int: Int] {
        var keys: [CartesianStackKey] = []
        var slots: [Int: Int] = [:]
        for i in series.indices where series[i].isVisible && (!usesMixedSeries || (series[i].kind?.isColumn ?? true)) {
            if isStacked && series[i].participatesInStack {
                let key = stackKey(for: i)
                if let slot = keys.firstIndex(of: key) { slots[i] = slot }
                else { slots[i] = keys.count; keys.append(key) }
            } else {
                slots[i] = keys.count
                let key = stackKey(for: i)
                keys.append(.init(axis: key.axis, stackID: key.stackID, partition: i,
                                  column: key.column, independentSeries: series[i].id))
            }
        }
        return slots
    }
    var columnSlotCount: Int { (columnSlots.values.max() ?? -1) + 1 }
    func columnSlot(for index: Int) -> Int { columnSlots[index] ?? 0 }

    var visibleSeriesCount: Int { series.filter(\.isVisible).count }
    func visibleSlot(for index: Int) -> Int {
        series.prefix(index).filter(\.isVisible).count
    }

    /// 实际生效的类目标签：显式非空优先；否则自动 "1"..."n"（1-based，用户友好）。
    /// 锯齿 series（各系列长度不一）时以最长 series 为准；短系列的空位语义由渲染层决定。
    /// 空 series 返回 []（`1...0` 会触发 Range 构造崩溃，必须先判空）。
    public var categoryLabels: [String] {
        if case .category(let labels) = xAxis.kind, !labels.isEmpty {
            return Array(labels.prefix(maxPointCount))
        }
        guard maxPointCount > 0 else { return [] }
        if let timeAxis, timeAxis.isValid(count: maxPointCount) { return timeAxis.labels(count: maxPointCount) }
        return (1...maxPointCount).map { String($0) }
    }
}
