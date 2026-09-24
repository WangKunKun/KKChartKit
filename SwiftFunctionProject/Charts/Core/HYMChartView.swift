import UIKit

/// 通用图表容器（泛型）：持有 Renderer，负责布局分发、入场动画、触摸命中分发、
/// DisplayLink 生命周期与 layer 防泄漏。绘制细节全部在 Renderer。
///
/// Swift 用法：
/// ```
/// let chart = HYMChartView<RadarChartRenderer>(frame: .zero)
/// chart.configure(model: m, theme: t)
/// chart.playEntranceAnimation()
/// chart.onHit = { target, gesture in ... }
/// ```
public final class HYMChartView<Renderer: HYMChartRenderer>: UIView, UIGestureRecognizerDelegate {

    // MARK: - 状态
    private var model: Renderer.Model?
    private var theme: Renderer.Theme?
    private var interactionRevision = 0
    private var pendingAnimation = false
    private var seriesVisibilityOverrides: [String: Bool] = [:]
    /// 图例点击或 setSeriesVisible 修改有效显隐时回调。仅轴系图表提供此能力。
    public var onSeriesVisibilityChanged: ((String, Bool) -> Void)?
    private let animator = HYMChartValueAnimator()

    /// 命中交互单元时回调（带手势类型，为扩展留位）
    public var onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    /// tooltip 外观主题（通用；默认 `.default`，可覆盖）。
    public var tooltipTheme: HYMChartTooltipTheme = .default {
        didSet { tooltipController?.theme = tooltipTheme }
    }
    /// 命中时是否显示默认 tooltip（通用默认 false，避免影响现有图表；
    /// 需要弹窗的图表在其封装层显式置 true）。
    public var showsTooltipOnHit: Bool = false
    /// 命中后带位置信息的回调（外部自定义弹窗用）。
    /// 命中→context 非 nil（含 target/frame/location）；未命中（取消选中）→nil，外部据此隐藏弹窗。
    /// 设置后内置 tooltip 自动不显示（见 `updateTooltip` 互斥）。
    public var onHitLocated: ((HYMChartHitContext?, HYMChartGesture) -> Void)?

    /// 缩放手势启用（默认 false）。轴向由 zoomAxisMode 决定；
    /// renderer 需实现对应的 X/Y 视口协议。
    public var isZoomEnabled: Bool = false {
      didSet {
        zoomGesture.isEnabled = isZoomEnabled
        panGesture.isEnabled = isZoomEnabled
        doubleTapGesture.isEnabled = isZoomEnabled
      }
    }

    /// 最小缩放级别。当前实现固定语义 1.0（不可缩小超过全量数据），预留扩展。
    public var minimumZoomScale: CGFloat = 1.0
    /// 最大缩放级别（默认 10.0）。同步为 renderer 的最小可视 X/Y 跨度。
    public var maximumZoomScale: CGFloat = 10.0 {
      didSet {
        xAxisZoomable?.maximumXAxisZoomScale = maximumZoomScale
        yAxisZoomable?.maximumYAxisZoomScale = maximumZoomScale
      }
    }
    /// 最小可见类目数（放大下限，默认 12；≥ 2）。与 `maximumZoomScale` 共同约束，取更宽松者
    /// （小数据量按倍数防过度放大，大数据量按类目数保证"放大到底能看清单柱"）。
    public var minimumVisibleCategories: Int = 12 {
      didSet {
        xAxisZoomable?.minimumXAxisCategories = max(2, minimumVisibleCategories)
        yAxisZoomable?.minimumYAxisCategories = max(2, minimumVisibleCategories)
      }
    }
    /// 捏合缩放作用的轴向（默认 `.x` = 现状）。`.y`/`.xy` 需 renderer 实现
    /// `HYMChartYAxisZoomable`（轴系图表均实现）：垂直图 Y = 值轴、水平图 Y = 类目轴。
    /// 锚点取捏合中心在对应方向的分量；`.xy` 时两轴各自钳制（单轴到限另一轴仍可继续）。
    public var zoomAxisMode: HYMChartZoomAxisMode = .x

