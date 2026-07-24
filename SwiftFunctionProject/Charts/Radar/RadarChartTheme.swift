import UIKit

/// 网格每圈底色模式
public enum GridRingFill {
    /// 不填充（默认）
    case none
    /// 从最外圈(from)到最内圈(to)线性插值
    case gradient(from: UIColor, to: UIColor)
    /// 每圈独立色；数组长度 < gridRingCount 时，超出圈回退为最后一色
    case colors([UIColor])
}

/// 线型（实线 / 虚线）
public enum ChartLineStyle {
    case solid
    case dashed(dashLength: CGFloat = 4, gap: CGFloat = 3)

    /// 转为 CAShapeLayer.lineDashPattern；nil 表示实线
    public var dashPattern: [NSNumber]? {
        switch self {
        case .solid: return nil
        case .dashed(let dash, let gap): return [dash as NSNumber, gap as NSNumber]
        }
    }
}

/// 雷达图主题（纯值类型；所有外观集中于此，改色只动这里）
public struct RadarChartTheme: HYMChartTheme {
    public var backgroundGradientStart: UIColor
    public var backgroundGradientEnd:   UIColor
    public var gridColor:   UIColor
    public var axisColor:   UIColor
    public var dataFillColor:   UIColor
    public var dataStrokeColor: UIColor
    public var vertexDotColor:     UIColor
    public var vertexDotRingColor: UIColor
    public var labelColor: UIColor
    public var labelFont:  UIFont
    public var scoreColor: UIColor
    public var scoreFont:  UIFont
    public var gridRingCount: Int
    public var cardCornerRadius: CGFloat
    public var dataLineWidth: CGFloat
    public var labelOuterPadding: CGFloat
    /// 左右两侧（水平方向）标签一行最大长度；<=0 = 不换行（单行，向后兼容）。
    /// 上下（垂直方向）标签始终单行，不受此值影响。
    public var labelMaxLineLength: CGFloat
    public var vertexDotRadius: CGFloat
    public var gridRingFill: GridRingFill
    public var showsGridLines: Bool
    public var showsAxes: Bool
    public var showsData: Bool
    public var showsBackground: Bool
    // —— 样式扩展 ——
    public var showsVertexDots: Bool          // 数据点独立显隐（与 showsData 正交）
    public var showsLabelDots: Bool           // 标题顶点圆点显隐
    public var labelDotColor: UIColor
    public var labelDotRadius: CGFloat
    public var showsOuterRing: Bool           // 最外圈边框独立显隐
    public var outerRingColor: UIColor
    public var outerRingLineWidth: CGFloat
    public var outerRingLineStyle: ChartLineStyle  // 最外圈线型（独立于内圈网格）
    public var gridLineStyle: ChartLineStyle  // 内圈网格线型
    public var axisLineStyle: ChartLineStyle  // 放射线型
    // —— 装饰 ring（最外圈外）——
    public var showsDecorativeRing: Bool
    public var decorativeRingColor: UIColor
    public var decorativeRingLineWidth: CGFloat
    public var decorativeRingLineStyle: ChartLineStyle
    public var decorativeRingInset: CGFloat        // 距最外圈外的间距 pt
    public var decorativeRingSides: Int            // -1=跟随维度数；0=圆形；N=正N边形
    public var decorativeRingFillColor: UIColor?   // 装饰 ring 填充色（nil = 透明）
    /// 装饰 ring 半径比例（相对 viewHalf，0~1）；nil = 顶点圈 + labelOuterPadding + inset（旧行为）。
    /// 1.0 = 贴 view 边，0.7 = 70% viewHalf，可自由放大/缩小。
    public var decorativeRingRadiusRatio: CGFloat?
    // —— 选中态高亮（顶点点击）——
    public var selectionScale: CGFloat          // 选中放大倍数；1.0 = 不放大
    public var selectionStrokeColor: UIColor?   // 选中描边色；nil = 沿用原描边
    public var selectionStrokeWidth: CGFloat    // 描边线宽
    public var selectionColor: UIColor?         // 选中变色；nil = 用原色不变色
    public var selectionHitPadding: CGFloat     // 命中容差（pt）
    public var dataVertexTappable: Bool         // 数据顶点是否可点击（默认 true）
    public var labelVertexTappable: Bool        // 标题顶点是否可点击（默认 true）

