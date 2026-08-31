import UIKit

/// 整列命中 target（shared tooltip）：某 X 类目下所有系列的数据组合。
public struct CartesianSharedHitTarget: HYMChartHitTarget {
    public struct Entry {
        /// 系列序号
        public let seriesIndex: Int
        public let name: String
        /// 该列的数据值（堆叠模式下为原始值，非累计）
        public let value: Double
        /// 是否绑右轴（弹窗标注用）
        public let isSecondaryAxis: Bool
    }

    /// 类目索引
    public let categoryIndex: Int
    /// 该类目下所有有值系列（锯齿数据集缺值系列被跳过）
    public let entries: [Entry]
    /// 十字线 x（view 坐标；锚点用）
    public let crosshairX: CGFloat
    /// 表头键（类目标签；弹窗文本模板 {key} 代入用，nil = 无）
    public let headerKey: String?

    public init(categoryIndex: Int, entries: [Entry], crosshairX: CGFloat,
                headerKey: String? = nil) {
        self.categoryIndex = categoryIndex
        self.entries = entries
        self.crosshairX = crosshairX
        self.headerKey = headerKey
    }

    // MARK: - HYMChartHitTarget
    public let kind = "sharedColumn"
    public var identifier: String { "sharedColumn:\(categoryIndex)" }
    public var index: Int { categoryIndex }
    public var tooltipText: String? {
        entries.map { entry in
            var text = "\(entry.name): \(AxisRenderer.format(entry.value))"
            if entry.isSecondaryAxis { text += " (右轴)" }
            return text
        }.joined(separator: "\n")
    }
}

extension CartesianSharedHitTarget: HYMChartTooltipDataSource {
    public var tooltipRows: [(name: String, value: Double, isSecondaryAxis: Bool)] {
        entries.map { ($0.name, $0.value, $0.isSecondaryAxis) }
    }
    public var tooltipHeaderKey: String? { headerKey }
}

/// 轴系图表渲染基类（模板方法）。
///
/// 统一编排：背景 → 值域(nice scale) → viewport → plot 布局 → 网格 → 轴 → 标题
/// → **子类 `drawSeries`**。轴/网格/标题/命中上下文全部由基类负责，
/// 子类（LineChartRenderer 等）只实现"把 series 画进 plot 区"与系列命中。
///
/// 泛型参数 `ChartTheme` 让阶段 1 起各类型可扩展自己的 Theme
/// （如 ColumnChartTheme 在 CartesianChartTheme 基础上加柱宽），阶段 0 直接用 CartesianChartTheme。
///
/// 遵循 `HYMChartXAxisZoomable`：所有轴系子类（Column/Bar/Line…）自动获得
/// X 轴视口缩放/平移能力（Y 轴视口始终数据驱动，不参与手势）。
open class CartesianRendererBase<ChartTheme: HYMChartTheme>: HYMChartRenderer, HYMChartXAxisZoomable, HYMChartYAxisZoomable {
    public typealias Model = CartesianChartModel
    public typealias Theme = ChartTheme

    public required init() {}

    // MARK: - 图表方向
    /// 值轴是否水平（条形图为 true）。决定轴系编排的方向分支：
    /// 水平图值域落 X（底部数值刻度、竖网格线）、类目域落 Y（左侧类目标签、横网格线）；
    /// 垂直图（Column/Line）相反。viewport 语义随之对调（见 `makeViewport`）。
    open var isHorizontalValueAxis: Bool { false }

    // MARK: - layer 子树
    /// 根容器（网格/轴线/series 挂其下；入场动画的 opacity 单元）。
    let rootLayer = CALayer()
    /// series 专用挂载层（frame = plot 区、masksToBounds）。
    ///
    /// 子类必须把数据系列画在这里而不是 `rootLayer`：
    /// 视口缩放/平移时部分可见的元素会被裁剪在 plot 区内，不溢出图表边界。
    let seriesLayer = CALayer()
    private let backgroundLayer = CALayer()
    private weak var hostView: UIView?
    private var titleLabels: [UILabel] = []
    private var tickLabels: [UILabel] = []

    // MARK: - 渲染期状态（供子类命中/动画读取）
    /// 当前生效的 viewport（render 时重算；x 域受手势视口影响，y 域始终数据驱动）。
    var currentViewport = CartesianViewport(xMin: 0, xMax: 1, yMin: 0, yMax: 1)
    /// 当前 plot 区（view 坐标系）。
    var currentPlotFrame: CGRect = .zero
    var currentModel: CartesianChartModel?
    var currentTheme: ChartTheme?
    var lastContext: HYMChartRenderContext?
    /// 当前值轴刻度（网格与值轴 label 同源；垂直图沿 Y 映射、水平图沿 X 映射）。
    var currentValueTicks: [Double] = []
    /// 次值轴（右）生效域；nil = 无次轴（单轴现状）。垂直图专用。
    var currentSecondaryYDomain: ClosedRange<Double>?
    /// 次值轴刻度（网格与右侧 label 同源）。
    var currentSecondaryValueTicks: [Double] = []

    // MARK: - X 轴视口状态（手势缩放/平移）
    /// 全量 X 域（render 时从 model 记录；手势窗口的 clamp 边界）。
    private(set) var fullXRange: ClosedRange<Double> = -0.5...0.5
    /// 用户手势设置的 X 窗口（nil = 全量）。外部 configure 会重置（见 `resetXAxisViewport`）。
    private var userXRange: ClosedRange<Double>?

    // MARK: - Y 轴视口状态（zoomAxisMode .y/.xy 启用；屏幕 Y 方向轴）
    /// 语义随方向映射：垂直图 = 值轴（刻度随缩放重算），水平图（Bar）= 类目轴。
    private(set) var fullYRange: ClosedRange<Double> = 0...1
    /// 用户手势设置的 Y 窗口（nil = 全量）。configure 会重置（见 `resetYAxisViewport`）。
    private var userYRange: ClosedRange<Double>?
    /// 次值轴（右）全量域与用户窗口（仅垂直图双轴；与主轴同手势、各自锚点换算）。
    private var fullSecondaryYRange: ClosedRange<Double>?
    private var userSecondaryYRange: ClosedRange<Double>?

