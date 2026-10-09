import UIKit

@objc public enum HYMCartesianChartKind: Int { case line, column, bar, combined }
@objc public enum HYMCartesianStacking: Int { case none, normal, percent, percentFixed, grouped }

/// mixed 系列类型；automatic 在混合图为柱，折线图跟随主题。
@objc public enum HYMCartesianSeriesKind: Int { case automatic, column, line, spline, area, areaspline }
/// 系列连接形态；inherit 使用图形类型/主题默认值。
@objc public enum HYMCartesianLineConnection: Int { case inherit, straight, smooth, stepAfter, stepBefore, stepCenter }
/// 系列标记形状，inherit 跟随主题。
@objc public enum HYMCartesianMarker: Int { case inherit, circle, square, diamond, triangle, triangleDown }
/// OC 系列样式；NSNumber 的 nil 表示恢复继承。UI 配置前构造，勿并发修改。
@objcMembers public final class HYMCartesianSeriesStyle: NSObject {
    public var connection: HYMCartesianLineConnection = .inherit
    public var lineWidth: NSNumber?
    public var showsPoints: NSNumber?
    public var pointRadius: NSNumber?
    public var showsArea: NSNumber?
    public var areaGradientColors: [UIColor]?
    public var fillOpacity: NSNumber?
    func build() -> CartesianSeriesStyle {
        var s = CartesianSeriesStyle()
        s.lineConnectionStyle = [nil, .straight, .smooth, .stepAfter, .stepBefore, .stepCenter][connection.rawValue]
        s.lineWidth = lineWidth.map { CGFloat($0.doubleValue) }
        s.showsPoints = showsPoints?.boolValue
        s.pointRadius = pointRadius.map { CGFloat($0.doubleValue) }
        s.showsArea = showsArea?.boolValue
        s.areaGradientColors = areaGradientColors
        s.fillOpacity = fillOpacity.map { CGFloat($0.doubleValue) }
        return s
    }
}

/// 最小 OC 格式包装。与 Swift CartesianValueFormat 使用同一格式化实现。
/// 配置对象应在调用 configure/update 前完成设置，不要并发修改。
@objcMembers public final class HYMCartesianValueFormat: NSObject {
    public var engineeringScale = false
    public var truncates = false
    public var maximumFractionDigits = 2
    public var showsAbsoluteValue = false
    public var currencySymbol = ""
    public var localeIdentifier: String?
    public var usesGroupingSeparator = true
    func build() -> CartesianValueFormat {
        var f = CartesianValueFormat()
        f.scale = engineeringScale ? .engineering : .none
        f.rounding = truncates ? .towardZero : .nearest
        f.maximumFractionDigits = maximumFractionDigits
        f.showsAbsoluteValue = showsAbsoluteValue
        f.currencySymbol = currencySymbol
        f.localeIdentifier = localeIdentifier
        f.usesGroupingSeparator = usesGroupingSeparator
        return f
    }
}

/// OC 缺测策略；系列 gapPolicy 为 nil 时沿用 connectNulls。
@objc public enum HYMCartesianGapMode: Int { case breakAll, connectAll, autoGap, autoGapDuration }

/// 配置时复制为 Swift 值；之后修改此对象须重新 configure/update。
@objcMembers public final class HYMCartesianGapPolicy: NSObject {
    public var mode: HYMCartesianGapMode = .autoGap
    public var maximumMissingPoints = 11
    public var maximumMissingDuration: TimeInterval = 3300
    func build() -> CartesianGapPolicy {
        switch mode {
        case .breakAll: return .breakAll
        case .connectAll: return .connectAll
        case .autoGap: return .autoGap(maximumMissingPoints: maximumMissingPoints)
        case .autoGapDuration: return .autoGapDuration(maximumMissingDuration: maximumMissingDuration)
        }
    }
}

/// 逻辑分区轴，不随 Bar 水平镜像交换；X 是原始采样索引，Y 由图形族和取值配置决定。
@objc public enum HYMCartesianZoneAxis: Int { case x, y }

