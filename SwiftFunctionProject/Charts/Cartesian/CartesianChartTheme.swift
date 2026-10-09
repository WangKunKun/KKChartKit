import UIKit

/// 折线连接形态（数据点之间的绘制方式）。
///
/// 单枚举设计：一条线只有一种连接形态，互斥天然成立（无 smooth+step 组合歧义）；
/// 曲线细分参数将来用关联值扩展（如 `case smooth(tension: CGFloat)`）。
///
/// - straight: 直线连接（默认）
/// - smooth: 单调 Hermite 曲线，抑制区间内过冲
/// - stepCenter: 阶梯垂直段在两点水平中点（类似 ECharts step:'middle'）
/// - stepAfter: 先保持前值水平前进，到下一 x 再垂直跳变（step:'end'，监控图常用）
/// - stepBefore: 先垂直跳变到新值，再水平前进（step:'start'）
public enum LineConnectionStyle: String, CaseIterable, Equatable {
    case straight = "直线"
    case smooth = "平滑曲线"
    case stepCenter = "居中阶梯"
    case stepAfter = "后置阶梯"
    case stepBefore = "前置阶梯"
}

/// 堆叠面积的采样点之间如何插值；原始数值、堆叠计算和命中位置不变。
public enum StackedAreaBoundaryMode: String, CaseIterable, Equatable {
    /// 累计值独立插值，保留原有外观；薄层可能穿过下层边界。
    case independent = "独立插值（兼容）"
    /// 同符号且有共同基线的区间，插值自身厚度后叠加到基线上。
    /// 上边界会继承下层的曲线/阶梯形态；正负基线均可确定时，在自身厚度过零点分片闭合，
    /// 描边不跨接不同符号基线，原始零值仍属于正链。
    /// 描边按 lineWidth 向各自面积内绘制，收住交界与端点；零面积处不显示描边，marker 仍独立绘制。
    /// 已解析的前层跨零片保留正/负连续表面，上层可在这些片之间切换基线。
    /// 上层连接跨越下层缺测时保留两侧实际轮廓，仅在无法共享底边的缺口直连正/负基准；
    /// 上层自身厚度叠加到该过渡上，下层仍断开，不补业务样本；缺口不承诺全域无重叠。
    /// 自动百分比先插值各采样份额，再用同链份额绝对值总和共同归一化；正负总跨度为 100%，
    /// 混合线型共同调整，共享三次曲线的几何误差目标为每条边界 0.05 pt。
    /// 同链须全部为沿基线面积、缺测分段一致且分母非零；超过精度/细分上限也整链兼容回退。
    /// 普通、序号分组与固定基准百分比仍使用精确路径相加。
    case followBaseline = "沿基线叠加"
    /// 正负渲染链共享切分和边界；先插值自身贡献，再在实际过零位置分片。
    /// 同一数学堆叠组（值轴/stackID/类型族/序号分组）统一断段：任一参与系列缺测或短尾即断，
    /// 优先于 connectNulls/gapPolicy；有效原始点的 marker、命中和业务数据不变。
    /// 非面积折线也参与共同基线；各系列可保留不同线型。隐藏/不参与堆叠系列不影响组内断段。
    /// 自动百分比先插值原始贡献再共同归一化；零分母采样断开。
    /// 曲线精度/预算不足时整组改用共同归一化端点的共享直线，绝不回退独立边界。
    /// 自动值域包含区间贡献的保守包络，避免混合阶梯的采样间峰值被裁掉；显式轴界限仍优先。
    /// 查看 LineChartRenderer.divergingLinearFallbackSeries 可获知最近绘制的降级系列。
    case diverging = "正负分链（统一断段）"
}

/// 轴系图表主题（纯值类型；所有外观集中于此）。折线/柱状等共用，
/// 各类型特有外观（如柱宽）由该类型 Theme 扩展属性补充——阶段 1 起按需拆分。
public struct CartesianChartTheme: HYMChartTheme {
    /// 是否复用轴标签与绘制图层，默认开启；关闭可用于性能/视觉对照。
    /// 仅影响对象分配，不改变几何、命中或采样。通过主线程图表更新接口应用。
    public var reusesRenderingObjects: Bool = true
    public var legend = ChartLegendConfiguration()
    /// 非堆叠直线/面积图的 Min/Max 绘制降采样；nil 默认关闭，原始数据始终用于命中。
    public var lineSampling: LineChartSampling? = nil

