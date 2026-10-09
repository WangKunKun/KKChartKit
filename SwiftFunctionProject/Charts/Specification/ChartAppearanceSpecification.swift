import Foundation

/// sRGB 分量（0...1）；不依赖 UIColor、十六进制字符串或 JS rgba 表达式。
public struct ChartRGBA: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    /// 保留输入；非法分量由 validate() 报错，不静默钳制。
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
}

/// 面积填充的视觉意图；gradient 是屏幕顶部到底部，颜色透明度只计算一次。
public enum ChartAreaFill: Codable, Equatable, Sendable {
    case solid(ChartRGBA)
    case verticalGradient(top: ChartRGBA, bottom: ChartRGBA)
}

/// 基础线条外观；具体像素节奏由引擎适配，不承诺不同库逐像素一致。
public enum ChartStrokePattern: String, Codable, Sendable { case solid, dashed, dotted }

/// nil 使用引擎默认；none 显式隐藏。图片 marker 留待独立资源协议支持。
public enum ChartMarkerShape: String, Codable, Sendable { case none, circle, square, diamond, triangle }

/// 仅包含系列绘制意图，尺寸使用逻辑点。nil 表示接受目标引擎默认外观。
public struct ChartSeriesAppearance: Codable, Equatable, Sendable {
    public var color: ChartRGBA?
    public var negativeColor: ChartRGBA?
    /// 值轴阈值配色（schema v3）；nil 保留原有负值配色和默认外观。
    public var valueColorZones: ChartValueColorZones?
    public var lineWidth: Double?
    public var strokePattern: ChartStrokePattern = .solid
    public var marker: ChartMarkerShape?
    public var markerRadius: Double?
    public var areaFill: ChartAreaFill?
    public var showsValueLabels: Bool = false
    /// 创建继承目标引擎默认外观的配置；随后按需设置显式覆盖。
    public init() {}
}

/// 轴的基本视觉意图；网格与轴线/标签显隐独立。
public struct ChartAxisAppearance: Codable, Equatable, Sendable {
    public var labelColor: ChartRGBA?
    public var labelFontSize: Double?
    /// schema v4；nil 沿用原有系统常规字重。未指定字号时采用目标引擎默认字号。
    public var labelFontWeight: ChartFontWeight?
    public var lineColor: ChartRGBA?
    public var lineWidth: Double?
    public var showsLabels = true
    public var showsLine = true
    public var showsGridlines = false
    /// 默认显示轴线和标签，不显示网格。
    public init() {}
}

/// 值轴采用稳定 ID；上下界可分别自动，不强制业务输入数组下标。
public struct ChartAxisSpecification: Codable, Equatable, Sendable {
    public var id: String
    public var minimum: Double?
    public var maximum: Double?
    public var isReversed: Bool
    /// schema v4：有限、严格递增的逻辑值坐标；nil 自动，[] 不画刻度/对应网格。
    /// 域外刻度过滤，不扩大值域；百分比模式的刻度单位为百分数。
    public var tickPositions: [Double]?
    /// schema v4；nil 沿用引擎原有刻度格式。只改文字，不改数学单位。
    public var labelFormat: ChartAxisLabelFormat?
    public var appearance: ChartAxisAppearance
    /// 显式上下界须有限且 minimum < maximum；反向是独立语义，不交换 min/max。
    public init(id: String, minimum: Double? = nil, maximum: Double? = nil,
                isReversed: Bool = false, appearance: ChartAxisAppearance = .init(),
                tickPositions: [Double]? = nil, labelFormat: ChartAxisLabelFormat? = nil) {
        self.id = id; self.minimum = minimum; self.maximum = maximum
        self.isReversed = isReversed; self.appearance = appearance
        self.tickPositions = tickPositions; self.labelFormat = labelFormat
    }
}

/// 数字展示不改变原值。单位是系列属性；金额符号不是数学单位。
public struct ChartValuePresentation: Codable, Equatable, Sendable {
    /// engineering 使用 k/M/G；禁止把旧模型的 fractionDigits=100 原样传入。
    public enum Scale: String, Codable, Sendable { case none, engineering }
    /// towardZero 为截断；nearest 为四舍五入。
    public enum Rounding: String, Codable, Sendable { case nearest, towardZero }
    public var scale: Scale = .none
    public var rounding: Rounding = .nearest
    public var maximumFractionDigits = 2
    public var showsAbsoluteValue = false
    public var currencySymbol = ""
    public var localeIdentifier: String?
    public var usesGroupingSeparator = true
    /// 默认最多两位小数，保留符号，不自动工程进位。
    public init() {}
}