    // MARK: - mount / unmount
    public func mount(into view: UIView) {
        hostView = view
        view.layer.addSublayer(backgroundLayer)
        view.layer.addSublayer(rootLayer)
    }

    public func unmount(from view: UIView) {
        titleLabels.forEach { $0.removeFromSuperview() }
        tickLabels.forEach { $0.removeFromSuperview() }
        titleLabels.removeAll()
        tickLabels.removeAll()
        rootLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        [backgroundLayer, rootLayer].forEach { $0.removeFromSuperlayer() }
        hostView = nil
    }

    // MARK: - 动画契约
    public var animatableLayers: [CALayer] { [rootLayer] }
    /// 入场动画逐帧：转发给子类（折线 strokeEnd 生长等）。
    public func updateEntranceAnimation(progress: Double) {
        updateSeriesAnimation(progress: progress)
    }
    /// 子类逐帧动画钩子（progress 0...1，已 ease）。
    open func updateSeriesAnimation(progress: Double) {}

    // MARK: - X 轴视口手势（HYMChartXAxisZoomable）
    /// 最大放大倍数。由容器 `HYMChartView.maximumZoomScale` 同步。
    public var maximumXAxisZoomScale: CGFloat = 10.0
    /// 最小可见类目数（放大下限）。由容器 `HYMChartView.minimumVisibleCategories` 同步。
    public var minimumXAxisCategories: Int = 12

    /// 放大下限对应的最小可视跨度：倍数上限与类目数上限**取更宽松者**（min）。
    ///
    /// 两个约束各管一段：小数据量按倍数防过度放大（4 点 × 10 倍），
    /// 大数据量按类目数保证放大到底能看清单柱（1440 点 → 一屏 12 柱）。
    /// （曾误用 max 导致倍数限制在大数据量下永远压制类目下限，下限失效。）
    /// 水平图 X 轴是数值轴：类目数下限无意义，仅按最大倍数约束。
    private var minimumXSpan: Double {
        let fullSpan = fullXRange.upperBound - fullXRange.lowerBound
        let byZoom = fullSpan / max(maximumXAxisZoomScale, 1)
        if isHorizontalValueAxis { return byZoom }
        return min(byZoom, Double(minimumXAxisCategories))
    }

    /// 当前 X 轴视口（值域）。
    public var xAxisViewport: ClosedRange<Double> { currentViewport.xDomain }

    /// 全量 X 域。
    public var fullXAxisDomain: ClosedRange<Double> { fullXRange }

    /// 当前 X 轴缩放倍率（全量跨度 / 当前跨度）。
    public var xAxisZoomScale: CGFloat {
        let full = fullXRange.upperBound - fullXRange.lowerBound
        let current = currentViewport.xSpan
        guard current > 0 else { return 1 }
        return CGFloat(full / current)
    }

    public func zoomXAxis(factor: CGFloat, anchorScreenX: CGFloat) {
        guard currentPlotFrame.width > 0 else { return }
        // 屏幕 x → 值域锚点（比例插值；锚点在 plot 外时由纯函数 clamp）
        let ratio = Double((anchorScreenX - currentPlotFrame.minX) / currentPlotFrame.width)
        let anchorValue = currentViewport.xMin + ratio * currentViewport.xSpan
        applyUserXRange(CartesianGeometry.zoomedXRange(
            from: currentViewport.xDomain,
            factor: factor,
            anchorValue: anchorValue,
            fullDomain: fullXRange,
            minSpan: minimumXSpan,
            maxSpan: fullXRange.upperBound - fullXRange.lowerBound))
    }

    public func panXAxis(screenDeltaX: CGFloat) {
        panXAxis(screenDeltaX: screenDeltaX, allowsRubberBand: false)
    }

    /// 橡皮筋平移：越界方向阻尼 + 允许拖出全量域至多 25% 跨度（松手由容器回弹）。
    public func panXAxis(screenDeltaX: CGFloat, allowsRubberBand: Bool) {
        let margin = allowsRubberBand
            ? (fullXRange.upperBound - fullXRange.lowerBound) * CartesianGeometry.rubberBandMarginRatio
            : 0
        applyUserXRange(CartesianGeometry.pannedXRange(
            from: currentViewport.xDomain,
            screenDeltaX: screenDeltaX,
            plotWidth: currentPlotFrame.width,
            fullDomain: fullXRange,
            overshootMargin: margin))
    }

    /// 直接设置 X 视口（回弹动画逐帧插值用）：钳制到全量域 ± 橡皮筋余量。
    public func setXAxisViewport(_ range: ClosedRange<Double>) {
        let margin = (fullXRange.upperBound - fullXRange.lowerBound) * CartesianGeometry.rubberBandMarginRatio
        let lo = min(max(range.lowerBound, fullXRange.lowerBound - margin), fullXRange.upperBound)
        let hi = max(min(range.upperBound, fullXRange.upperBound + margin), fullXRange.lowerBound)
        applyUserXRange(min(lo, hi)...max(lo, hi))
    }

    /// 当前视口是否越出全量域（橡皮筋拖拽中，松手须回弹）。
    public var isXAxisOvershooting: Bool {
        currentViewport.xMin < fullXRange.lowerBound - 1e-9
            || currentViewport.xMax > fullXRange.upperBound + 1e-9
    }

    public func resetXAxisViewport() {
        guard userXRange != nil else { return }
        userXRange = nil
        relayout()
    }

    /// 应用新的用户 X 窗口；被 clamp 到无变化（如未缩放时平移）则跳过重排。
    private func applyUserXRange(_ range: ClosedRange<Double>) {
        guard range != userXRange else { return }
        userXRange = range
        relayout()
    }