    // —— 整体 ——
    /// 背景（nil 透明）。
    public var backgroundColor: UIColor?
    public var backgroundCornerRadius: CGFloat
    public var contentInset: UIEdgeInsets
    /// 标题颜色/字体（model.title 非 nil 时渲染）。
    public var titleColor: UIColor
    public var titleFont: UIFont

    // —— 网格 ——
    public var showsHorizontalGridlines: Bool
    public var showsVerticalGridlines: Bool
    public var gridColor: UIColor
    public var gridLineWidth: CGFloat

    // —— 轴 ——
    public var axisLineColor: UIColor
    public var axisLineWidth: CGFloat
    public var tickLabelColor: UIColor
    public var tickLabelFont: UIFont
    /// 刻度 label 与 plot 边缘间距。
    public var axisLabelGap: CGFloat

    // —— 系列（折线阶段 0 直接消费；多系列配色阶段 3 引入调色板）——
    /// series 未指定颜色时的默认色。
    public var seriesColor: UIColor
    public var lineWidth: CGFloat
    /// 折线阶梯样式（默认直线；仅折线图消费）。
    public var lineConnectionStyle: LineConnectionStyle
    /// 系列线条默认虚线样式（系列级 `lineDashStyle` 可覆盖；区分实际/预测数据用）
    public var lineDashStyle: LineDashStyle
    /// 是否绘制数据点圆点。
    public var showsPoints: Bool
    public var pointRadius: CGFloat
    public var pointColor: UIColor?
    /// 数据点默认标记符号（系列级 `pointSymbol` 可覆盖）
    public var pointSymbol: PointMarkerSymbol
    /// 数据点空心内径（0 = 实心；>0 = 空心环，Charts holeRadius 同款）。
    /// 会在 pointRadius 内 clamp，形状沿用各符号（圆环/方环/菱环…）。
    public var pointHoleRadius: CGFloat
    /// 空心内芯颜色（默认白，与描边呼应）
    public var pointHoleColor: UIColor

    // —— 面积填充（面积图形态；仅折线图消费）——
    /// 是否填充折线与零轴之间的区域（默认 false）。
    public var showsArea: Bool
    /// 仅影响堆叠面积（含混合图的面积系列）；默认保持已有外观。
    public var stackedAreaBoundaryMode: StackedAreaBoundaryMode = .independent
    /// 面积渐变色（自上而下，顶部靠近折线浓度高）。
    /// nil = 自动由各系列颜色派生：[系列色 35% 透明度 → 4% 透明度]。
    public var areaGradientColors: [UIColor]?

    // —— 数据标签（数值标注；Line/Column/Bar 共用，系列级 dataLabelsEnabled 可覆盖）——
    /// 是否在数据点/柱段端部标注数值（默认 false）。
    public var showsDataLabels: Bool
    /// 数据标签字号（默认 10）。
    public var dataLabelFontSize: CGFloat
    /// 数据标签颜色。nil = 自动：柱/条外与折线点旁用 `.label`（随深浅色自适应），
    /// 柱/条内（insideEnd/center 且被形状覆盖）用白色。
    public var dataLabelColor: UIColor?
    /// 可选标签底色（nil 透明）；数据标签和堆叠总量共用。
    public var dataLabelBackgroundColor: UIColor? = nil
    /// 默认 false 保持原有数量；开启时避开标注文字、总量优先，省略 plot 外与碰撞的数据标签。
    public var dataLabelAvoidsOverlap: Bool = false
    /// 数据标签位置（语义按图表形态映射，见 `CartesianDataLabelPosition`）。
    public var dataLabelPosition: CartesianDataLabelPosition
    /// 数值格式化（nil = 自动：整数不带小数、非整数最多 2 位去尾零）。
    public var dataLabelFormatter: ((Double) -> String)?
    /// 可见类目 × 系列总数超过该值时整图跳过标注（防大数据集糊屏 + 手势期 layer 风暴；
    /// 缩放后可见数变少会自动恢复显示）。默认 200。
    public var dataLabelMaxMarkCount: Int

    /// 默认关闭的图形主体选中反馈，独立于准线和弹窗。
    public var selection = CartesianSelectionStyle()

    // —— 行为 ——
    public var showsEntranceAnimation: Bool
    public var showsTooltipOnHit: Bool

