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
public final class HYMChartView<Renderer: HYMChartRenderer>: UIView {

    // MARK: - 状态
    private var model: Renderer.Model?
    private var theme: Renderer.Theme?
    private var pendingAnimation = false
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

    /// 缩放手势启用（默认 false）。仅 X 轴（宽度方向）参与缩放/平移，
    /// Y 轴视口始终由数据驱动；renderer 需实现 `HYMChartXAxisZoomable`。
    public var isZoomEnabled: Bool = false {
      didSet {
        zoomGesture.isEnabled = isZoomEnabled
        panGesture.isEnabled = isZoomEnabled
        doubleTapGesture.isEnabled = isZoomEnabled
      }
    }

    /// 最小缩放级别。当前实现固定语义 1.0（不可缩小超过全量数据），预留扩展。
    public var minimumZoomScale: CGFloat = 1.0
    /// 最大缩放级别（默认 10.0）。同步为 renderer 的最小可视 X 跨度。
    public var maximumZoomScale: CGFloat = 10.0 {
      didSet { xAxisZoomable?.maximumXAxisZoomScale = maximumZoomScale }
    }
    /// 最小可见类目数（放大下限，默认 12；≥ 2）。与 `maximumZoomScale` 共同约束，取更宽松者
    /// （小数据量按倍数防过度放大，大数据量按类目数保证"放大到底能看清单柱"）。
    public var minimumVisibleCategories: Int = 12 {
      didSet { xAxisZoomable?.minimumXAxisCategories = max(2, minimumVisibleCategories) }
    }

    // MARK: - 手势体验增强（参照 Charts/AAChartKit 交互惯例）
    /// 拖拽松手后的惯性减速（默认开）。
    public var isDragDecelerationEnabled: Bool = true
    /// 全量视口（未缩放）时拖拽自动变为「滑动选中」：手指划过逐个高亮数据点（默认开）。
    /// 已缩放/平移过的图表拖拽仍是移动视口。
    public var isHighlightPerDragEnabled: Bool = true
    /// 把视口拖出边界时的橡皮筋越界 + 松手回弹（默认开）。
    public var isRubberBandEnabled: Bool = true

    /// 命中弹窗的「内容 view」提供者（外部自定义弹窗的便利模式）。
    ///
    /// 设了它：SDK 命中时调用获取内容 view，套统一外壳(背景/圆角/箭头)，
    /// 用 `HYMChartTooltipGeometry` 智能定位(边界避让) + 显隐动画显示；未命中自动隐藏。
    /// 设了它 → 跳过 `onHitLocated` 与内置 text tooltip（三层 fallback 最高优先级）。
    /// 内容 view 应能报告尺寸(`intrinsicContentSize` 或 `sizeThatFits(_:)`)。
    public var popupContentProvider: ((HYMChartHitContext) -> UIView?)?
    /// 弹窗控制器（首次显示时懒创建）。
    private var tooltipController: HYMChartTooltipController?

