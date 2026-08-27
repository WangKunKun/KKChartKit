import UIKit

/// 轴系图表渲染基类（模板方法）。
///
/// 统一编排：背景 → 值域(nice scale) → viewport → plot 布局 → 网格 → 轴 → 标题
/// → **子类 `drawSeries`**。轴/网格/标题/命中上下文全部由基类负责，
/// 子类（LineChartRenderer 等）只实现"把 series 画进 plot 区"与系列命中。
///
/// 泛型参数 `ChartTheme` 让阶段 1 起各类型可扩展自己的 Theme
/// （如 ColumnChartTheme 在 CartesianChartTheme 基础上加柱宽），阶段 0 直接用 CartesianChartTheme。
open class CartesianRendererBase<ChartTheme: HYMChartTheme>: HYMChartRenderer {
    public typealias Model = CartesianChartModel
    public typealias Theme = ChartTheme

    public required init() {}

    // MARK: - layer 子树
    /// 根容器（网格/轴线/series 挂其下；入场动画的 opacity 单元）。
    let rootLayer = CALayer()
    private let backgroundLayer = CALayer()
    private weak var hostView: UIView?
    private var titleLabels: [UILabel] = []
    private var tickLabels: [UILabel] = []

    // MARK: - 渲染期状态（供子类命中/动画读取）
    /// 当前生效的 viewport（render 时重算；阶段 0 为固定全量值域）。
    var currentViewport = CartesianViewport(xMin: 0, xMax: 1, yMin: 0, yMax: 1)
    /// 自定义 viewport（缩放时由外部设置，nil 时使用自动计算的）
    var customViewport: CartesianViewport?
    /// 当前 plot 区（view 坐标系）。
    var currentPlotFrame: CGRect = .zero
    var currentModel: CartesianChartModel?
    var currentTheme: ChartTheme?
    var lastContext: HYMChartRenderContext?
    /// 当前 y 刻度（网格与 y label 同源）。
    var currentYTicks: [Double] = []

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

    // MARK: - render（模板方法；子类不得 override，扩展点在 drawSeries）
    public final func render(model: CartesianChartModel, theme: ChartTheme,
                             context: HYMChartRenderContext) {
        currentModel = model
        currentTheme = theme
        lastContext = context

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

        // 2) viewport（y：显式或 nice；x：类目 -0.5...n-0.5）
        // 如果有自定义 viewport（缩放产生），使用自定义的；否则自动计算
        if let custom = customViewport {
            currentViewport = custom
        } else {
            currentViewport = makeViewport(model: model)
        }

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

        // 5) 子类绘制（模板方法扩展点；空数据不进 series）
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

    // MARK: - 便捷（子类用）
    /// 值 → 屏幕（view 坐标系），用当前 viewport/plotFrame；须在 render 之后调用。
    func screenPoint(x: Double, y: Double) -> CGPoint {
        CartesianGeometry.point(x: x, y: y, viewport: currentViewport, plotFrame: currentPlotFrame)
    }

    /// 外部缩放接口：设置自定义 viewport 并重新渲染
    /// - Parameter viewport: 缩放后的 viewport（以锚点为中心计算）
    public func zoomToViewport(_ viewport: CartesianViewport) {
        customViewport = viewport
        // 强制重新渲染（由外部的 setNeedsLayout 触发）
    }

    /// 重置缩放：清除自定义 viewport，恢复自动计算
    public func resetZoom() {
        customViewport = nil
    }

    // MARK: - 私有
    private func makeViewport(model: CartesianChartModel) -> CartesianViewport {
        let count = max(model.maxPointCount, 1)
        // x：类目域 -0.5...n-0.5（点 i 落 band 中心）。显式 min/max 覆盖。
        let xMin = model.xAxis.min ?? -0.5
        let xMax = model.xAxis.max ?? Double(count - 1) + 0.5
        // y：显式 min/max 同显式时直接用；否则 nice scale（显式端单独生效时与自动端合并）。
        // 注意：显式端与自动刻度不对齐时，首/末刻度与轴线间会有空隙（显式端优先的语义，与 Highcharts 一致）。
        let bounds = model.dataBounds ?? (min: 0, max: 1)
        let scale = NiceScaleGenerator.generate(
            dataMin: model.yAxis.min ?? bounds.min,
            dataMax: model.yAxis.max ?? bounds.max)
        let yMin = model.yAxis.min ?? scale.min
        let yMax = model.yAxis.max ?? scale.max
        return CartesianViewport(xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax)
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