/// 柱/条 Y 分区取值；原值在聚合时为桶统计值，绘制值为累计/百分比终点。线族忽略。
@objc public enum HYMCartesianColumnZoneValueSource: Int { case rawValue, drawValue }

/// 半开区间的颜色/面积填充；upperBound 为 nil 时无上限且必须为末段。柱/条忽略面积渐变。
@objcMembers public final class HYMCartesianColorZone: NSObject {
    public var upperBound: NSNumber?
    public var color: UIColor?
    public var areaGradientColors: [UIColor]?
    func build() -> CartesianColorZone {
        .init(upperBound: upperBound?.doubleValue, color: color, areaGradientColors: areaGradientColors)
    }
}

/// 逐系列分区配置；非法边界整份回退旧行为。configure/update 时复制为 Swift 值。
@objcMembers public final class HYMCartesianColorZones: NSObject {
    public var axis: HYMCartesianZoneAxis = .y
    public var zones: [HYMCartesianColorZone] = []
    public var columnValueSource: HYMCartesianColumnZoneValueSource = .rawValue
    public var isValid: Bool { build().isValid }
    func build() -> CartesianColorZones {
        .init(axis: axis == .x ? .x : .y, zones: zones.map { $0.build() },
              columnValueSource: columnValueSource == .rawValue ? .rawValue : .drawValue)
    }
}