    // ===== 柱体外观 =====
    /// 固定柱宽及组内/组间距（pt）；非 nil 时忽略三个比例，未指定柱宽时使用剩余空间。
    /// nil 保留旧比例布局。适用于 Column 与 Bar，堆叠仅使用组间距。
    public var columnSpacing: CartesianColumnSpacing? = nil
    /// 柱体宽度比例（0.1 ~ 1.0，默认 0.8 = 80% 宽度，20% 间距）
    public var columnWidthRatio: CGFloat
    /// 组间距：相邻类目组之间空隙占槽宽的比例（0...0.5；0 = 组占满槽位，现状）。
    public var columnGroupSpacingRatio: CGFloat
    /// 组内相邻柱间距占子槽宽的比例。nil = 自动 = 柱宽余量（1 - columnWidthRatio，现状）；
    /// 设值后组内间距独立可调，柱宽仍由 columnWidthRatio 决定（超槽自动 clamp）。
    public var columnInnerSpacingRatio: CGFloat?

    /// 最小柱高/条长（值轴方向，Highcharts minPointLength 同款）：非零小值在大量级下
    /// 完全不可见 → clamp 到该最小长度仍可点击可见；0 = 关闭。仅非堆叠生效
    /// （堆叠段须按累计值精确铺排，min 长会破坏层叠几何）。默认 0。
    public var columnMinPointLength: CGFloat
    /// 柱体圆角半径（默认 4）
    public var columnCornerRadius: CGFloat

    /// 柱体边框颜色（nil = 无边框）
    public var columnBorderColor: UIColor?

    /// 柱体边框宽度（默认 1）
    public var columnBorderWidth: CGFloat

    // ===== 堆叠样式 =====
    /// 堆叠柱体间的分隔线颜色（nil = 无分隔线）
    public var stackSeparatorColor: UIColor?

    /// 堆叠柱体间的分隔线宽度（默认 1）
    public var stackSeparatorWidth: CGFloat

    /// 堆叠总量标签（Highcharts stackLabels 同款）：堆叠模式下每类目在链端标注
    /// 该链**原值合计**（正链顶端、负链底端；百分比堆叠也标原值合计而非 100）。
    /// 非堆叠/全零链忽略；可见链端标签数（含双轴）超过 dataLabelMaxMarkCount 时跳过。
    /// 视口外链端不显示；边缘标签收敛到绘图区内，放不下的长文案跳过。默认 false。
    public var showsStackTotalLabels: Bool
    /// 总量标签数值格式化（nil = 与数据标签同款自动格式）
    public var stackTotalLabelFormatter: ((Double) -> String)?

    // ===== 系列阴影 =====
    /// 系列阴影默认样式（nil = 无阴影；系列级 `shadow` 可覆盖）。
    /// 作用于系列主体层：柱/条体、折线。建议浅偏移低透明度。
    public var seriesShadow: CartesianShadowStyle?

    // ===== 动画配置 =====
    /// 柱状图入场动画：柱体从零轴升起（默认 true）
    public var showsColumnEntranceAnimation: Bool