    // MARK: - Y 轴视口手势（HYMChartYAxisZoomable）
    /// 最大放大倍数（容器 `HYMChartView.maximumZoomScale` 同步）。
    public var maximumYAxisZoomScale: CGFloat = 10.0
    /// 最小可见类目数（仅水平图类目轴消费；容器 minimumVisibleCategories 同步）。
    public var minimumYAxisCategories: Int = 12

    /// 放大下限跨度：垂直图值轴只按最大倍数；水平图类目轴再叠加类目数下限（与 X 轴同理）。
    private var minimumYSpan: Double {
        let fullSpan = fullYRange.upperBound - fullYRange.lowerBound
        let byZoom = fullSpan / max(maximumYAxisZoomScale, 1)
        return isHorizontalValueAxis ? min(byZoom, Double(minimumYAxisCategories)) : byZoom
    }

    public var yAxisViewport: ClosedRange<Double> { currentViewport.yDomain }
    public var fullYAxisDomain: ClosedRange<Double> { fullYRange }

    public var yAxisZoomScale: CGFloat {
        let full = fullYRange.upperBound - fullYRange.lowerBound
        let current = currentViewport.ySpan
        guard current > 0 else { return 1 }
        return CGFloat(full / current)
    }

    public func zoomYAxis(factor: CGFloat, anchorScreenY: CGFloat) {
        guard currentPlotFrame.height > 0 else { return }
        // 屏幕 y → Y 域锚点。垂直图值轴向上、水平图类目轴向下——两个方向的比率相反。
        let t: Double
        if isHorizontalValueAxis {
            t = Double((anchorScreenY - currentPlotFrame.minY) / currentPlotFrame.height)
        } else {
            t = Double((currentPlotFrame.maxY - anchorScreenY) / currentPlotFrame.height)
        }
        let anchorValue = currentViewport.yMin + t * currentViewport.ySpan
        let newY = CartesianGeometry.zoomedXRange(
            from: currentViewport.yDomain,
            factor: factor,
            anchorValue: anchorValue,
            fullDomain: fullYRange,
            minSpan: minimumYSpan,
            maxSpan: fullYRange.upperBound - fullYRange.lowerBound)

        // 垂直图双轴：次值轴同倍率、以自身域换算锚点同步缩放（两轴刻度对齐关系保持）
        var newSec: ClosedRange<Double>?
        if let sec = currentSecondaryYDomain, let fullSec = fullSecondaryYRange {
            let anchorS = sec.lowerBound + t * (sec.upperBound - sec.lowerBound)
            newSec = CartesianGeometry.zoomedXRange(
                from: sec, factor: factor, anchorValue: anchorS,
                fullDomain: fullSec,
                minSpan: (fullSec.upperBound - fullSec.lowerBound) / max(maximumYAxisZoomScale, 1),
                maxSpan: fullSec.upperBound - fullSec.lowerBound)
        }
        commitYRange(main: newY, secondary: newSec)
    }

    public func panYAxis(screenDeltaY: CGFloat, allowsRubberBand: Bool) {
        let margin = allowsRubberBand
            ? (fullYRange.upperBound - fullYRange.lowerBound) * CartesianGeometry.rubberBandMarginRatio
            : 0
        let newY = CartesianGeometry.pannedXRange(
            from: currentViewport.yDomain,
            screenDeltaX: screenDeltaY,     // 两轴平移公式同构：内容跟手，高度换算
            plotWidth: currentPlotFrame.height,
            fullDomain: fullYRange,
            overshootMargin: margin)

        var newSec: ClosedRange<Double>?
        if let sec = currentSecondaryYDomain, let fullSec = fullSecondaryYRange {
            let secMargin = allowsRubberBand
                ? (fullSec.upperBound - fullSec.lowerBound) * CartesianGeometry.rubberBandMarginRatio
                : 0
            newSec = CartesianGeometry.pannedXRange(
                from: sec, screenDeltaX: screenDeltaY,
                plotWidth: currentPlotFrame.height,
                fullDomain: fullSec, overshootMargin: secMargin)
        }
        commitYRange(main: newY, secondary: newSec)
    }

    /// 主/次 Y 窗口一起提交（一次 relayout，两轴原子更新）。
    private func commitYRange(main: ClosedRange<Double>, secondary: ClosedRange<Double>?) {
        let oldMain = userYRange, oldSec = userSecondaryYRange
        userYRange = main
        userSecondaryYRange = secondary ?? oldSec
        if main != oldMain || userSecondaryYRange != oldSec { relayout() }
    }

    public func setYAxisViewport(_ range: ClosedRange<Double>) {
        let margin = (fullYRange.upperBound - fullYRange.lowerBound) * CartesianGeometry.rubberBandMarginRatio
        let lo = min(max(range.lowerBound, fullYRange.lowerBound - margin), fullYRange.upperBound)
        let hi = max(min(range.upperBound, fullYRange.upperBound + margin), fullYRange.lowerBound)
        applyUserYRange(min(lo, hi)...max(lo, hi))
    }

    public var isYAxisOvershooting: Bool {
        currentViewport.yMin < fullYRange.lowerBound - 1e-9
            || currentViewport.yMax > fullYRange.upperBound + 1e-9
    }

    public func resetYAxisViewport() {
        guard userYRange != nil || userSecondaryYRange != nil else { return }
        userYRange = nil
        userSecondaryYRange = nil
        relayout()
    }

    private func applyUserYRange(_ range: ClosedRange<Double>) {
        guard range != userYRange else { return }
        userYRange = range
        relayout()
    }

    /// 手势视口变化后的整体重排（禁用隐式动画，保证跟手）。
    private func relayout() {
        guard let model = currentModel, let theme = currentTheme, let context = lastContext else { return }
        render(model: model, theme: theme, context: context)
    }

    /// 可见类目索引范围（部分可见即计入；子类据此跳过视口外元素的 layer 创建）。
    /// 仅对垂直图有意义（类目在 X、参与手势缩放）；水平图类目在 Y（不参与手势、
    /// 恒全量可见），水平子类（Bar）无需此裁剪。
    var visibleCategoryRange: Range<Int> {
        CartesianGeometry.visibleCategoryRange(viewport: currentViewport,
                                               count: currentModel?.maxPointCount ?? 0)
    }