    // MARK: - 手势体验增强（参照 Charts/AAChartKit 交互惯例）
    /// 拖拽松手后的惯性减速（默认开）。
    public var isDragDecelerationEnabled: Bool = true
    /// 全量视口（未缩放）时拖拽自动变为「滑动选中」：手指划过逐个高亮数据点（默认开）。
    /// 已缩放/平移过的图表拖拽仍是移动视口。
    public var isHighlightPerDragEnabled: Bool = true
    /// 把视口拖出边界时的橡皮筋越界 + 松手回弹（默认开）。
    public var isRubberBandEnabled: Bool = true
    /// 命中数据时是否显示十字准线（贯穿绘图区的细线，Highcharts crosshair 同款）。
    /// 逐点命中与整列命中（shared tooltip）都会显示；默认开。
    public var isCrosshairEnabled: Bool = true
    /// 准线颜色（默认半透明中性灰）
    public var crosshairColor: UIColor = UIColor(white: 0.55, alpha: 0.9) {
        didSet { crosshairLayer.strokeColor = crosshairColor.cgColor }
    }
    /// 准线线宽（默认 0.75）
    public var crosshairLineWidth: CGFloat = 0.75 {
        didSet { crosshairLayer.lineWidth = max(0.25, crosshairLineWidth) }
    }
    /// 准线虚线样式（默认实线；AAChartKit crosshair dashStyle 同款）
    public var crosshairDashStyle: LineDashStyle = .solid {
        didSet { crosshairLayer.lineDashPattern = crosshairDashStyle.dashPattern }
    }
    /// 准线横+竖双向指示（默认单向：类目向一条线）。
    /// 开启后叠加值向分量——逐点命中 = 过命中值的线，整列命中 = 跟触点走（Highcharts crosshair 同款）。
    public var isCrosshairDualDirectionEnabled: Bool = false
    /// 内置弹窗文本模板（表头 {key} / 数值后缀 / 固定小数位）。
    /// 命中 target 实现 HYMChartTooltipDataSource 时生效，否则回落 target.tooltipText 固定格式。
    public var tooltipTextOptions = HYMChartTooltipTextOptions()
    /// 点击按 X 类目取**整列**数据（shared tooltip，Highcharts 同款）。
    /// - `nil`（默认，自动）：多系列图表开（整列对比信息密度最高）、单系列关（逐点+吸附更直观）；
    /// - `true`：强制整列；`false`：强制逐点。
    /// 仅对实现了 `HYMChartSharedHitProvider` 的 renderer（轴系图表）生效。
    public var isSharedTooltipOnTapEnabled: Bool? = nil

    /// 命中弹窗的「内容 view」提供者（外部自定义弹窗的便利模式）。
    ///
    /// 设了它：SDK 命中时调用获取内容 view，套统一外壳(背景/圆角/箭头)，
    /// 用 `HYMChartTooltipGeometry` 智能定位(边界避让) + 显隐动画显示；未命中自动隐藏。
    /// 设了它 → 跳过 `onHitLocated` 与内置 text tooltip（三层 fallback 最高优先级）。
    /// 内容 view 应能报告尺寸(`intrinsicContentSize` 或 `sizeThatFits(_:)`)。
    public var popupContentProvider: ((HYMChartHitContext) -> UIView?)?
    /// 弹窗控制器（首次显示时懒创建）。
    private var tooltipController: HYMChartTooltipController?
    /// 外部位置弹窗已显示时，数据更新需发送一次失效通知。
    private var locatedSelectionGesture: HYMChartGesture?

    // MARK: - 轴视口手势状态
    /// 当前 renderer 若实现 `HYMChartXAxisZoomable`（轴系图表）则支持 X 视口手势；
    /// 雷达图/热力图等未实现协议时所有手势自动无效。
    private var xAxisZoomable: HYMChartXAxisZoomable? { renderer as? HYMChartXAxisZoomable }
    /// renderer 若实现 `HYMChartYAxisZoomable`（轴系图表均实现）则支持 Y 轴缩放/平移。
    private var yAxisZoomable: HYMChartYAxisZoomable? { renderer as? HYMChartYAxisZoomable }
    /// 捏合增量基准（上一帧 gr.scale；增量比值连续复合 = 手势累计，跨手势天然续接）。
    private var lastPinchScale: CGFloat = 1.0
    /// 平移增量基准（上一帧累计 translation，差值即本次增量，无累计漂移）。
    private var lastPanTranslation = CGPoint.zero
    /// 当前 pan 的模式（拖视口 / 全量视图下滑动选中）。
    private var panIsHighlightMode = false
    /// 惯性减速/回弹动画专用（与入场动画的 animator 分开，互不干扰）。
    private let decelAnimator = HYMChartValueAnimator()
    /// 减速消费进度（上一帧 ease-out 进度，差值即本帧位移占比）。
    private var lastDecelProgress: Double = 0
    /// 十字准线层（shared tooltip 激活时贯穿绘图区）
    private let crosshairLayer = CAShapeLayer()