    // MARK: - X 轴视口手势状态
    /// 当前 renderer 若实现 `HYMChartXAxisZoomable`（轴系图表）则支持 X 视口手势；
    /// 雷达图/热力图等未实现协议时所有手势自动无效。
    private var xAxisZoomable: HYMChartXAxisZoomable? { renderer as? HYMChartXAxisZoomable }
    /// 捏合增量基准（上一帧 gr.scale；增量比值连续复合 = 手势累计，跨手势天然续接）。
    private var lastPinchScale: CGFloat = 1.0
    /// 平移增量基准（上一帧累计 translation.x，差值即本次增量，无累计漂移）。
    private var lastPanTranslationX: CGFloat = 0
    /// 当前 pan 的模式（拖视口 / 全量视图下滑动选中）。
    private var panIsHighlightMode = false
    /// 惯性减速/回弹动画专用（与入场动画的 animator 分开，互不干扰）。
    private let decelAnimator = HYMChartValueAnimator()
    /// 减速消费进度（上一帧 ease-out 进度，差值即本帧位移占比）。
    private var lastDecelProgress: Double = 0

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
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
        addGestureRecognizer(zoomGesture)
        addGestureRecognizer(panGesture)
        addGestureRecognizer(doubleTapGesture)
        doubleTapGesture.numberOfTapsRequired = 2
        zoomGesture.isEnabled = isZoomEnabled
        panGesture.isEnabled = isZoomEnabled
        doubleTapGesture.isEnabled = isZoomEnabled
    }

    // MARK: - 公开 API
    /// 配置并刷新（model + theme 一起传入）。
    ///
    /// 外部数据/主题变化会重置 X 轴视口到全量（手势缩放状态不跨数据更新保留）。
    public func configure(model: Renderer.Model, theme: Renderer.Theme) {
        stopDeceleration()
        self.model = model
        self.theme = theme
        xAxisZoomable?.resetXAxisViewport()
        setNeedsLayout()
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
        renderer.render(model: model, theme: theme,
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

    // MARK: - 触摸命中（tap 与拖拽滑动选中共用）
    @objc private func onTap(_ gr: UITapGestureRecognizer) {
        handleHit(at: gr.location(in: self), gesture: .tap)
    }

    /// 命中分发：选中 + onHit 回调 + 三层弹窗 fallback（popup > onHitLocated > 内置 tooltip）。
    private func handleHit(at point: CGPoint, gesture: HYMChartGesture) {
        let target = renderer.hitTest(point)
        renderer.applySelection(target)

        if let target {
            onHit?(target, gesture)                      // 始终：命中事件通知

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
                onHitLocated?(ctx, gesture)
                tooltipController?.hide()
            } else {                                   // ③ 内置 text tooltip
                updateTooltip(for: target)
            }
        } else {
            // 未命中：按激活模式镜像处理（popup 模式不触发 onHitLocated，与命中分支对称）
            tooltipController?.hide()
            if popupContentProvider == nil, onHitLocated != nil {
                onHitLocated?(nil, gesture)
            }
        }
    }

    // MARK: - X 轴视口手势（viewport 驱动：只改 X 视口，Y 轴恒定）
    /// 捏合缩放 X 视口：增量倍率连续复合，捏合中心（跟手锚点）保持不动。
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
            zoomable.zoomXAxis(factor: factor, anchorScreenX: gr.location(in: self).x)
        default:
            break
        }
    }

    /// 单指左右手势：
    /// - 图表处于全量视口（未缩放/平移过）且开启滑动选中 → 「滑动选中」模式：手指划过逐个高亮数据点；
    /// - 否则 → 拖移 X 视口（橡皮筋可越界），松手时惯性减速 / 回弹。
    @objc private func onPan(_ gr: UIPanGestureRecognizer) {
        guard isZoomEnabled, let zoomable = xAxisZoomable else { return }

        switch gr.state {
        case .began:
            finishEntranceAnimationIfNeeded()
            stopDeceleration()
            lastPanTranslationX = 0
            // 全量视口时拖视口无意义（clamp 后原地不动）→ 自动切换为滑动选中
            let fullyZoomedOut = zoomable.xAxisZoomScale <= 1.0001
            panIsHighlightMode = isHighlightPerDragEnabled && fullyZoomedOut
        case .changed:
            if panIsHighlightMode {
                handleHit(at: gr.location(in: self), gesture: .drag)
                return
            }
            let total = gr.translation(in: self).x
            let delta = total - lastPanTranslationX
            lastPanTranslationX = total
            guard delta != 0 else { return }
            zoomable.panXAxis(screenDeltaX: delta, allowsRubberBand: isRubberBandEnabled)
        case .ended, .cancelled:
            guard !panIsHighlightMode else { return }
            if isRubberBandEnabled, zoomable.isXAxisOvershooting {
                reboundXAxis(zoomable)         // 越界 → 回弹优先（不叠加惯性）
            } else if isDragDecelerationEnabled, gr.state == .ended {
                startDeceleration(zoomable, velocity: gr.velocity(in: self).x)
            }
        default:
            break
        }
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

    /// 橡皮筋回弹：从当前越界视口 ease-out 插值回全量域内的钳制位置。
    private func reboundXAxis(_ zoomable: HYMChartXAxisZoomable) {
        let full = zoomable.fullXAxisDomain
        let start = zoomable.xAxisViewport
        let span = start.upperBound - start.lowerBound
        // 目标：越界侧贴回全量域边缘
        let targetLo: Double
        if start.lowerBound < full.lowerBound { targetLo = full.lowerBound }
        else { targetLo = min(start.lowerBound, full.upperBound - span) }
        lastDecelProgress = 0
        decelAnimator.startEaseOut(duration: 0.25,
            handler: { [weak self] progress in
                guard let self else { return }
                let t = progress - self.lastDecelProgress
                self.lastDecelProgress = progress
                let lo = start.lowerBound + (targetLo - start.lowerBound) * t
                zoomable.setXAxisViewport(lo...(lo + span))
            },
            completion: { [weak self] in self?.stopDeceleration() })
    }

    /// 停止惯性/回弹（新手势开始、configure 重置时调用）。
    private func stopDeceleration() {
        decelAnimator.stop()
    }

    /// 双击重置 X 视口到全量数据。
    @objc private func onDoubleTap(_ gr: UITapGestureRecognizer) {
        guard isZoomEnabled, let zoomable = xAxisZoomable else { return }
        zoomable.resetXAxisViewport()
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

    /// 命中后更新 tooltip：开关关 / 无文本 / 无锚点 → 隐藏；否则显示。
    private func updateTooltip(for target: HYMChartHitTarget?) {
        if onHitLocated != nil { tooltipController?.hide(); return }   // 外部接管弹窗 → 跳过内置
        guard showsTooltipOnHit else { tooltipController?.hide(); return }
        guard let target,
              let text = target.tooltipText,
              let anchor = renderer.tooltipAnchor(for: target) else {
            tooltipController?.hide()
            return
        }
        ensureTooltipController().show(anchor: anchor.frame, text: text,
                                       in: bounds, preferred: anchor.preferredPlacements)
    }

    deinit {
        animator.stop()                       // 打破 displayLink ↔ animator 循环
        decelAnimator.stop()
        tooltipController?.removeFromSuperview()
        renderer.unmount(from: self)          // 清理 layer/子视图
    }
}