    // MARK: - render（模板方法；子类不得 override，扩展点在 drawSeries）
    public final func render(model: CartesianChartModel, theme: ChartTheme,
                             context: HYMChartRenderContext) {
        currentModel = model
        currentTheme = theme
        lastContext = context

        // 全程禁用隐式动画：本方法在手势 relayout 时高频调用，
        // layer 增删/属性变化必须即时呈现（否则缩放拖影、不跟手）。
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        // 清空旧内容
        rootLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        titleLabels.forEach { $0.removeFromSuperview() }; titleLabels.removeAll()
        tickLabels.forEach { $0.removeFromSuperview() }; tickLabels.removeAll()
        rootLayer.frame = context.bounds

        guard let cartTheme = theme as? CartesianChartTheme else { return }

        // 1) 背景
        if let bg = cartTheme.backgroundColor {
            backgroundLayer.isHidden = false
            backgroundLayer.frame = context.bounds
            backgroundLayer.backgroundColor = bg.cgColor
            backgroundLayer.cornerRadius = cartTheme.backgroundCornerRadius
        } else {
            backgroundLayer.isHidden = true
        }

        // 2) viewport（值域：显式或 nice，始终数据驱动；X 轴：手势窗口优先，否则全量）
        currentViewport = makeViewport(model: model)

        // 2.5) 次值轴（仅垂直图；Bar 水平图忽略并提示）
        if let secondary = model.secondaryYAxis {
            if isHorizontalValueAxis {
                assertionFailure("Bar（水平图）暂不支持 secondaryYAxis，将忽略")
                currentSecondaryYDomain = nil
                currentSecondaryValueTicks = []
                fullSecondaryYRange = nil
            } else {
                let bounds = model.dataBounds(yAxisIndex: 1)
                let full = makeValueDomain(axis: secondary, bounds: bounds)
                fullSecondaryYRange = full
                // Y 缩放窗口（与主轴同手势、独立域）：clamp 语义与主轴一致
                var domain = full
                if let user = userSecondaryYRange {
                    let fullSpan = full.upperBound - full.lowerBound
                    let span = min(max(user.upperBound - user.lowerBound,
                                       fullSpan / max(maximumYAxisZoomScale, 1)), fullSpan)
                    let margin = fullSpan * CartesianGeometry.rubberBandMarginRatio
                    var lo = min(max(user.lowerBound, full.lowerBound - margin),
                                 full.upperBound + margin - span)
                    lo = max(lo, full.lowerBound - margin)
                    domain = lo...(lo + span)
                }
                currentSecondaryYDomain = domain
                currentSecondaryValueTicks = domain.lowerBound == domain.upperBound
                    ? []
                    : ValueTickGenerator.ticks(axis: secondary, domain: domain,
                                               dataBounds: bounds,
                                               generatesFromDomain: userSecondaryYRange != nil)
            }
        } else {
            currentSecondaryYDomain = nil
            currentSecondaryValueTicks = []
            fullSecondaryYRange = nil
        }

        // 3) 值轴刻度 + 布局（左侧标签宽度：水平图量类目标签、垂直图量值刻度文本；
        //    底部标签高度两种方向同为刻度字体行高）
        let valueDomainDegenerate = isHorizontalValueAxis
            ? currentViewport.xMin == currentViewport.xMax
            : currentViewport.yMin == currentViewport.yMax
        currentValueTicks = valueDomainDegenerate ? []
            : makeValueTicks(axis: model.yAxis,
                             domain: isHorizontalValueAxis ? currentViewport.xDomain : currentViewport.yDomain,
                             bounds: model.dataBounds(yAxisIndex: 0))
        let leadingLabelWidth: CGFloat = isHorizontalValueAxis
            ? model.categoryLabels.map { textSize($0, font: cartTheme.tickLabelFont).width }.max() ?? 0
            : currentValueTicks.map { textSize(AxisRenderer.tickText($0, formatter: model.yAxis.labelFormatter),
                                               font: cartTheme.tickLabelFont).width }.max() ?? 0
        let xTickHeight = textSize("0", font: cartTheme.tickLabelFont).height
        let titleHeight = model.title.map { textSize($0, font: cartTheme.titleFont).height } ?? 0
        let rightAxisLabelWidth: CGFloat = currentSecondaryYDomain == nil ? 0 :
            currentSecondaryValueTicks.map {
                textSize(AxisRenderer.tickText($0, formatter: model.secondaryYAxis?.labelFormatter),
                         font: cartTheme.tickLabelFont).width }.max() ?? 0
        currentPlotFrame = CartesianGeometry.layout(
            bounds: context.bounds,
            contentInset: cartTheme.contentInset,
            yAxisTickLabelWidth: leadingLabelWidth,
            xAxisTickLabelHeight: xTickHeight,
            axisLabelGap: cartTheme.axisLabelGap,
            titleHeight: titleHeight,
            rightAxisLabelWidth: rightAxisLabelWidth)

        // 4) 网格 + 轴 + 标题（挂在 series 之下）。
        // 空数据也画空坐标系（规格：防御式兜底），只是跳过 series 绘制。
        // 次轴网格默认关；轴级 showsGridlines 开启时才传入 ticks。
        var secondaryGridTicks: [Double] = []
        if currentSecondaryYDomain != nil,
           model.secondaryYAxis?.showsGridlines == true {
            secondaryGridTicks = currentSecondaryValueTicks
        }
        rootLayer.addSublayer(GridRenderer.makeGridLayer(
            valueTicks: currentValueTicks, categoryCount: model.maxPointCount,
            viewport: currentViewport, plotFrame: currentPlotFrame, theme: cartTheme,
            isHorizontalValueAxis: isHorizontalValueAxis,
            secondaryValueTicks: secondaryGridTicks,
            secondaryYDomain: currentSecondaryYDomain))
        rootLayer.addSublayer(AxisRenderer.makeAxisLinesLayer(
            plotFrame: currentPlotFrame, theme: cartTheme,
            showsRightAxis: currentSecondaryYDomain != nil))
        addTickLabels(model: model, theme: cartTheme)
        addTitleLabel(model: model, theme: cartTheme)

        // 5) series 挂载层（裁剪到 plot 区，防止缩放后溢出），子类画在其下
        //
        // 坐标系约定（关键）：子类几何函数返回 **view 绝对坐标**（与 grid/axis 的 path 一致）。
        // seriesLayer.frame = plotFrame 提供定位与裁剪边界，bounds.origin = plotFrame.origin
        // 把子层坐标系平移回 view 原点——sublayer 直接用绝对坐标，无双重偏移。
        seriesLayer.frame = currentPlotFrame
        seriesLayer.bounds.origin = currentPlotFrame.origin
        seriesLayer.masksToBounds = true
        rootLayer.addSublayer(seriesLayer)
        if model.maxPointCount > 0 {
            drawSeries(model: model, theme: theme, plotFrame: currentPlotFrame)
        }
        // 6) 标线（阈值参考线）：画在系列之上，超出当前值域自动隐藏（缩放平移跟随）
        drawPlotLines(model: model, theme: cartTheme)
    }

