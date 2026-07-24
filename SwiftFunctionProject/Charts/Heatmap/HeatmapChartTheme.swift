import UIKit

/// 热力图水平对齐方式。
public enum HeatmapHorizontalAlignment {
    case leading, center, trailing
}

/// 热力图色阶映射模式。
public enum HeatmapColorScale {
    /// 不映射（统一透明；适合每格自带 color）。
    case none
    /// 两点线性：归一化 t∈[0,1]，low → high。
    case gradient(low: UIColor, high: UIColor)
    /// 多段：按 value（原始值）升序的 (value, color) 锚点，首尾 value 作归一化基准，相邻段线性插值。
    case stops([(value: Double, color: UIColor)])
    /// 单色 + 透明度按 t（0→1）变化：t=0 全透明，t=1 全不透明。
    /// 适合「值越大越实色」；t = value/值域上界。Model 默认值域为 0...数据max（下界为 0），
    /// 故 value=0 全透明、value=max 全不透明。
    case alpha(UIColor)

    /// 取归一化比值 t∈[0,1]（越界裁剪）对应的颜色（纯函数）。
    public func color(at normalizedT: CGFloat) -> UIColor {
        let t = max(0, min(1, normalizedT))
        switch self {
        case .none:
            return .clear
        case .gradient(let low, let high):
            return HYMColorInterpolation.lerp(low, high, t)
        case .stops(let pairs):
            return HeatmapColorScale.lerpStops(pairs, t: t)
        case .alpha(let c):
            return c.withAlphaComponent(t)
        }
    }

    /// 多段插值（纯函数，便于自检）。stops 须按 value 升序。
    static func lerpStops(_ stops: [(value: Double, color: UIColor)], t: CGFloat) -> UIColor {
        guard let first = stops.first, let last = stops.last else { return .clear }
        guard last.value > first.value else { return last.color }
        let value = first.value + Double(t) * (last.value - first.value)
        if value <= first.value { return first.color }
        if value >= last.value { return last.color }
        for i in 1..<stops.count {
            let prev = stops[i - 1]
            let cur = stops[i]
            if value <= cur.value {
                let span = cur.value - prev.value
                let localT = span > 0 ? (value - prev.value) / span : 0
                return HYMColorInterpolation.lerp(prev.color, cur.color, CGFloat(localT))
            }
        }
        return last.color
    }
}

/// 热力图主题（纯值类型；所有外观集中于此，改色只动这里）。
public struct HeatmapChartTheme: HYMChartTheme {
    public var colorScale: HeatmapColorScale
    /// 空数据格子底色（value 落在值域下界以下时也用它）。
    public var emptyColor: UIColor
    /// `.none` 色阶时的统一填充色。
    public var baseColor: UIColor
    /// 格子圆角半径。
    public var cellCornerRadius: CGFloat
    /// 行间距（垂直，格子之间）；最小 0。
    public var rowSpacing: CGFloat
    /// 列间距（水平，格子之间）；最小 0。
    public var columnSpacing: CGFloat
    /// 内容相对可用区域的外边距。
    public var contentInset: CGFloat
    /// 格子整体在可用宽度内的水平对齐。
    public var horizontalAlignment: HeatmapHorizontalAlignment
    /// 背景（nil 透明）。
    public var backgroundColor: UIColor?
    /// 背景圆角。
    public var backgroundCornerRadius: CGFloat
    /// 行/列标签颜色与字体。
    public var labelColor: UIColor
    public var labelFont: UIFont
    /// 标签与格子的间距。
    public var labelGap: CGFloat
    /// 是否显示行标签（左侧）；false 时完全不渲染且不占空间。
    public var showsRowLabels: Bool
    /// 是否显示列标签（顶部）；false 时完全不渲染且不占空间。
    public var showsColumnLabels: Bool
    /// 是否参与入场动画（整体 opacity 淡入）。
    public var showsEntranceAnimation: Bool
    // —— 选中态边框（点击格子）——
    public var selectionBorderColor: UIColor?         // 选中格子边框色；nil = 无边框
    public var selectionBorderWidth: CGFloat          // 边框宽度
    public var selectionBorderCornerRadius: CGFloat?  // 边框圆角；nil = 同 cellCornerRadius

    /// 点击有效格子是否弹出默认 tooltip（默认 true）。
    /// false 时 Renderer 不提供锚点 → 不弹窗。
    public var showsTooltipOnHit: Bool

    public init(
        colorScale: HeatmapColorScale = .gradient(
            low: UIColor(red: 0x9b/255.0, green: 0xe9/255.0, blue: 0xa8/255.0, alpha: 1),
            high: UIColor(red: 0x21/255.0, green: 0x6e/255.0, blue: 0x39/255.0, alpha: 1)),
        emptyColor: UIColor = UIColor(red: 0xeb/255.0, green: 0xed/255.0, blue: 0xf0/255.0, alpha: 1),
        baseColor: UIColor = UIColor(red: 0x21/255.0, green: 0x6e/255.0, blue: 0x39/255.0, alpha: 1),
        cellCornerRadius: CGFloat = 2,
        rowSpacing: CGFloat = 3,
        columnSpacing: CGFloat = 3,
        contentInset: CGFloat = 0,
        horizontalAlignment: HeatmapHorizontalAlignment = .leading,
        backgroundColor: UIColor? = nil,
        backgroundCornerRadius: CGFloat = 0,
        labelColor: UIColor = UIColor(red: 0x58/255.0, green: 0x60/255.0, blue: 0x66/255.0, alpha: 1),
        labelFont: UIFont = .systemFont(ofSize: 10),
        labelGap: CGFloat = 6,
        showsRowLabels: Bool = true,
        showsColumnLabels: Bool = true,
        showsEntranceAnimation: Bool = true,
        selectionBorderColor: UIColor? = .black,
        selectionBorderWidth: CGFloat = 2,
        selectionBorderCornerRadius: CGFloat? = nil,
        showsTooltipOnHit: Bool = true
    ) {
        self.colorScale = colorScale
        self.emptyColor = emptyColor
        self.baseColor = baseColor
        self.cellCornerRadius = cellCornerRadius
        self.rowSpacing = max(0, rowSpacing)
        self.columnSpacing = max(0, columnSpacing)
        self.contentInset = contentInset
        self.horizontalAlignment = horizontalAlignment
        self.backgroundColor = backgroundColor
        self.backgroundCornerRadius = backgroundCornerRadius
        self.labelColor = labelColor
        self.labelFont = labelFont
        self.labelGap = labelGap
        self.showsRowLabels = showsRowLabels
        self.showsColumnLabels = showsColumnLabels
        self.showsEntranceAnimation = showsEntranceAnimation
        self.selectionBorderColor = selectionBorderColor
        self.selectionBorderWidth = selectionBorderWidth
        self.selectionBorderCornerRadius = selectionBorderCornerRadius
        self.showsTooltipOnHit = showsTooltipOnHit
    }
}
