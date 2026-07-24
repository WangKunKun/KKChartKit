import UIKit

/// OC 友好的热力图主题构造器：属性赋值 → build() 成纯 Swift struct。
/// 覆盖 HeatmapChartTheme 全部字段。颜色/字体可选（nil → 用主题默认）。
/// `colorScaleType`：none/gradient/stops；
///   gradient 用 colorScaleColors[0..1]；stops 用 colorScaleValues + colorScaleColors（等长）。
/// `horizontalAlignment`：leading/center/trailing。
@objcMembers
public final class HYMHeatmapThemeBuilder: NSObject {
    // —— 色阶 ——
    @objc public var colorScaleType: String = "gradient"
    @objc public var colorScaleColors: [UIColor] = []
    @objc public var colorScaleValues: [NSNumber] = []
    @objc public var emptyColor: UIColor?
    @objc public var baseColor: UIColor?

    // —— 几何 ——
    @objc public var cellCornerRadius: CGFloat = 2
    @objc public var rowSpacing: CGFloat = 3          // 行间距（最小 0）
    @objc public var columnSpacing: CGFloat = 3       // 列间距（最小 0）
    @objc public var contentInset: CGFloat = 0
    @objc public var horizontalAlignment: String = "leading"

    // —— 背景 ——
    @objc public var backgroundColor: UIColor?
    @objc public var backgroundCornerRadius: CGFloat = 0

    // —— 标签 ——
    @objc public var labelColor: UIColor?
    @objc public var labelFont: UIFont?
    @objc public var labelGap: CGFloat = 6
    @objc public var showsRowLabels: Bool = true
    @objc public var showsColumnLabels: Bool = true
    @objc public var showsEntranceAnimation: Bool = true

    // —— 选中态边框（点击格子）——
    @objc public var selectionBorderColor: UIColor? = .black
    @objc public var selectionBorderWidth: CGFloat = 2
    /// nil = 同 cellCornerRadius
    @objc public var selectionBorderCornerRadius: NSNumber?

    /// 点击格子是否弹默认 tooltip（默认 YES）。
    @objc public var showsTooltipOnHit: Bool = true

    @objc public override init() { super.init() }

    internal func build() -> HeatmapChartTheme {
        var t = HeatmapChartTheme()
        t.colorScale = buildColorScale(defaulting: t.colorScale)
        if let v = emptyColor { t.emptyColor = v }
        if let v = baseColor { t.baseColor = v }
        t.cellCornerRadius = cellCornerRadius
        t.rowSpacing = rowSpacing
        t.columnSpacing = columnSpacing
        t.contentInset = contentInset
        t.horizontalAlignment = buildAlignment()
        t.backgroundColor = backgroundColor
        t.backgroundCornerRadius = backgroundCornerRadius
        if let v = labelColor { t.labelColor = v }
        if let v = labelFont { t.labelFont = v }
        t.labelGap = labelGap
        t.showsRowLabels = showsRowLabels
        t.showsColumnLabels = showsColumnLabels
        t.showsEntranceAnimation = showsEntranceAnimation
        t.selectionBorderColor = selectionBorderColor
        t.selectionBorderWidth = selectionBorderWidth
        if let v = selectionBorderCornerRadius { t.selectionBorderCornerRadius = CGFloat(v.doubleValue) }
        t.showsTooltipOnHit = showsTooltipOnHit
        return t
    }

    private func buildColorScale(defaulting fallback: HeatmapColorScale) -> HeatmapColorScale {
        switch colorScaleType.lowercased() {
        case "none":
            return .none
        case "stops":
            guard colorScaleValues.count >= 2,
                  colorScaleColors.count == colorScaleValues.count else { return fallback }
            let pairs = zip(colorScaleValues, colorScaleColors)
                .map { (value: $0.doubleValue, color: $1) }
            return .stops(pairs)
        case "gradient", "":
            if colorScaleColors.count >= 2 {
                return .gradient(low: colorScaleColors[0], high: colorScaleColors[1])
            }
            return fallback
        case "alpha":
            if let c = colorScaleColors.first { return .alpha(c) }
            return fallback
        default:
            return fallback
        }
    }

    private func buildAlignment() -> HeatmapHorizontalAlignment {
        switch horizontalAlignment.lowercased() {
        case "center":   return .center
        case "trailing": return .trailing
        default:         return .leading
        }
    }
}