    public init(
        backgroundColor: UIColor? = nil,
        backgroundCornerRadius: CGFloat = 0,
        contentInset: UIEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
        titleColor: UIColor = UIColor(red: 0.23, green: 0.25, blue: 0.28, alpha: 1),
        titleFont: UIFont = .systemFont(ofSize: 14, weight: .semibold),
        showsHorizontalGridlines: Bool = true,
        showsVerticalGridlines: Bool = false,
        gridColor: UIColor = UIColor(white: 0.9, alpha: 1),
        gridLineWidth: CGFloat = 0.5,
        axisLineColor: UIColor = UIColor(white: 0.78, alpha: 1),
        axisLineWidth: CGFloat = 1,
        tickLabelColor: UIColor = UIColor(red: 0.35, green: 0.38, blue: 0.4, alpha: 1),
        tickLabelFont: UIFont = .systemFont(ofSize: 10),
        axisLabelGap: CGFloat = 4,
        seriesColor: UIColor = UIColor(red: 0x21/255.0, green: 0x6e/255.0, blue: 0x39/255.0, alpha: 1),
        lineWidth: CGFloat = 2,
        lineConnectionStyle: LineConnectionStyle = .straight,
        lineDashStyle: LineDashStyle = .solid,
        showsPoints: Bool = true,
        pointRadius: CGFloat = 3,
        pointColor: UIColor? = nil,
        pointSymbol: PointMarkerSymbol = .circle,
        pointHoleRadius: CGFloat = 0,
        pointHoleColor: UIColor = .white,
        showsArea: Bool = false,
        areaGradientColors: [UIColor]? = nil,
        showsDataLabels: Bool = false,
        dataLabelFontSize: CGFloat = 10,
        dataLabelColor: UIColor? = nil,
        dataLabelPosition: CartesianDataLabelPosition = .outsideEnd,
        dataLabelFormatter: ((Double) -> String)? = nil,
        dataLabelMaxMarkCount: Int = 200,
        showsEntranceAnimation: Bool = true,
        showsTooltipOnHit: Bool = true,
        columnWidthRatio: CGFloat = 0.8,
        columnGroupSpacingRatio: CGFloat = 0,
        columnInnerSpacingRatio: CGFloat? = nil,
        columnMinPointLength: CGFloat = 0,
        columnCornerRadius: CGFloat = 4,
        columnBorderColor: UIColor? = nil,
        columnBorderWidth: CGFloat = 1,
        stackSeparatorColor: UIColor? = nil,
        stackSeparatorWidth: CGFloat = 1,
        showsStackTotalLabels: Bool = false,
        stackTotalLabelFormatter: ((Double) -> String)? = nil,
        seriesShadow: CartesianShadowStyle? = nil,
        showsColumnEntranceAnimation: Bool = true,
        lineSampling: LineChartSampling? = nil,
        reusesRenderingObjects: Bool = true,
        columnSpacing: CartesianColumnSpacing? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.backgroundCornerRadius = max(0, backgroundCornerRadius)
        self.contentInset = contentInset
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.showsHorizontalGridlines = showsHorizontalGridlines
        self.showsVerticalGridlines = showsVerticalGridlines
        self.gridColor = gridColor
        self.gridLineWidth = max(0, gridLineWidth)
        self.axisLineColor = axisLineColor
        self.axisLineWidth = max(0, axisLineWidth)
        self.tickLabelColor = tickLabelColor
        self.tickLabelFont = tickLabelFont
        self.axisLabelGap = max(0, axisLabelGap)
        self.seriesColor = seriesColor
        self.lineWidth = max(0, lineWidth)
        self.lineConnectionStyle = lineConnectionStyle
        self.lineDashStyle = lineDashStyle
        self.showsPoints = showsPoints
        self.pointRadius = max(0, pointRadius)
        self.pointColor = pointColor
        self.pointSymbol = pointSymbol
        self.pointHoleRadius = max(0, pointHoleRadius)
        self.pointHoleColor = pointHoleColor
        self.showsArea = showsArea
        self.areaGradientColors = areaGradientColors
        self.showsDataLabels = showsDataLabels
        self.dataLabelFontSize = max(6, dataLabelFontSize)
        self.dataLabelColor = dataLabelColor
        self.dataLabelPosition = dataLabelPosition
        self.dataLabelFormatter = dataLabelFormatter
        self.dataLabelMaxMarkCount = max(0, dataLabelMaxMarkCount)
        self.showsEntranceAnimation = showsEntranceAnimation
        self.showsTooltipOnHit = showsTooltipOnHit
        self.columnWidthRatio = max(0.1, min(1.0, columnWidthRatio))
        self.columnGroupSpacingRatio = max(0, min(0.5, columnGroupSpacingRatio))
        self.columnInnerSpacingRatio = columnInnerSpacingRatio.map { max(0, min(0.5, $0)) }
        self.columnMinPointLength = max(0, columnMinPointLength)
        self.columnCornerRadius = max(0, columnCornerRadius)
        self.columnBorderColor = columnBorderColor
        self.columnBorderWidth = max(0, columnBorderWidth)
        self.stackSeparatorColor = stackSeparatorColor
        self.stackSeparatorWidth = max(0, stackSeparatorWidth)
        self.showsStackTotalLabels = showsStackTotalLabels
        self.stackTotalLabelFormatter = stackTotalLabelFormatter
        self.seriesShadow = seriesShadow
        self.showsColumnEntranceAnimation = showsColumnEntranceAnimation
        self.lineSampling = lineSampling
        self.reusesRenderingObjects = reusesRenderingObjects
        self.columnSpacing = columnSpacing
    }
}
