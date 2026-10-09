import Foundation
import CoreGraphics

/// 交互手势类型（预留扩展）
public enum HYMChartGesture {
    case tap
    /// 拖拽（全量视口下的"滑动选中"：手指划过逐个高亮数据点）
    case drag
    // 预留扩展：longPress 等
}

/// 图表中一个可命中的语义单元（关联数据，非绘图细节）
public protocol HYMChartHitTarget {
    /// 业务标识，如 "进攻"
    var identifier: String { get }
    /// 序号
    var index: Int { get }
    /// 通用类别槽位（如 "dataVertex"/"labelVertex"）；默认 "" 表示不分类。
    /// 具体类别值由各图表特有 HitTarget 定义，不污染本通用协议。
    var kind: String { get }
    /// 弹窗显示文本（数据驱动）；默认 nil = 不显示弹窗。
    /// 具体图表的 `XXXHitTarget` 按需覆盖（从自身数据派生）。
    var tooltipText: String? { get }
}

public extension HYMChartHitTarget {
    /// 默认不分类
    var kind: String { "" }
    /// 默认不显示弹窗
    var tooltipText: String? { nil }
}

// MARK: - 弹窗结构化数据源 + 文本模板

/// 命中目标可选实现：为「弹窗文本模板」（`HYMChartTooltipTextOptions`）提供结构化数据。
/// 未实现或模板未配置时，内置弹窗回落到 `tooltipText` 固定格式。
/// （不约束 AnyObject：各图表 HitTarget 均为 struct。）
public protocol HYMChartTooltipDataSource {
    /// 聚合区间等不可被普通数值模板省略的上下文。
    var tooltipContextText: String? { get }
    /// 弹窗数据行（系列名 + 值 + 是否次轴）
    var tooltipRows: [(name: String, value: Double, isSecondaryAxis: Bool)] { get }
    /// 表头键（类目标签等；nil = 无表头可代入 `{key}`，配置了表头也不拼该行）
    var tooltipHeaderKey: String? { get }
}

/// 内置弹窗文本模板（AAChartKit/Highcharts headerFormat/valueSuffix/valueDecimals 同款）。
/// 在 `HYMChartView.tooltipTextOptions` 上配置；命中目标实现 `HYMChartTooltipDataSource`
/// 才生效，否则回落各 target 的 `tooltipText` 固定格式。
public struct HYMChartTooltipTextOptions: Equatable {
    /// 表头行模板：`{key}` 占位类目标签（如 "{key} 元" → "3月 元"）。nil = 不加表头行。
    public var header: String?
    /// 数值后缀（如 " 万元"、"%"）；nil = 无后缀。
    public var valueSuffix: String?
    /// 数值固定小数位数；nil = 自动（整数无小数、非整数最多 2 位去尾零）。
    public var valueDecimals: Int?
    /// 仅轴系命中使用；默认保留平铺提示及所有数据行。
    public var cartesian: CartesianTooltipOptions

    public init(header: String? = nil,
                valueSuffix: String? = nil,
                valueDecimals: Int? = nil,
                cartesian: CartesianTooltipOptions = .init()) {
        self.header = header
        self.valueSuffix = valueSuffix
        self.valueDecimals = valueDecimals
        self.cartesian = cartesian
    }

    /// 通用文本模板是否默认；轴系业务分组在格式化入口独立应用。
    public var isDefault: Bool { header == nil && valueSuffix == nil && valueDecimals == nil }

    /// 按模板格式化数值：decimals 固定位数；nil 自动（同数据标签默认：整型不带小数、非整型两位去尾零）
    public static func formatValue(_ value: Double, decimals: Int?) -> String {
        if let d = decimals { return String(format: "%.\(d)f", value) }
        return CartesianDataLabelGeometry.labelText(value)
    }
}

/// 一次命中 + 其在 chartView 内的几何位置（供外部自定义弹窗定位）。
///
/// 位置不进 `HYMChartHitTarget`（保持其"数据，非绘图细节"语义），单独放在此 context。
/// `frame` 与 `location` 均为 chartView 坐标系；外部按需用 `convertRect:fromView:` 等转换。
public struct HYMChartHitContext {
    /// 命中的语义单元（含 identifier/index 及具体图表的 row/column 等）。
    public let target: any HYMChartHitTarget
    /// 命中单元在 chartView 坐标系的 frame。
    public let frame: CGRect
    /// 触发点在 chartView 坐标系的位置。
    public let location: CGPoint
    public init(target: any HYMChartHitTarget, frame: CGRect, location: CGPoint) {
        self.target = target
        self.frame = frame
        self.location = location
    }
}

public extension HYMChartTooltipDataSource {
    var tooltipContextText: String? { nil }
}