    // MARK: - 标线（plotLines）
    /// 值轴标线：垂直图 = 水平横线（次轴线按次值域换算），水平图（Bar）= 竖线。
    private func drawPlotLines(model: CartesianChartModel, theme: CartesianChartTheme) {
        guard !model.plotLines.isEmpty else { return }
        for pl in model.plotLines {
            let domain: ClosedRange<Double>?
            let axisIdx = pl.yAxisIndex == 1 ? 1 : 0
            if isHorizontalValueAxis {
                domain = axisIdx == 0 ? currentViewport.xDomain : nil   // 水平图无次轴
            } else {
                domain = axisIdx == 1 ? currentSecondaryYDomain : currentViewport.yDomain
            }
            guard let domain,
                  domain.lowerBound <= pl.value, pl.value <= domain.upperBound else { continue }

            let path = UIBezierPath()
            let labelCenter: CGPoint
            let labelSize = pl.label.map { dataLabelTextSize($0, fontSize: theme.tickLabelFont.pointSize) }
            if isHorizontalValueAxis {
                let x = CartesianGeometry.point(x: pl.value, y: 0,
                                                viewport: currentViewport,
                                                plotFrame: currentPlotFrame).x
                path.move(to: CGPoint(x: x, y: currentPlotFrame.minY))
                path.addLine(to: CGPoint(x: x, y: currentPlotFrame.maxY))
                labelCenter = CGPoint(x: min(x + (labelSize?.width ?? 0) / 2 + 4,
                                             currentPlotFrame.maxX - (labelSize?.width ?? 0) / 2),
                                      y: currentPlotFrame.minY + (labelSize?.height ?? 0) / 2 + 3)
            } else {
                let y = screenPoint(x: 0, y: pl.value, yAxisIndex: axisIdx).y
                path.move(to: CGPoint(x: currentPlotFrame.minX, y: y))
                path.addLine(to: CGPoint(x: currentPlotFrame.maxX, y: y))
                labelCenter = CGPoint(x: currentPlotFrame.maxX - (labelSize?.width ?? 0) / 2 - 4,
                                      y: y - (labelSize?.height ?? 0) / 2 - 3)
            }
            let line = CAShapeLayer()
            line.path = path.cgPath
            line.strokeColor = pl.color.cgColor
            line.fillColor = nil
            line.lineWidth = max(0.25, pl.lineWidth)
            line.lineDashPattern = pl.dashStyle.dashPattern
            rootLayer.addSublayer(line)

            if let text = pl.label {
                rootLayer.addSublayer(makeDataLabelLayer(
                    text: text, fontSize: theme.tickLabelFont.pointSize,
                    color: pl.color, center: labelCenter))
            }
        }
    }

    // MARK: - 子类扩展点
    /// 把 series 画进 plot 区（挂 rootLayer 下）。子类必须在此缓存命中几何（如各数据点 frame）。
    open func drawSeries(model: CartesianChartModel, theme: ChartTheme, plotFrame: CGRect) {}

    /// 系列命中测试（view 坐标点）。默认 nil。
    open func seriesHitTest(_ point: CGPoint) -> HYMChartHitTarget? { nil }

    // MARK: - 命中契约（witness 固定在基类，子类实现 seriesHitTest 即可）
    public func hitTest(_ point: CGPoint) -> HYMChartHitTarget? { seriesHitTest(point) }

    // MARK: - 弹窗/命中 frame 契约
    // witness 锚定在基类（与 hitTest 同理）：若只在子类实现而不在基类提供转发，
    // 协议 witness 会解析到 HYMChartRenderer 扩展的默认实现（返回 nil），
    // 子类实现永远不被调用——内置 tooltip 因此不显示（Swift 协议 witness 陷阱）。
    // 子类用 `override` 提供真实实现。
    public func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? { nil }
    public func hitFrame(for target: HYMChartHitTarget) -> CGRect? { nil }

    // MARK: - 便捷（子类用）
    /// 由子类把吸附结果包装成各自的 HitTarget（Line/Column/Bar 的 target 类型不同）。
    open func makeHitTarget(seriesIndex: Int, categoryIndex: Int, value: Double)
        -> (any HYMChartHitTarget)? { nil }

    /// 值 → 屏幕（view 坐标系），用当前 viewport/plotFrame；须在 render 之后调用。
    /// 按系列绑定的值轴选域：0 = 主轴 viewport.yDomain，1 = 次轴域。
    func screenPoint(x: Double, y: Double, yAxisIndex: Int = 0) -> CGPoint {
        CartesianGeometry.point(x: x, y: y, viewport: currentViewport,
                                plotFrame: currentPlotFrame,
                                yDomain: yAxisIndex == 1 ? currentSecondaryYDomain : nil)
    }