/// NSNumber、数值字符串及 NSNull 数组；非法值保留索引并转为缺测，不转成 0。
@objcMembers public final class HYMCartesianSeries: NSObject {
    public var identifier = UUID().uuidString
    public var name = ""
    public var data: [Any] = []
    public var color: UIColor?
    public var unit: String?
    public var groupID: String?
    public var valueFormat: HYMCartesianValueFormat?
    public var kind: HYMCartesianSeriesKind = .automatic
    public var stackID: String?
    public var participatesInStack = true
    public var style: HYMCartesianSeriesStyle?
    public var marker: HYMCartesianMarker = .inherit
    public var connectNulls = false
    public var gapPolicy: HYMCartesianGapPolicy?
    public var colorZones: HYMCartesianColorZones?
    public var isVisible = true
    public var showsInLegend = true
    public var yAxisIndex = 0
    func build() -> CartesianSeriesElement {
        let numbers = data.map { item -> Double in
            let number: Double?
            if let n = item as? NSNumber { number = n.doubleValue }
            else if let s = item as? String { number = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
            else { number = nil }
            return number.flatMap { $0.isFinite ? $0 : nil } ?? .nan
        }
        return .init(name: name, data: numbers, color: color, yAxisIndex: yAxisIndex,
            connectNulls: connectNulls, pointSymbol: [nil, .circle, .square, .diamond, .triangle, .triangleDown][marker.rawValue],
            id: identifier, isVisible: isVisible, showsInLegend: showsInLegend,
            unit: unit, groupID: groupID, valueFormat: valueFormat?.build(),
            kind: [nil, .column, .line, .spline, .area, .areaspline][kind.rawValue],
            stackID: stackID, participatesInStack: participatesInStack, style: style?.build() ?? .init(),
            gapPolicy: gapPolicy?.build(), colorZones: colorZones?.build())
    }
}

/// 业务展示组，不表示堆叠组。
@objcMembers public final class HYMCartesianGroup: NSObject {
    public var identifier = UUID().uuidString
    public var name = ""
}

/// 第一阶段 OC 模型；支持类目、多系列、主次轴范围与现有堆叠模式。
/// 值对象；build 时快照，修改后请调用 update。
@objcMembers public final class HYMCartesianAxisStyle: NSObject {
    public var labelColor: UIColor?
    public var labelFont: UIFont?
    public var lineColor: UIColor?
    public var lineWidth: NSNumber?
    public var showsLabels = true
    public var showsLine = true
    func build() -> CartesianAxisStyle {
        .init(labelColor: labelColor, labelFont: labelFont, lineColor: lineColor,
              lineWidth: lineWidth.map { CGFloat($0.doubleValue) },
              showsLabels: showsLabels, showsLine: showsLine)
    }
}

@objcMembers public final class HYMCartesianModel: NSObject {
    public var title: String?
    public var categories: [String] = []
    /// 非 nil 时启用等间隔时间轴；缺测必须保留 NSNull 占位。
    public var samplingStart: Date?
    public var samplingInterval: TimeInterval = 300
    public var series: [HYMCartesianSeries] = []
    public var groups: [HYMCartesianGroup] = []
    public var plotLines: [HYMCartesianPlotLine] = []
    public var plotBands: [HYMCartesianPlotBand] = []
    public var stacking: HYMCartesianStacking = .none
    public var stackGroupCount: Int = 2
    public var percentageBase: Double = 100
    public var minimum: NSNumber?
    public var maximum: NSNumber?
    public var xAxisStyle = HYMCartesianAxisStyle()
    public var yAxisStyle = HYMCartesianAxisStyle()
    public var secondaryYAxisStyle = HYMCartesianAxisStyle()
    public var categoryLabelInterval: NSNumber?
    public var categoryLabelRotation: CGFloat = 0
    public var categoryGridlines: NSNumber?
    public var valueGridlines: NSNumber?
    public var secondaryGridlines: NSNumber?
    public var usesSecondaryAxis = false
    public var secondaryMinimum: NSNumber?
    public var secondaryMaximum: NSNumber?
    func build() -> CartesianChartModel {
        let stack: StackConfig
        switch stacking {
        case .none: stack = .none
        case .normal: stack = .normal
        case .percent: stack = .percent
        case .percentFixed: stack = .percentFixed(max: percentageBase)
        case .grouped: stack = .grouped(groupCount: stackGroupCount)
        }
        return .init(title: title, series: series.map { $0.build() },
            xAxis: .init(kind: .category(labels: categories), showsGridlines: categoryGridlines?.boolValue,
                         tickLabelRotation: categoryLabelRotation, style: xAxisStyle.build(),
                         categoryLabelInterval: categoryLabelInterval?.intValue),
            yAxis: .init(kind: .value, min: minimum?.doubleValue, max: maximum?.doubleValue,
                         showsGridlines: valueGridlines?.boolValue, style: yAxisStyle.build()),
            secondaryYAxis: usesSecondaryAxis ? .init(kind: .value, min: secondaryMinimum?.doubleValue,
                max: secondaryMaximum?.doubleValue, showsGridlines: secondaryGridlines?.boolValue,
                style: secondaryYAxisStyle.build()) : nil,
            stacking: stack, plotLines: plotLines.map { $0.build() }, plotBands: plotBands.map { $0.build() },
            timeAxis: samplingStart.map { CartesianTimeAxis(start: $0, interval: samplingInterval) },
            groups: groups.map { .init(id: $0.identifier, name: $0.name) })
    }
}

/// OC 回调快照。rawValue=nil 表示聚合项；sourceRange 始终指向原始数组。
@objcMembers public final class HYMCartesianDatum: NSObject {
    public let seriesID: String
    public let seriesIndex: Int
    public let categoryIndex: Int
    public let name: String
    public let stackID: String?
    public let groupID: String?
    public let groupName: String?
    public let unit: String?
    public let yAxisIndex: Int
    public let rawValue: NSNumber?
    public let aggregatedValue: NSNumber?
    public let drawValue: Double
    public let stackBase: Double
    public let percentage: NSNumber?
    public let sourceRange: NSRange
    public let displayValue: Double
    public let formattedValue: String
    init(_ data: CartesianDatum) {
        seriesID = data.seriesID; seriesIndex = data.seriesIndex; categoryIndex = data.categoryIndex
        name = data.name; stackID = data.stackID; groupID = data.groupID; groupName = data.groupName
        unit = data.unit; yAxisIndex = data.yAxisIndex
        rawValue = data.rawValue.map { NSNumber(value: $0) }
        aggregatedValue = data.aggregatedValue.map { NSNumber(value: $0) }
        drawValue = data.drawValue; stackBase = data.stackBase
        percentage = data.percentage.map { NSNumber(value: $0) }
        sourceRange = NSRange(location: data.sourceRange.lowerBound, length: data.sourceRange.count)
        displayValue = data.displayValue; formattedValue = data.formattedValue
    }
}
