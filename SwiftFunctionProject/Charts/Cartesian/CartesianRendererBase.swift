import UIKit

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
open class CartesianRendererBase<ChartTheme: HYMChartTheme>: HYMChartRenderer, HYMChartXAxisZoomable {
    public typealias Model = CartesianChartModel
    public typealias Theme = ChartTheme

    public required init() {}

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
    /// 当前 y 刻度（网格与 y label 同源）。
    var currentYTicks: [Double] = []

    // MARK: - X 轴视口状态（手势缩放/平移）
    /// 全量 X 域（render 时从 model 记录；手势窗口的 clamp 边界）。
    private(set) var fullXRange: ClosedRange<Double> = -0.5...0.5
    /// 用户手势设置的 X 窗口（nil = 全量）。外部 configure 会重置（见 `resetXAxisViewport`）。
    private var userXRange: ClosedRange<Double>?

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
    private var minimumXSpan: Double {
        let fullSpan = fullXRange.upperBound - fullXRange.lowerBound
        let byZoom = fullSpan / max(maximumXAxisZoomScale, 1)
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
        applyUserXRange(CartesianGeometry.pannedXRange(
            from: currentViewport.xDomain,
            screenDeltaX: screenDeltaX,
            plotWidth: currentPlotFrame.width,
            fullDomain: fullXRange))
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

    /// 手势视口变化后的整体重排（禁用隐式动画，保证跟手）。
    private func relayout() {
        guard let model = currentModel, let theme = currentTheme, let context = lastContext else { return }
        render(model: model, theme: theme, context: context)
    }

    /// 可见类目索引范围（部分可见即计入；子类据此跳过视口外元素的 layer 创建）。
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

        // 2) viewport（y：显式或 nice，始终数据驱动；x：手势窗口优先，否则全量）
        currentViewport = makeViewport(model: model)

        // 3) 布局（需要 y 刻度最宽文本宽度）
        currentYTicks = currentViewport.yMin == currentViewport.yMax
            ? [] : makeYTicks(model: model, domain: currentViewport.yDomain)
        let yTickWidth = currentYTicks.map { textSize(AxisRenderer.format($0), font: cartTheme.tickLabelFont).width }.max() ?? 0
        let xTickHeight = textSize("0", font: cartTheme.tickLabelFont).height
        let titleHeight = model.title.map { textSize($0, font: cartTheme.titleFont).height } ?? 0
        currentPlotFrame = CartesianGeometry.layout(
            bounds: context.bounds,
            contentInset: cartTheme.contentInset,
            yAxisTickLabelWidth: yTickWidth,
            xAxisTickLabelHeight: xTickHeight,
            axisLabelGap: cartTheme.axisLabelGap,
            titleHeight: titleHeight)

        // 4) 网格 + 轴 + 标题（挂在 series 之下）。
        // 空数据也画空坐标系（规格：防御式兜底），只是跳过 series 绘制。
        rootLayer.addSublayer(GridRenderer.makeGridLayer(
            yTicks: currentYTicks, categoryCount: model.maxPointCount,
            viewport: currentViewport, plotFrame: currentPlotFrame, theme: cartTheme))
        rootLayer.addSublayer(AxisRenderer.makeAxisLinesLayer(
            plotFrame: currentPlotFrame, theme: cartTheme))
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
    /// 值 → 屏幕（view 坐标系），用当前 viewport/plotFrame；须在 render 之后调用。
    func screenPoint(x: Double, y: Double) -> CGPoint {
        CartesianGeometry.point(x: x, y: y, viewport: currentViewport, plotFrame: currentPlotFrame)
    }

    // MARK: - 私有
    private func makeViewport(model: CartesianChartModel) -> CartesianViewport {
        let count = max(model.maxPointCount, 1)
        // x：类目域 -0.5...n-0.5（点 i 落 band 中心）。显式 min/max 覆盖。
        let xMin = model.xAxis.min ?? -0.5
        let xMax = model.xAxis.max ?? Double(count - 1) + 0.5
        fullXRange = min(xMin, xMax)...max(xMin, xMax)

        // 手势窗口优先（clamp 到全量域内、span 在 [最小可见跨度, 全量] 内；
        // 数据变化后旧窗口可能失效，此处兜底防止越界/过窄）
        var effectiveX = fullXRange
        if let user = userXRange {
            let fullSpan = fullXRange.upperBound - fullXRange.lowerBound
            let span = min(max(user.upperBound - user.lowerBound, minimumXSpan), fullSpan)
            var lo = min(max(user.lowerBound, fullXRange.lowerBound), fullXRange.upperBound - span)
            lo = max(lo, fullXRange.lowerBound)
            effectiveX = lo...(lo + span)
        }

        // y：显式 min/max 同显式时直接用；否则 nice scale（显式端单独生效时与自动端合并）。
        // 注意：显式端与自动刻度不对齐时，首/末刻度与轴线间会有空隙（显式端优先的语义，与 Highcharts 一致）。
        // y 域永远数据驱动——X 轴手势缩放/平移不影响 y 域（Y 轴固定）。
        let bounds = model.dataBounds ?? (min: 0, max: 1)
        let scale = NiceScaleGenerator.generate(
            dataMin: model.yAxis.min ?? bounds.min,
            dataMax: model.yAxis.max ?? bounds.max)
        let yMin = model.yAxis.min ?? scale.min
        let yMax = model.yAxis.max ?? scale.max
        return CartesianViewport(xMin: effectiveX.lowerBound, xMax: effectiveX.upperBound, yMin: yMin, yMax: yMax)
    }

    /// y 刻度：显式 tickInterval（须显式 min/max）从 min 步进；否则 nice scale ticks。
    /// 结果过滤到生效值域内（显式 0...95 时 nice 化出的 100 不得越界画线）。
    private func makeYTicks(model: CartesianChartModel, domain: ClosedRange<Double>) -> [Double] {
        let ticks: [Double]
        if let interval = model.yAxis.tickInterval,
           let lo = model.yAxis.min, let hi = model.yAxis.max, interval > 0 {
            let count = Int(((hi - lo) / interval).rounded())
            ticks = (0...max(count, 0)).map { lo + Double($0) * interval }
        } else {
            let bounds = model.dataBounds ?? (min: 0, max: 1)
            ticks = NiceScaleGenerator.generate(
                dataMin: model.yAxis.min ?? bounds.min,
                dataMax: model.yAxis.max ?? bounds.max).ticks
        }
        return ticks.filter { $0 >= domain.lowerBound - 1e-9 && $0 <= domain.upperBound + 1e-9 }
    }

    private func addTickLabels(model: CartesianChartModel, theme: CartesianChartTheme) {
        guard let view = hostView else { return }
        tickLabels.append(contentsOf: AxisRenderer.makeYTickLabels(
            ticks: currentYTicks, viewport: currentViewport,
            plotFrame: currentPlotFrame, theme: theme))
        tickLabels.append(contentsOf: AxisRenderer.makeCategoryLabels(
            labels: model.categoryLabels, viewport: currentViewport,
            plotFrame: currentPlotFrame, theme: theme))
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