    // MARK: - 数据标签（Line/Column/Bar 共用工具）
    /// 系列是否画数据标签：系列级 `dataLabelsEnabled` 覆盖主题开关；
    /// 可见类目 × 系列总数超 `dataLabelMaxMarkCount` 时整图跳过（缩放后可见数变少自动恢复）。
    func dataLabelsAllowed(for element: CartesianSeriesElement,
                           theme: CartesianChartTheme) -> Bool {
        guard element.dataLabelsEnabled ?? theme.showsDataLabels else { return false }
        let visible = visibleCategoryRange.count
        return visible * max(currentModel?.series.count ?? 0, 1) <= theme.dataLabelMaxMarkCount
    }

    /// 标签文本尺寸（与 makeDataLabelLayer 同字体，供先量尺寸再算中心）。
    func dataLabelTextSize(_ text: String, fontSize: CGFloat) -> CGSize {
        textSize(text, font: UIFont.systemFont(ofSize: fontSize, weight: .medium))
    }

    /// 标签颜色：显式 `dataLabelColor` > 位置自适应（形状内 = 白、外侧 = `.label` 随深浅色）。
    func dataLabelColor(theme: CartesianChartTheme, inside: Bool) -> UIColor {
        theme.dataLabelColor ?? (inside ? .white : .label)
    }

    /// 居中定位的 CATextLayer（加到 rootLayer，不受 seriesLayer 裁剪——
    /// 端部外侧标签允许略微探出 plot 区，否则贴边柱/点的标签会被裁一半）。
    func makeDataLabelLayer(text: String, fontSize: CGFloat, color: UIColor, center: CGPoint) -> CATextLayer {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let size = textSize(text, font: font)
        let label = CATextLayer()
        label.string = text
        label.font = font
        label.fontSize = fontSize
        label.foregroundColor = color.cgColor
        label.alignmentMode = .center
        label.contentsScale = hostView?.window?.screen.scale ?? UIScreen.main.scale
        label.frame = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                             width: size.width, height: size.height)
        return label
    }

    // MARK: - 私有
    /// 由轴配置 + 绑定系列边界算值域（显式 min/max 优先，否则 nice scale）。
    private func makeValueDomain(axis: CartesianAxisModel,
                                 bounds: (min: Double, max: Double)?) -> ClosedRange<Double> {
        let b = bounds ?? (min: 0, max: 1)
        let scale = NiceScaleGenerator.generate(dataMin: axis.min ?? b.min,
                                                dataMax: axis.max ?? b.max)
        let lo = axis.min ?? scale.min
        let hi = axis.max ?? scale.max
        return min(lo, hi)...max(lo, hi)
    }

    private func makeViewport(model: CartesianChartModel) -> CartesianViewport {
        let count = max(model.maxPointCount, 1)
        // 类目域：-0.5...n-0.5（点 i 落 band 中心）。显式 min/max 覆盖。
        // 垂直图落 X 轴，水平图（条形图）落 Y 轴——轴配置按"值轴/类目轴"语义
        // （model.yAxis = 值轴、model.xAxis = 类目轴）与方向无关。
        let catMin = model.xAxis.min ?? -0.5
        let catMax = model.xAxis.max ?? Double(count - 1) + 0.5
        let fullCategory = min(catMin, catMax)...max(catMin, catMax)

        // 值域：显式 min/max 同显式时直接用；否则 nice scale（显式端单独生效时与自动端合并）。
        // 注意：显式端与自动刻度不对齐时，首/末刻度与轴线间会有空隙（显式端优先的语义，与 Highcharts 一致）。
        let fullValue = makeValueDomain(axis: model.yAxis, bounds: model.dataBounds(yAxisIndex: 0))

        // 手势窗口只作用于 X 轴：垂直图缩放类目域、水平图缩放数值域。
        // Y 轴（垂直图 = 值域，水平图 = 类目域）默认数据驱动；
        // zoomAxisMode .y/.xy 时由 userYRange 接管（同 X 的钳制与橡皮筋语义）。
        fullXRange = isHorizontalValueAxis ? fullValue : fullCategory
        var effectiveX = fullXRange
        if let user = userXRange {
            let fullSpan = fullXRange.upperBound - fullXRange.lowerBound
            let span = min(max(user.upperBound - user.lowerBound, minimumXSpan), fullSpan)
            // clamp 域放宽到全量域 ± 橡皮筋余量：越界窗口（拖拽回弹前）也可渲染
            let rubberMargin = fullSpan * CartesianGeometry.rubberBandMarginRatio
            var lo = min(max(user.lowerBound, fullXRange.lowerBound - rubberMargin),
                         fullXRange.upperBound + rubberMargin - span)
            lo = max(lo, fullXRange.lowerBound - rubberMargin)
            effectiveX = lo...(lo + span)
        }

        fullYRange = isHorizontalValueAxis ? fullCategory : fullValue
        var effectiveY = fullYRange
        if let user = userYRange {
            let fullSpan = fullYRange.upperBound - fullYRange.lowerBound
            let span = min(max(user.upperBound - user.lowerBound, minimumYSpan), fullSpan)
            let rubberMargin = fullSpan * CartesianGeometry.rubberBandMarginRatio
            var lo = min(max(user.lowerBound, fullYRange.lowerBound - rubberMargin),
                         fullYRange.upperBound + rubberMargin - span)
            lo = max(lo, fullYRange.lowerBound - rubberMargin)
            effectiveY = lo...(lo + span)
        }

        return isHorizontalValueAxis
            ? CartesianViewport(xMin: effectiveX.lowerBound, xMax: effectiveX.upperBound,
                                yMin: effectiveY.lowerBound, yMax: effectiveY.upperBound)
            : CartesianViewport(xMin: effectiveX.lowerBound, xMax: effectiveX.upperBound,
                                yMin: effectiveY.lowerBound, yMax: effectiveY.upperBound)
    }

    /// 值轴刻度：显式 tickInterval（须显式 min/max）从 min 步进；否则 nice scale ticks。
    /// 水平图值轴在 X：自动刻度按**生效 X 窗口**生成（缩放/平移时刻度跟随）；
    /// 垂直图值轴在 Y：默认按数据边界生成，Y 缩放窗口生效后改为按窗口域生成
    /// （否则放大后窗口内只剩零星刻度）。
    /// 结果过滤到生效值域内（显式 0...95 时 nice 化出的 100 不得越界画线）。
    private func makeValueTicks(axis: CartesianAxisModel,
                                domain: ClosedRange<Double>,
                                bounds: (min: Double, max: Double)?) -> [Double] {
        ValueTickGenerator.ticks(axis: axis, domain: domain, dataBounds: bounds,
                                 generatesFromDomain: isHorizontalValueAxis || userYRange != nil)
    }

    private func addTickLabels(model: CartesianChartModel, theme: CartesianChartTheme) {
        guard let view = hostView else { return }
        if isHorizontalValueAxis {
            tickLabels.append(contentsOf: AxisRenderer.makeBottomValueTickLabels(
                ticks: currentValueTicks, viewport: currentViewport,
                plotFrame: currentPlotFrame, theme: theme,
                formatter: model.yAxis.labelFormatter))
            tickLabels.append(contentsOf: AxisRenderer.makeLeftCategoryLabels(
                labels: model.categoryLabels, viewport: currentViewport,
                plotFrame: currentPlotFrame, theme: theme))
        } else {
            tickLabels.append(contentsOf: AxisRenderer.makeYTickLabels(
                ticks: currentValueTicks, viewport: currentViewport,
                plotFrame: currentPlotFrame, theme: theme,
                formatter: model.yAxis.labelFormatter))
            if let secondary = model.secondaryYAxis, !isHorizontalValueAxis {
                tickLabels.append(contentsOf: AxisRenderer.makeRightValueTickLabels(
                    ticks: currentSecondaryValueTicks, viewport: currentViewport,
                    plotFrame: currentPlotFrame, theme: theme,
                    formatter: secondary.labelFormatter,
                    secondaryDomain: currentSecondaryYDomain))
            }
            tickLabels.append(contentsOf: AxisRenderer.makeCategoryLabels(
                labels: model.categoryLabels, viewport: currentViewport,
                plotFrame: currentPlotFrame, theme: theme))
        }
        tickLabels.forEach { view.addSubview($0) }
    }

    private func addTitleLabel(model: CartesianChartModel, theme: CartesianChartTheme) {
        guard let view = hostView, let title = model.title else { return }
        let lbl = UILabel()
        lbl.text = title
        lbl.textColor = theme.titleColor
        lbl.font = theme.titleFont
        lbl.sizeToFit()
        lbl.center = CGPoint(x: view.bounds.midX,
                             y: theme.contentInset.top + lbl.bounds.height / 2)
        view.addSubview(lbl)
        titleLabels.append(lbl)
    }

    private func textSize(_ s: String, font: UIFont) -> CGSize {
        (s as NSString).size(withAttributes: [.font: font])
    }
}

