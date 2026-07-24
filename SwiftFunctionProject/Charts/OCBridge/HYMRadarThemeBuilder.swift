import UIKit

/// OC 友好的雷达主题构造器：属性赋值 → build() 成纯 Swift struct。
/// 覆盖 RadarChartTheme **全部**字段。颜色/字体为可选（nil → 用主题默认）；
/// `GridRingFill` 用 "none"/"gradient"/"colors" + gridRingColors；
/// `ChartLineStyle` 用 "solid"/"dashed"（虚线参数 lineDashLength/lineDashGap）。
@objcMembers
public final class HYMRadarThemeBuilder: NSObject {
    // —— 显隐开关 ——
    @objc public var showsData: Bool = true
    @objc public var showsGridLines: Bool = true
    @objc public var showsAxes: Bool = true
    @objc public var showsBackground: Bool = true
    @objc public var showsVertexDots: Bool = true
    @objc public var showsLabelDots: Bool = false
    @objc public var showsOuterRing: Bool = true
    @objc public var showsDecorativeRing: Bool = false

    // —— 颜色（nil → 用主题默认）——
    @objc public var backgroundGradientStart: UIColor?
    @objc public var backgroundGradientEnd: UIColor?
    @objc public var gridColor: UIColor?
    @objc public var axisColor: UIColor?
    @objc public var dataFillColor: UIColor?
    @objc public var dataStrokeColor: UIColor?
    @objc public var vertexDotColor: UIColor?
    @objc public var vertexDotRingColor: UIColor?
    @objc public var labelColor: UIColor?
    @objc public var scoreColor: UIColor?
    @objc public var labelDotColor: UIColor?
    @objc public var outerRingColor: UIColor?
    @objc public var decorativeRingColor: UIColor?
    @objc public var decorativeRingFillColor: UIColor?
    /// 装饰 ring 半径比例（相对 viewHalf，0~1）；nil = 顶点圈+gap+inset 旧行为
    @objc public var decorativeRingRadiusRatio: NSNumber?

    // —— 字体（nil → 用主题默认）——
    @objc public var labelFont: UIFont?
    @objc public var scoreFont: UIFont?

    // —— 几何 / 尺寸 ——
    @objc public var gridRingCount: Int = 5
    @objc public var cardCornerRadius: CGFloat = 16
    @objc public var dataLineWidth: CGFloat = 2
    @objc public var labelOuterPadding: CGFloat = 10
    /// 左右标签一行最大长度；<=0 = 不换行（单行）
    @objc public var labelMaxLineLength: CGFloat = 0
    @objc public var vertexDotRadius: CGFloat = 5
    @objc public var labelDotRadius: CGFloat = 4
    @objc public var outerRingLineWidth: CGFloat = 1.5
    @objc public var decorativeRingLineWidth: CGFloat = 1
    @objc public var decorativeRingInset: CGFloat = 0
    /// -1=跟随维度数；0=圆形；N=正N边形
    @objc public var decorativeRingSides: Int = -1

    // —— 选中态高亮（顶点点击）——
    @objc public var selectionScale: CGFloat = 1.5
    @objc public var selectionStrokeColor: UIColor? = .white
    @objc public var selectionStrokeWidth: CGFloat = 2
    @objc public var selectionColor: UIColor?
    @objc public var selectionHitPadding: CGFloat = 10
    @objc public var dataVertexTappable: Bool = true
    @objc public var labelVertexTappable: Bool = true

    // —— 网格底色 GridRingFill ——
    @objc public var gridRingFill: String = "none"
    @objc public var gridRingColors: [UIColor] = []

    // —— 线型 ChartLineStyle ——
    @objc public var gridLineStyle: String = "solid"
    @objc public var axisLineStyle: String = "solid"
    @objc public var outerRingLineStyle: String = "solid"
    @objc public var decorativeRingLineStyle: String = "solid"
    @objc public var lineDashLength: CGFloat = 4
    @objc public var lineDashGap: CGFloat = 3

    @objc public override init() { super.init() }

    /// 翻译为内部纯 Swift struct
    internal func build() -> RadarChartTheme {
        var t = RadarChartTheme()
        // 显隐
        t.showsData = showsData
        t.showsGridLines = showsGridLines
        t.showsAxes = showsAxes
        t.showsBackground = showsBackground
        t.showsVertexDots = showsVertexDots
        t.showsLabelDots = showsLabelDots
        t.showsOuterRing = showsOuterRing
        t.showsDecorativeRing = showsDecorativeRing
        // 颜色
        if let v = backgroundGradientStart { t.backgroundGradientStart = v }
        if let v = backgroundGradientEnd { t.backgroundGradientEnd = v }
        if let v = gridColor { t.gridColor = v }
        if let v = axisColor { t.axisColor = v }
        if let v = dataFillColor { t.dataFillColor = v }
        if let v = dataStrokeColor { t.dataStrokeColor = v }
        if let v = vertexDotColor { t.vertexDotColor = v }
        if let v = vertexDotRingColor { t.vertexDotRingColor = v }
        if let v = labelColor { t.labelColor = v }
        if let v = scoreColor { t.scoreColor = v }
        if let v = labelDotColor { t.labelDotColor = v }
        if let v = outerRingColor { t.outerRingColor = v }
        if let v = decorativeRingColor { t.decorativeRingColor = v }
        if let v = decorativeRingFillColor { t.decorativeRingFillColor = v }
        if let v = decorativeRingRadiusRatio { t.decorativeRingRadiusRatio = CGFloat(v.doubleValue) }
        // 字体
        if let v = labelFont { t.labelFont = v }
        if let v = scoreFont { t.scoreFont = v }
        // 尺寸
        t.gridRingCount = gridRingCount
        t.cardCornerRadius = cardCornerRadius
        t.dataLineWidth = dataLineWidth
        t.labelOuterPadding = labelOuterPadding
        t.labelMaxLineLength = labelMaxLineLength
        t.vertexDotRadius = vertexDotRadius
        t.labelDotRadius = labelDotRadius
        t.outerRingLineWidth = outerRingLineWidth
        t.decorativeRingLineWidth = decorativeRingLineWidth
        t.decorativeRingInset = decorativeRingInset
        t.decorativeRingSides = decorativeRingSides
        // 选中态
        t.selectionScale = selectionScale
        t.selectionStrokeColor = selectionStrokeColor
        t.selectionStrokeWidth = selectionStrokeWidth
        t.selectionColor = selectionColor
        t.selectionHitPadding = selectionHitPadding
        t.dataVertexTappable = dataVertexTappable
        t.labelVertexTappable = labelVertexTappable
        // 网格底色
        switch gridRingFill.lowercased() {
        case "gradient":
            if gridRingColors.count >= 2 { t.gridRingFill = .gradient(from: gridRingColors[0], to: gridRingColors[1]) }
        case "colors":
            if !gridRingColors.isEmpty { t.gridRingFill = .colors(gridRingColors) }
        default:
            t.gridRingFill = .none
        }
        // 线型
        let dash = ChartLineStyle.dashed(dashLength: lineDashLength, gap: lineDashGap)
        t.gridLineStyle = (gridLineStyle == "dashed") ? dash : .solid
        t.axisLineStyle = (axisLineStyle == "dashed") ? dash : .solid
        t.outerRingLineStyle = (outerRingLineStyle == "dashed") ? dash : .solid
        t.decorativeRingLineStyle = (decorativeRingLineStyle == "dashed") ? dash : .solid
        return t
    }
}