    private lazy var zoomGesture = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
    private lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
    private lazy var doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap(_:)))

    // MARK: - Renderer
    private let renderer: Renderer

    // MARK: - init
    public override init(frame: CGRect) {
        self.renderer = Renderer()
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        // 泛型 UIView 不支持从 Xib/Storyboard 初始化（本项目纯代码 + SwiftUI，不会触发）
        fatalError("HYMChartView 不支持 init?(coder:)，请用 init(frame:)")
    }

    private func commonInit() {
        backgroundColor = .clear
        // 不裁剪 self：标签需画在卡片（gradientLayer）外侧
        clipsToBounds = false
        isUserInteractionEnabled = true
        renderer.mount(into: self)
        (renderer as? HYMChartLegendProviding)?.onLegendToggle = { [weak self] id, visible in
            self?.setSeriesVisible(visible, for: id)
        }
        // 样式初值来自实例属性（didSet 在 init 阶段不触发，这里显式应用一次）
        crosshairLayer.strokeColor = crosshairColor.cgColor
        crosshairLayer.fillColor = nil
        crosshairLayer.lineWidth = crosshairLineWidth
        crosshairLayer.lineDashPattern = crosshairDashStyle.dashPattern
        crosshairLayer.isHidden = true
        // render() 每次重绘都会往 self.layer 追加内容层（卡片背景等不透明层在数组序上高于本层），
        // 用 zPosition 稳定置顶（低于 tooltip 的 1000，弹窗永远压住准线）
        crosshairLayer.zPosition = 900
        layer.addSublayer(crosshairLayer)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
        addGestureRecognizer(zoomGesture)
        addGestureRecognizer(panGesture)
        addGestureRecognizer(doubleTapGesture)
        gestureRecognizers?.forEach { $0.delegate = self }
        doubleTapGesture.numberOfTapsRequired = 2
        zoomGesture.isEnabled = isZoomEnabled
        panGesture.isEnabled = isZoomEnabled
        doubleTapGesture.isEnabled = isZoomEnabled
    }

    // MARK: - 公开 API
    /// 配置并刷新（model + theme 一起传入）。
    ///
    /// 重置全部视口到全量；保留窗口请改用 update。必须在主线程调用。
    public func configure(model: Renderer.Model, theme: Renderer.Theme) {
        seriesVisibilityOverrides.removeAll()
        update(model: model, theme: theme, viewportPolicy: .reset)
    }

    /// 更新数据和样式，默认保留用户的缩放/平移窗口。
    ///
    /// - Parameters:
    ///   - model: 新数据模型；也可用于首次配置。
    ///   - theme: 新主题。
    ///   - viewportPolicy: 保留窗口并限制到新数据域，或重置到全量。
    /// - Note: 必须在主线程调用。下一次布局时绘制；不自动播放入场动画。
    ///   停止旧动画，清除旧选择、准线和弹窗，避免显示旧数据。
    ///   当前未提供跨数据更新的选择身份保持；不支持视口协议的 renderer 仍正常刷新。
    public func update(model: Renderer.Model, theme: Renderer.Theme,
                       viewportPolicy: HYMChartViewportUpdatePolicy = .preserve) {
        interactionRevision &+= 1
        stopDeceleration()
        if animator.isRunning { finishEntranceAnimationIfNeeded() }
        pendingAnimation = false
        hideCrosshair()
        tooltipController?.hide(animated: false)
        renderer.applySelection(nil)
        if let next = model as? CartesianChartModel {
            let previous = self.model as? CartesianChartModel
            let ids = Set(next.series.map(\.id))
            seriesVisibilityOverrides = seriesVisibilityOverrides.filter { ids.contains($0.key) }
            for series in next.series {
                if let old = previous?.series.first(where: { $0.id == series.id }),
                   old.isVisible != series.isVisible {
                    seriesVisibilityOverrides.removeValue(forKey: series.id)
                }
            }
        }
        self.model = model
        self.theme = theme
        if let updating = renderer as? any HYMChartViewportUpdating {
            updating.prepareViewportForUpdate(viewportPolicy)
        } else if viewportPolicy == .reset {
            xAxisZoomable?.resetXAxisViewport()
            yAxisZoomable?.resetYAxisViewport()
        }
        setNeedsLayout()
        if let gesture = locatedSelectionGesture {
            locatedSelectionGesture = nil
            onHitLocated?(nil, gesture)
        }
    }

    /// 只更新数据，沿用已配置主题；首次配置前调用不生效。必须在主线程调用。
    public func update(model: Renderer.Model,
                       viewportPolicy: HYMChartViewportUpdatePolicy = .preserve) {
        guard let theme else { return }
        update(model: model, theme: theme, viewportPolicy: viewportPolicy)
    }

    /// 只更新样式，沿用已配置数据；首次配置前调用不生效。必须在主线程调用。
    public func update(theme: Renderer.Theme,
                       viewportPolicy: HYMChartViewportUpdatePolicy = .preserve) {
        guard let model else { return }
        update(model: model, theme: theme, viewportPolicy: viewportPolicy)
    }

    /// 主动恢复全部视口（含次轴），不修改数据或主题。必须在主线程调用。
    public func resetViewport() {
        guard let model, let theme else { return }
        update(model: model, theme: theme, viewportPolicy: .reset)
    }

    /// 按稳定系列 ID 设置显隐；不改变原始数据。重复 ID 不可独立切换，应由调用方保证唯一。
    public func setSeriesVisible(_ visible: Bool, for seriesID: String) {
        guard let cartesian = model as? CartesianChartModel,
              let series = cartesian.series.first(where: { $0.id == seriesID }),
              (seriesVisibilityOverrides[seriesID] ?? series.isVisible) != visible,
              let model, let theme else { return }
        seriesVisibilityOverrides[seriesID] = visible
        update(model: model, theme: theme)
        layoutIfNeeded()
        onSeriesVisibilityChanged?(seriesID, visible)
    }

    public func isSeriesVisible(_ seriesID: String) -> Bool? {
        guard let cartesian = model as? CartesianChartModel,
              let series = cartesian.series.first(where: { $0.id == seriesID }) else { return nil }
        return seriesVisibilityOverrides[seriesID] ?? series.isVisible
    }

    /// 清除图例本地状态，恢复为模型的 isVisible。
    public func resetSeriesVisibility() {
        seriesVisibilityOverrides.removeAll()
        guard let model, let theme else { return }
        update(model: model, theme: theme)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view, current !== self {
            if current is ChartLegendView { return false }
            view = current.superview
        }
        return true
    }

    /// 按原始类目索引进入明细；聚合不会改变该坐标。需先 configure/update。
    public func showCategoryRange(_ range: Range<Int>) {
        guard !range.isEmpty, let model, let theme,
              let controlling = renderer as? HYMChartCategoryViewportControlling else { return }
        update(model: model, theme: theme)
        layoutIfNeeded()
        controlling.showCategoryRange(range)
    }

    /// 播放入场动画（幂等，可重复调用）
    public func playEntranceAnimation() {
        guard model != nil, theme != nil else { return }
        pendingAnimation = true
        setNeedsLayout()   // 触发 layoutSubviews → performEntranceAnimation
    }

    // MARK: - 布局
    public override func layoutSubviews() {
        super.layoutSubviews()
        guard let model, let theme else { return }
        var renderModel = model
        if var cartesian = model as? CartesianChartModel {
            for i in cartesian.series.indices {
                if let visible = seriesVisibilityOverrides[cartesian.series[i].id] {
                    cartesian.series[i].isVisible = visible
                }
            }
            if let typed = cartesian as? Renderer.Model { renderModel = typed }
        }
        renderer.render(model: renderModel, theme: theme,
                        context: HYMChartRenderContext(
                            bounds: bounds,
                            center: CGPoint(x: bounds.midX, y: bounds.midY)))
        if pendingAnimation {
            pendingAnimation = false
            performEntranceAnimation()
        }
    }

    // MARK: - 入场动画
    private func performEntranceAnimation() {
        animator.stop()
        let animatable = renderer.animatableLayers
        let duration: CFTimeInterval = 0.8

        // 第 1 步：无动画设「初始态」——scale 极小 + 透明。
        // 必须在 identity transform 下（frame 由 render 设为 bounds，锚点居中）。
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for l in animatable {
            l.opacity = 0
        }
        renderer.updateEntranceAnimation(progress: 0)
        CATransaction.commit()

        // 第 2 步：逐帧驱动 animatableLayers 的 scale + opacity（DisplayLink）。
        // 不用 CATransaction 隐式动画：本方法在 layoutSubviews 内调用，UIKit 的 layout 上下文
        // 会抑制隐式动画（实测 setDisableActions(false) 亦无效）；改由 animator 每帧手动插值，
        // 与 renderer.updateEntranceAnimation（分数淡入）共用同一 progress，同步且可靠。
        animator.startEaseOut(duration: duration,
            handler: { [weak self] progress in
                guard let self else { return }
                for l in animatable {
                    l.opacity = Float(progress)
                }
                self.renderer.updateEntranceAnimation(progress: progress)
            },
            completion: { [weak self] in
                // 终态精确化：DisplayLink 最后一帧可能停在 0.99x（柱高/透明度差一丝），
                // 收尾强制推到 1，避免与后续手势的"定格到完成态"产生可见跳变。
                guard let self else { return }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                for l in animatable {
                    l.opacity = 1
                }
                self.renderer.updateEntranceAnimation(progress: 1)
                CATransaction.commit()
            })
    }

    // MARK: - 十字准线（shared tooltip 激活时显示）
    private func showCrosshair(_ lines: [CGRect]) {
        // 开关关闭或几何无效 → 撤掉现有准线（避免上一命中的残影，如用户中途拨掉开关）
        guard isCrosshairEnabled else {
            hideCrosshair()
            return
        }
        let path = UIBezierPath()
        for frame in lines where frame.width > 0 || frame.height > 0 {
            if frame.width <= 1 {          // 竖线
                path.move(to: CGPoint(x: frame.minX, y: frame.minY))
                path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
            } else {                       // 横线（水平图）
                path.move(to: CGPoint(x: frame.minX, y: frame.minY))
                path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
            }
        }
        guard !path.isEmpty else {
            hideCrosshair()
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        crosshairLayer.path = path.cgPath
        crosshairLayer.isHidden = false
        CATransaction.commit()
    }

    private func hideCrosshair() {
        guard !crosshairLayer.isHidden else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        crosshairLayer.isHidden = true
        CATransaction.commit()
    }

    // MARK: - 触摸命中（tap 与拖拽滑动选中共用）
    @objc private func onTap(_ gr: UITapGestureRecognizer) {
        let p = gr.location(in: self)
        performTap(at: p)
    }

    /// 与 tap 手势同一分发路径（整列优先、回落逐点）；供测试与无手势环境驱动。
    func performTap(at point: CGPoint) {
        layoutIfNeeded()   // update 后同一轮事件也必须命中新模型，不能读取旧缓存。
        if !handleSharedIfActive(at: point, gesture: .tap) {
            handleHit(at: point, gesture: .tap)
        }
    }

    /// 供测试：模拟一次"拖视口后松手"（与 onPan 的 .changed/.ended 同分发路径：
    /// 橡皮筋拖拽越界 → 松手回弹 / 惯性减速），无需真实手势。
    func simulateViewportPan(deltaX: CGFloat, velocityX: CGFloat = 0) {
        guard isZoomEnabled, let zoomable = xAxisZoomable else { return }
        finishEntranceAnimationIfNeeded()
        stopDeceleration()
        panIsHighlightMode = false
        zoomable.panXAxis(screenDeltaX: deltaX, allowsRubberBand: isRubberBandEnabled)
        if isRubberBandEnabled { reboundIfNeeded() }
        if !isRebounding, isDragDecelerationEnabled {
            startDeceleration(zoomable, velocity: velocityX)
        }
    }

    /// 供测试：当前 X 视口（renderer 未实现缩放协议时为 nil）。
    var xAxisViewportForTesting: ClosedRange<Double>? {
        (renderer as? HYMChartXAxisZoomable)?.xAxisViewport
    }

    /// 供 @testable 验证容器更新后的实际 renderer 状态。
    var rendererForTesting: Renderer { renderer }

    /// 准线当前是否可见（供单测断言；展示逻辑见 showCrosshair/hideCrosshair）。
    var isCrosshairVisibleForTesting: Bool {
        !crosshairLayer.isHidden && crosshairLayer.superlayer != nil
    }
    /// 准线层是否仍挂在 layer 树上（供单测诊断 detach 类问题）。
    var isCrosshairAttachedForTesting: Bool { crosshairLayer.superlayer != nil }

    /// 整列命中（shared tooltip）：优先于逐点命中，点在绘图区外自动回落。
    /// 自动档（nil）：单系列（整列只有一条数据）回落逐点+吸附，多系列才整列。
    /// tap 与滑动选中（drag）共用：drag 更新不重播淡入（弹窗跟手逐列移动，不闪动）。
    private func handleSharedIfActive(at p: CGPoint, gesture: HYMChartGesture) -> Bool {
        guard let shared = (renderer as? HYMChartSharedHitProvider)?.sharedHit(at: p) else { return false }
        let entryCount = (shared.target as? CartesianSharedHitTarget)?.entries.count ?? 0
        let useShared = isSharedTooltipOnTapEnabled ?? (entryCount > 1)
        guard useShared else { return false }
        renderer.applySelection(shared.target)
        let revision = interactionRevision
        onHit?(shared.target, gesture)
        // 回调可能直接进入明细/更新数据；不得继续展示旧区间的准线和弹窗。
        guard revision == interactionRevision else { return true }
        // 整列弹窗伴随准线：单向 = 类目向；双向 = 叠加跟触点的值向分量
        showCrosshair(isCrosshairDualDirectionEnabled
                      ? [shared.crosshair, shared.valueCrosshair]
                      : [shared.crosshair])
        // popup / onHitLocated 模式沿用逐点 target 的外部链路；shared 组合文本走内置 tooltip
        if popupContentProvider == nil && onHitLocated == nil {
            if let text = formattedTooltipText(for: shared.target) {
                ensureTooltipController().show(anchor: shared.anchor.frame, text: text,
                                               in: bounds,
                                               preferred: shared.anchor.preferredPlacements,
                                               animated: gesture != .drag)
            } else {
                tooltipController?.hide()
            }
        }
        return true
    }

    /// 命中分发：选中 + onHit 回调 + 三层弹窗 fallback（popup > onHitLocated > 内置 tooltip）。
    private func handleHit(at point: CGPoint, gesture: HYMChartGesture) {
        // 逐点命中失败 → 吸附横向最近类目上最近的系列点（"永远有反馈"，DGCharts 同款）
        let target = renderer.hitTest(point)
            ?? (renderer as? HYMChartSnapHitProvider)?.snapHit(at: point)
        renderer.applySelection(target)
        // 准线跟命中走（不依赖整列弹窗）：命中画在类目上，未命中撤掉
        if let target, let rect = renderer.crosshairRect(for: target) {
            var lines = [rect]
            if isCrosshairDualDirectionEnabled,
               let vRect = renderer.valueCrosshairRect(for: target) {
                lines.append(vRect)   // 双向：叠加过命中值的值向线
            }
            showCrosshair(lines)
        } else {
            hideCrosshair()
        }

        if let target {
            let revision = interactionRevision
            onHit?(target, gesture)                      // 始终：命中事件通知
            guard revision == interactionRevision else { return }

            let ctx = HYMChartHitContext(
                target: target,
                frame: renderer.hitFrame(for: target) ?? .zero,
                location: point)

            if popupContentProvider != nil {           // ① popup 模式（最高优先）
                if let cv = popupContentProvider?(ctx),
                   let anchor = renderer.tooltipAnchor(for: target) {
                    ensureTooltipController().show(anchor: anchor.frame, contentView: cv,
                                                  in: bounds, preferred: anchor.preferredPlacements)
                } else {
                    tooltipController?.hide()
                }
            } else if onHitLocated != nil {            // ② onHitLocated 外部全权
                locatedSelectionGesture = gesture
                onHitLocated?(ctx, gesture)
                tooltipController?.hide()
            } else {                                   // ③ 内置 text tooltip
                updateTooltip(for: target, animated: gesture != .drag)
            }
        } else {
            // 未命中：按激活模式镜像处理（popup 模式不触发 onHitLocated，与命中分支对称）
            locatedSelectionGesture = nil
            tooltipController?.hide()
            if popupContentProvider == nil, onHitLocated != nil {
                onHitLocated?(nil, gesture)
            }
        }
    }

    // MARK: - 轴视口手势（viewport 驱动；轴向由 zoomAxisMode 决定）
    /// 捏合缩放视口：增量倍率连续复合，捏合中心（跟手锚点）保持不动。
    /// zoomAxisMode：`.x` 只缩 X 轴、`.y` 只缩 Y 轴、`.xy` 两轴同时（锚点取捏合中心分量）。
    @objc private func onPinch(_ gr: UIPinchGestureRecognizer) {
        guard isZoomEnabled, let zoomable = xAxisZoomable else { return }

        switch gr.state {
        case .began:
            finishEntranceAnimationIfNeeded()
            lastPinchScale = 1.0
        case .changed:
            // 增量倍率 = 本帧 scale / 上帧 scale：连续复合即手势累计效果，
            // 且跨手势天然续接（第二次捏合从当前视口继续，无快照、无漂移）。
            let factor = gr.scale / max(lastPinchScale, 1e-9)
            lastPinchScale = gr.scale
            let loc = gr.location(in: self)
            if zoomAxisMode.includesX {
                zoomable.zoomXAxis(factor: factor, anchorScreenX: loc.x)
            }
            if zoomAxisMode.includesY, let yz = yAxisZoomable {
                yz.zoomYAxis(factor: factor, anchorScreenY: loc.y)
            }
        default:
            break
        }
    }

    /// 单指拖拽手势（轴向由 zoomAxisMode 决定）：
    /// - 图表处于全量视口（未缩放/平移过）且开启滑动选中 → 「滑动选中」模式：手指划过逐个高亮数据点；
    /// - 否则 → 拖移视口（橡皮筋可越界），松手时惯性减速（仅 X 轴）/ 回弹。
    @objc private func onPan(_ gr: UIPanGestureRecognizer) {
        guard isZoomEnabled, let zoomable = xAxisZoomable else { return }

        switch gr.state {
        case .began:
            finishEntranceAnimationIfNeeded()
            stopDeceleration()
            lastPanTranslation = .zero
            // 全量视口时拖视口无意义（clamp 后原地不动）→ 自动切换为滑动选中
            // （参与缩放的轴向全部处于全量才视为"全量视图"）
            var fullyZoomedOut = true
            if zoomAxisMode.includesX {
                fullyZoomedOut = zoomable.xAxisZoomScale <= 1.0001
            }
            if fullyZoomedOut, zoomAxisMode.includesY, let yz = yAxisZoomable {
                fullyZoomedOut = yz.yAxisZoomScale <= 1.0001
            }
            panIsHighlightMode = isHighlightPerDragEnabled && fullyZoomedOut
        case .changed:
            if panIsHighlightMode {
                let loc = gr.location(in: self)
                if !handleSharedIfActive(at: loc, gesture: .drag) {
                    handleHit(at: loc, gesture: .drag)
                }
                return
            }
            hideCrosshair()   // 拖视口：准线所属视口已失效
            let total = gr.translation(in: self)
            let dx = total.x - lastPanTranslation.x
            let dy = total.y - lastPanTranslation.y
            lastPanTranslation = total
            if dx != 0, zoomAxisMode.includesX {
                zoomable.panXAxis(screenDeltaX: dx, allowsRubberBand: isRubberBandEnabled)
            }
            if dy != 0, zoomAxisMode.includesY, let yz = yAxisZoomable {
                yz.panYAxis(screenDeltaY: dy, allowsRubberBand: isRubberBandEnabled)
            }
        case .ended, .cancelled:
            guard !panIsHighlightMode else { return }
            if isRubberBandEnabled { reboundIfNeeded() }   // 越界 → 回弹优先（不叠加惯性）
            if !isRebounding, isDragDecelerationEnabled, gr.state == .ended,
               zoomAxisMode.includesX {
                startDeceleration(zoomable, velocity: gr.velocity(in: self).x)
            }
        default:
            break
        }
    }

    /// 本次松手是否正在回弹（回弹期间不再叠加 X 轴惯性）。
    private var isRebounding = false

    /// 橡皮筋回弹：把越界轴的窗口 ease-out 插值回全量域内的钳制位置。
    /// X/Y 可同时越界（.xy 模式斜拖）——两轴共用一段动画逐帧插值。
    private func reboundIfNeeded() {
        let zoomable = xAxisZoomable
        let yz = yAxisZoomable
        let xOver = zoomable?.isXAxisOvershooting == true
        let yOver = yz?.isYAxisOvershooting == true
        guard xOver || yOver, let zoomable else { return }

        // 各越界轴的目标窗口：越界侧贴回全量域边缘（span 保持不变）
        func target<V: FloatingPoint>(of start: ClosedRange<V>, full: ClosedRange<V>) -> ClosedRange<V> {
            let span = start.upperBound - start.lowerBound
            let targetLo: V = start.lowerBound < full.lowerBound
                ? full.lowerBound
                : min(start.lowerBound, full.upperBound - span)
            return targetLo...(targetLo + span)
        }
        let xStart = xOver ? zoomable.xAxisViewport : nil
        let xTarget = xOver ? target(of: zoomable.xAxisViewport, full: zoomable.fullXAxisDomain) : nil
        let yStart = yOver ? yz!.yAxisViewport : nil
        let yTarget = yOver ? target(of: yz!.yAxisViewport, full: yz!.fullYAxisDomain) : nil

        // 插值用**绝对进度**（setXAxisViewport 是绝对语义）：曾误用逐帧增量 t 配绝对锚点，
        // 每帧都只从起点挪一小步、互不累积，最后一帧 t≈0 → 视口停在越界处（回弹从未生效）。
        isRebounding = true
        decelAnimator.startEaseOut(duration: 0.25,
            handler: { progress in
                if let s = xStart, let tg = xTarget {
                    let lo = s.lowerBound + (tg.lowerBound - s.lowerBound) * progress
                    zoomable.setXAxisViewport(lo...(lo + (s.upperBound - s.lowerBound)))
                }
                if let s = yStart, let tg = yTarget, let yz {
                    let lo = s.lowerBound + (tg.lowerBound - s.lowerBound) * progress
                    yz.setYAxisViewport(lo...(lo + (s.upperBound - s.lowerBound)))
                }
            },
            completion: { [weak self] in
                self?.isRebounding = false
                self?.stopDeceleration()
            })
    }

    /// 惯性减速：松手速度经指数衰减继续平移视口（ease-out 驱动，视口顶到边界即停）。
    private func startDeceleration(_ zoomable: HYMChartXAxisZoomable, velocity: CGFloat) {
        let speedThreshold: CGFloat = 200          // px/s 以下视为轻拖，不减速
        guard velocity > speedThreshold || velocity < -speedThreshold else { return }
        let timeConstant: Double = 0.35            // 衰减时间常数（秒）：总位移 ≈ v₀ × τ
        let totalDistance = Double(velocity) * timeConstant
        lastDecelProgress = 0
        decelAnimator.startEaseOut(duration: 0.7,
            handler: { [weak self] progress in
                guard let self else { return }
                let delta = totalDistance * (progress - self.lastDecelProgress)
                self.lastDecelProgress = progress
                let before = zoomable.xAxisViewport
                zoomable.panXAxis(screenDeltaX: CGFloat(delta))
                // 视口已顶到边界（无变化）→ 提前结束
                if zoomable.xAxisViewport == before {
                    self.decelAnimator.stop()
                }
            },
            completion: { [weak self] in self?.stopDeceleration() })
    }

    /// 停止惯性/回弹（新手势开始、configure 重置时调用）。
    private func stopDeceleration() {
        decelAnimator.stop()
        isRebounding = false
    }

    /// 双击重置视口到全量数据（X/Y 两轴一起重置）。
    @objc private func onDoubleTap(_ gr: UITapGestureRecognizer) {
        guard isZoomEnabled, xAxisZoomable != nil else { return }
        resetViewport()
    }

    /// 手势开始前的统一收尾：
    /// 1. 入场动画仍在播放则立即定格到完成态——**全部包进禁动画事务瞬变**。
    ///    opacity 若停在中间值（动画被打断），事务外恢复 1 会触发 0.25s 隐式
    ///    渐显动画，整个图表半透明渐变，视觉即"手势开始瞬间的当前状态残影"；
    /// 2. 立即隐藏 tooltip（弹窗锚点属于旧视口；带动画淡出会在原位悬 0.15s，
    ///    与平移中的内容错开形成"残影"——必须无动画瞬隐）。
    private func finishEntranceAnimationIfNeeded() {
        animator.stop()
        decelAnimator.stop()
        hideCrosshair()
        pendingAnimation = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        renderer.animatableLayers.forEach { $0.opacity = 1 }
        renderer.updateEntranceAnimation(progress: 1)
        CATransaction.commit()
        tooltipController?.hide(animated: false)
    }

    // MARK: - Tooltip
    private func ensureTooltipController() -> HYMChartTooltipController {
        if let c = tooltipController { return c }
        let c = HYMChartTooltipController(host: self, theme: tooltipTheme)
        tooltipController = c
        return c
    }

    /// 按文本模板组装弹窗内容：target 提供结构化行 + options 配置（表头/后缀/小数位）；
    /// 模板未配置或 target 未实现数据源 → 回落 target.tooltipText 固定格式。
    private func formattedTooltipText(for target: HYMChartHitTarget) -> String? {
        guard !tooltipTextOptions.isDefault,
              let dataSource = target as? HYMChartTooltipDataSource else {
            return target.tooltipText
        }
        var lines: [String] = []
        if let context = dataSource.tooltipContextText { lines.append(context) }
        if let header = tooltipTextOptions.header, let key = dataSource.tooltipHeaderKey {
            lines.append(header.replacingOccurrences(of: "{key}", with: key))
        }
        for row in dataSource.tooltipRows {
            var text = "\(row.name): "
                + HYMChartTooltipTextOptions.formatValue(row.value, decimals: tooltipTextOptions.valueDecimals)
            if let suffix = tooltipTextOptions.valueSuffix { text += suffix }
            if row.isSecondaryAxis { text += " (右轴)" }
            lines.append(text)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// 命中后更新 tooltip：开关关 / 无文本 / 无锚点 → 隐藏；否则显示。
    /// - Parameter animated: false = 已可见的跟手移动更新（滑动选中），不重播淡入。
    private func updateTooltip(for target: HYMChartHitTarget?, animated: Bool = true) {
        if onHitLocated != nil { tooltipController?.hide(); return }   // 外部接管弹窗 → 跳过内置
        guard showsTooltipOnHit else { tooltipController?.hide(); return }
        guard let target,
              let text = formattedTooltipText(for: target),
              let anchor = renderer.tooltipAnchor(for: target) else {
            tooltipController?.hide()
            return
        }
        ensureTooltipController().show(anchor: anchor.frame, text: text,
                                       in: bounds, preferred: anchor.preferredPlacements,
                                       animated: animated)
    }

    deinit {
        animator.stop()                       // 打破 displayLink ↔ animator 循环
        decelAnimator.stop()
        tooltipController?.removeFromSuperview()
        renderer.unmount(from: self)          // 清理 layer/子视图
    }
}