    public init(
        backgroundGradientStart: UIColor = UIColor(red: 0x2A/255.0, green: 0x1B/255.0, blue: 0x5C/255.0, alpha: 1),
        backgroundGradientEnd:   UIColor = UIColor(red: 0x4B/255.0, green: 0x2E/255.0, blue: 0xAA/255.0, alpha: 1),
        gridColor:   UIColor = UIColor.white.withAlphaComponent(0.15),
        axisColor:   UIColor = UIColor.white.withAlphaComponent(0.25),
        dataFillColor:   UIColor = UIColor(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0, alpha: 0.35),
        dataStrokeColor: UIColor = UIColor(red: 0xA7/255.0, green: 0x8B/255.0, blue: 0xFA/255.0, alpha: 1),
        vertexDotColor:     UIColor = UIColor(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0, alpha: 1),
        vertexDotRingColor: UIColor = .white,
        labelColor: UIColor = UIColor(red: 0xE0/255.0, green: 0xE7/255.0, blue: 0xFF/255.0, alpha: 1),
        labelFont:  UIFont = .systemFont(ofSize: 14),
        scoreColor: UIColor = .white,
        scoreFont:  UIFont = .boldSystemFont(ofSize: 36),
        gridRingCount: Int = 5,
        cardCornerRadius: CGFloat = 16,
        dataLineWidth: CGFloat = 2,
        labelOuterPadding: CGFloat = 15,
        labelMaxLineLength: CGFloat = 0,
        vertexDotRadius: CGFloat = 5,
        gridRingFill: GridRingFill = .none,
        showsGridLines: Bool = true,
        showsAxes: Bool = true,
        showsData: Bool = true,
        showsBackground: Bool = true,
        showsVertexDots: Bool = true,
        showsLabelDots: Bool = false,
        labelDotColor: UIColor = .white,
        labelDotRadius: CGFloat = 4,
        showsOuterRing: Bool = true,
        outerRingColor: UIColor = UIColor.white.withAlphaComponent(0.15),
        outerRingLineWidth: CGFloat = 1.5,
        outerRingLineStyle: ChartLineStyle = .solid,
        gridLineStyle: ChartLineStyle = .solid,
        axisLineStyle: ChartLineStyle = .solid,
        showsDecorativeRing: Bool = false,
        decorativeRingColor: UIColor = UIColor.white.withAlphaComponent(0.3),
        decorativeRingLineWidth: CGFloat = 1,
        decorativeRingLineStyle: ChartLineStyle = .solid,
        decorativeRingInset: CGFloat = 0,
        decorativeRingSides: Int = -1,
        decorativeRingFillColor: UIColor? = nil,
        decorativeRingRadiusRatio: CGFloat? = nil,
        selectionScale: CGFloat = 1.5,
        selectionStrokeColor: UIColor? = .white,
        selectionStrokeWidth: CGFloat = 2,
        selectionColor: UIColor? = UIColor(red: 0xFF/255.0, green: 0xC1/255.0, blue: 0x07/255.0, alpha: 1),
        selectionHitPadding: CGFloat = 10,
        dataVertexTappable: Bool = true,
        labelVertexTappable: Bool = true
    ) {
        self.backgroundGradientStart = backgroundGradientStart
        self.backgroundGradientEnd = backgroundGradientEnd
        self.gridColor = gridColor
        self.axisColor = axisColor
        self.dataFillColor = dataFillColor
        self.dataStrokeColor = dataStrokeColor
        self.vertexDotColor = vertexDotColor
        self.vertexDotRingColor = vertexDotRingColor
        self.labelColor = labelColor
        self.labelFont = labelFont
        self.scoreColor = scoreColor
        self.scoreFont = scoreFont
        self.gridRingCount = gridRingCount
        self.cardCornerRadius = cardCornerRadius
        self.dataLineWidth = dataLineWidth
        self.labelOuterPadding = labelOuterPadding
        self.labelMaxLineLength = labelMaxLineLength
        self.vertexDotRadius = vertexDotRadius
        self.gridRingFill = gridRingFill
        self.showsGridLines = showsGridLines
        self.showsAxes = showsAxes
        self.showsData = showsData
        self.showsBackground = showsBackground
        self.showsVertexDots = showsVertexDots
        self.showsLabelDots = showsLabelDots
        self.labelDotColor = labelDotColor
        self.labelDotRadius = labelDotRadius
        self.showsOuterRing = showsOuterRing
        self.outerRingColor = outerRingColor
        self.outerRingLineWidth = outerRingLineWidth
        self.outerRingLineStyle = outerRingLineStyle
        self.gridLineStyle = gridLineStyle
        self.axisLineStyle = axisLineStyle
        self.showsDecorativeRing = showsDecorativeRing
        self.decorativeRingColor = decorativeRingColor
        self.decorativeRingLineWidth = decorativeRingLineWidth
        self.decorativeRingLineStyle = decorativeRingLineStyle
        self.decorativeRingInset = decorativeRingInset
        self.decorativeRingSides = decorativeRingSides
        self.decorativeRingFillColor = decorativeRingFillColor
        self.decorativeRingRadiusRatio = decorativeRingRadiusRatio
        self.selectionScale = selectionScale
        self.selectionStrokeColor = selectionStrokeColor
        self.selectionStrokeWidth = selectionStrokeWidth
        self.selectionColor = selectionColor
        self.selectionHitPadding = selectionHitPadding
        self.dataVertexTappable = dataVertexTappable
        self.labelVertexTappable = labelVertexTappable
    }
}