// MARK: - 命中辅助（整列/吸附共用）
extension CartesianRendererBase {

    /// 触点 → 最近类目索引（垂直图按 X 值、水平图按 Y 类目）；plot 区（±8pt）外或无类目 → nil。
    func categoryIndex(at point: CGPoint) -> Int? {
        guard let model = currentModel, currentPlotFrame.width > 0, currentPlotFrame.height > 0,
              model.maxPointCount > 0 else { return nil }
        guard currentPlotFrame.insetBy(dx: -8, dy: -8).contains(point) else { return nil }
        let categoryIndex: Int
        if isHorizontalValueAxis {
            // 水平图（Bar）：类目在 Y
            let cat = CartesianGeometry.horizontalCategory(
                atY: point.y, viewport: currentViewport, plotFrame: currentPlotFrame)
            categoryIndex = Int(cat.rounded())
        } else {
            let x = CartesianGeometry.value(at: point, viewport: currentViewport,
                                            plotFrame: currentPlotFrame).x
            categoryIndex = Int(x.rounded())
        }
        guard categoryIndex >= 0, categoryIndex < model.maxPointCount else { return nil }
        return categoryIndex
    }
}

// MARK: - 十字准线几何（逐点/整列命中共用）
extension CartesianRendererBase {

    /// 命中目标所在类目的准线：垂直图 = 过类目中心的全高竖线，水平图 = 过类目行的全宽横线。
    /// 几何与 sharedHit 的 crosshair 完全一致（同一类目同一条线）。
    public func crosshairRect(for target: HYMChartHitTarget) -> CGRect? {
        guard let model = currentModel else { return nil }
        let idx: Int?
        switch target {
        case let t as CartesianSharedHitTarget: idx = t.categoryIndex
        case let t as LineHitTarget:             idx = t.index
        case let t as ColumnHitTarget:           idx = t.categoryIndex
        case let t as BarHitTarget:              idx = t.categoryIndex
        default:                                 idx = nil
        }
        guard let categoryIndex = idx, categoryIndex >= 0, categoryIndex < model.maxPointCount else { return nil }

        if isHorizontalValueAxis {
            let y = CartesianGeometry.horizontalCategoryY(category: Double(categoryIndex),
                                                          viewport: currentViewport,
                                                          plotFrame: currentPlotFrame)
            return CGRect(x: currentPlotFrame.minX, y: y - 0.5,
                          width: currentPlotFrame.width, height: 1)
        }
        let x = CartesianGeometry.point(x: Double(categoryIndex), y: 0,
                                        viewport: currentViewport,
                                        plotFrame: currentPlotFrame).x
        return CGRect(x: x - 0.5, y: currentPlotFrame.minY,
                      width: 1, height: currentPlotFrame.height)
    }
}

// MARK: - 双向准线的值向分量
extension CartesianRendererBase {

    /// 值轴方向准线：垂直图 = 过命中值的横线（按 target 绑定轴选域），水平图（Bar）= 竖线。
    /// 整列命中（CartesianSharedHitTarget）无单一值，由 sharedHit 的触点分量代替。
    public func valueCrosshairRect(for target: HYMChartHitTarget) -> CGRect? {
        guard currentModel != nil, currentPlotFrame.width > 0 else { return nil }
        let value: Double?
        let axis: Int
        switch target {
        case let t as LineHitTarget:   value = t.value; axis = t.yAxisIndex
        case let t as ColumnHitTarget: value = t.value; axis = t.yAxisIndex
        case let t as BarHitTarget:    value = t.value; axis = 0
        default:                       value = nil; axis = 0
        }
        guard let v = value else { return nil }
        if isHorizontalValueAxis {
            let x = CartesianGeometry.point(x: v, y: 0, viewport: currentViewport,
                                            plotFrame: currentPlotFrame).x
            return CGRect(x: x - 0.5, y: currentPlotFrame.minY,
                          width: 1, height: currentPlotFrame.height)
        }
        let y = screenPoint(x: 0, y: v, yAxisIndex: axis).y
        return CGRect(x: currentPlotFrame.minX, y: y - 0.5,
                      width: currentPlotFrame.width, height: 1)
    }
}

// MARK: - 整列命中（shared tooltip）
extension CartesianRendererBase: HYMChartSharedHitProvider {

    /// 点击按类目取整列：X 位置四舍五入到最近类目，组合所有有值系列。
    /// 点在 plot 区外（±8pt 宽容）返回 nil，由容器回落到逐点命中。
    public func sharedHit(at point: CGPoint) -> (target: any HYMChartHitTarget,
                                                 anchor: HYMChartTooltipAnchor,
                                                 crosshair: CGRect,
                                                 valueCrosshair: CGRect)? {
        guard let model = currentModel,
              let categoryIndex = categoryIndex(at: point) else { return nil }

        var entries: [CartesianSharedHitTarget.Entry] = []
        for (i, s) in model.series.enumerated()
        where categoryIndex < s.data.count && s.data[categoryIndex].isFinite {
            let isSecondary = s.effectiveYAxisIndex == 1
            entries.append(CartesianSharedHitTarget.Entry(seriesIndex: i, name: s.name,
                                                          value: s.data[categoryIndex],
                                                          isSecondaryAxis: isSecondary))
        }
        guard !entries.isEmpty else { return nil }

        // 锚点在触点位置（弹窗跟手出现，而非固定在图表顶部/底部）：
        // 垂直图 x 对齐类目中心、水平图 y 对齐类目行中心
        // 十字准线：垂直图为过类目中心的全高竖线，水平图为过类目行的全宽横线；
        // 值向分量跟触点走（垂直图横线过触点 y、水平图竖线过触点 x，钳制在 plot 内）
        let band: CGRect
        let crosshair: CGRect
        let valueCrosshair: CGRect
        if isHorizontalValueAxis {
            let y = CartesianGeometry.horizontalCategoryY(category: Double(categoryIndex),
                                                          viewport: currentViewport,
                                                          plotFrame: currentPlotFrame)
            band = CGRect(x: point.x - 1, y: y - 1, width: 2, height: 2)
            crosshair = CGRect(x: currentPlotFrame.minX, y: y - 0.5,
                               width: currentPlotFrame.width, height: 1)
            let vx = min(max(point.x, currentPlotFrame.minX), currentPlotFrame.maxX)
            valueCrosshair = CGRect(x: vx - 0.5, y: currentPlotFrame.minY,
                                    width: 1, height: currentPlotFrame.height)
        } else {
            let x = CartesianGeometry.point(x: Double(categoryIndex), y: 0,
                                            viewport: currentViewport,
                                            plotFrame: currentPlotFrame).x
            band = CGRect(x: x - 1, y: point.y - 1, width: 2, height: 2)
            crosshair = CGRect(x: x - 0.5, y: currentPlotFrame.minY,
                               width: 1, height: currentPlotFrame.height)
            let vy = min(max(point.y, currentPlotFrame.minY), currentPlotFrame.maxY)
            valueCrosshair = CGRect(x: currentPlotFrame.minX, y: vy - 0.5,
                                    width: currentPlotFrame.width, height: 1)
        }
        let headerKey = categoryIndex < model.categoryLabels.count
            ? model.categoryLabels[categoryIndex] : nil
        let target = CartesianSharedHitTarget(categoryIndex: categoryIndex,
                                              entries: entries,
                                              crosshairX: band.midX,
                                              headerKey: headerKey)
        return (target, HYMChartTooltipAnchor(frame: band,
                                               preferredPlacements: [.top, .bottom]),
                crosshair, valueCrosshair)
    }
}

// MARK: - 吸附命中（横向最近类目 → 离触点最近的系列点）
extension CartesianRendererBase: HYMChartSnapHitProvider {

    /// 点击没落在数据点上时的兜底：先归到最近类目，再在该列各系列点中
    /// 取屏幕距离最近者（"永远有反馈"，DGCharts 同款语义）。
    public func snapHit(at point: CGPoint) -> (any HYMChartHitTarget)? {
        guard let model = currentModel,
              let categoryIndex = categoryIndex(at: point) else { return nil }
        var best: (series: Int, value: Double, dist: CGFloat)?
        for (i, s) in model.series.enumerated()
        where categoryIndex < s.data.count && s.data[categoryIndex].isFinite {
            let v = s.data[categoryIndex]
            let p = isHorizontalValueAxis
                ? screenPoint(x: v, y: Double(categoryIndex))
                : screenPoint(x: Double(categoryIndex), y: v,
                              yAxisIndex: s.effectiveYAxisIndex)
            let d = hypot(p.x - point.x, p.y - point.y)
            if best == nil || d < best!.dist { best = (i, v, d) }
        }
        guard let b = best else { return nil }
        return makeHitTarget(seriesIndex: b.series, categoryIndex: categoryIndex, value: b.value)
    }

}
