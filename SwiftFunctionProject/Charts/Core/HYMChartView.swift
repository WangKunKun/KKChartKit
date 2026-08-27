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

    /// 缩放手势启用（默认 false，阶段 4 功能）
    public var isZoomEnabled: Bool = false {
      didSet {
        zoomGesture.isEnabled = isZoomEnabled
      }
    }

    /// 最小缩放级别（防止缩放过小，默认 1.0 = 100%，不允许缩小到小于原始视图）
    public var minimumZoomScale: CGFloat = 1.0
    /// 最大缩放级别（防止缩放过大，默认 10.0 = 1000%）
    public var maximumZoomScale: CGFloat = 10.0

    /// 命中弹窗的「内容 view」提供者（外部自定义弹窗的便利模式）。
    ///
    /// 设了它：SDK 命中时调用获取内容 view，套统一外壳(背景/圆角/箭头)，
    /// 用 `HYMChartTooltipGeometry` 智能定位(边界避让) + 显隐动画显示；未命中自动隐藏。
    /// 设了它 → 跳过 `onHitLocated` 与内置 text tooltip（三层 fallback 最高优先级）。
    /// 内容 view 应能报告尺寸(`intrinsicContentSize` 或 `sizeThatFits(_:)`)。
    public var popupContentProvider: ((HYMChartHitContext) -> UIView?)?
    /// 弹窗控制器（首次显示时懒创建）。
    private var tooltipController: HYMChartTooltipController?

    // MARK: - 缩放状态
    private var currentZoomScale: CGFloat = 1.0
    private var zoomAnchorPoint: CGPoint = .zero
    private var zoomBaseViewport: CartesianViewport?  // 手势开始时的viewport
    private lazy var zoomGesture = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
    private lazy var doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap(_:)))

    /// 缩放后的自定义 viewport（nil = 使用 renderer 自动计算的 viewport）
    private var customViewport: CartesianViewport?

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
        addGestureRecognizer(doubleTapGesture)
        doubleTapGesture.numberOfTapsRequired = 2
        zoomGesture.isEnabled = isZoomEnabled
        doubleTapGesture.isEnabled = isZoomEnabled
    }

    // MARK: - 公开 API
    /// 配置并刷新（model + theme 一起传入）
    public func configure(model: Renderer.Model, theme: Renderer.Theme) {
        self.model = model
        self.theme = theme
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
            completion: { })
    }

    // MARK: - 触摸命中
    @objc private func onTap(_ gr: UITapGestureRecognizer) {
        let p = gr.location(in: self)
        let target = renderer.hitTest(p)
        renderer.applySelection(target)

        if let target {
            onHit?(target, .tap)                       // 始终：命中事件通知

            let ctx = HYMChartHitContext(
                target: target,
                frame: renderer.hitFrame(for: target) ?? .zero,
                location: p)

            if popupContentProvider != nil {           // ① popup 模式（最高优先）
                if let cv = popupContentProvider?(ctx),
                   let anchor = renderer.tooltipAnchor(for: target) {
                    ensureTooltipController().show(anchor: anchor.frame, contentView: cv,
                                                  in: bounds, preferred: anchor.preferredPlacements)
                } else {
                    tooltipController?.hide()
                }
            } else if onHitLocated != nil {            // ② onHitLocated 外部全权
                onHitLocated?(ctx, .tap)
                tooltipController?.hide()
            } else {                                   // ③ 内置 text tooltip
                updateTooltip(for: target)
            }
        } else {
            // 未命中：按激活模式镜像处理（popup 模式不触发 onHitLocated，与命中分支对称）
            tooltipController?.hide()
            if popupContentProvider == nil, onHitLocated != nil {
                onHitLocated?(nil, .tap)
            }
        }
    }

    // MARK: - 缩放手势
    @objc private func onPinch(_ gr: UIPinchGestureRecognizer) {
        guard isZoomEnabled else { return }

        switch gr.state {
        case .began:
            zoomAnchorPoint = gr.location(in: self)
            // 记录手势开始时的viewport作为基准
            if let renderer = renderer as? CartesianRendererBase<CartesianChartTheme> {
                zoomBaseViewport = customViewport ?? renderer.currentViewport
            }
            currentZoomScale = 1.0

        case .changed:
            let scale = gr.scale
            // 限制缩放范围，但允许从放大状态缩小回来
            let boundedScale = min(max(scale, minimumZoomScale), maximumZoomScale)

            if let renderer = renderer as? CartesianRendererBase<CartesianChartTheme>,
               let baseViewport = zoomBaseViewport {
                // 基于基准viewport和手势scale计算新的viewport
                applyZoom(scale: boundedScale, baseViewport: baseViewport, anchor: zoomAnchorPoint)
            }

        case .ended, .cancelled:
            // 更新当前缩放比例
            currentZoomScale = gr.scale
            // 更新基准viewport为当前viewport，为下次缩放做准备
            if let renderer = renderer as? CartesianRendererBase<CartesianChartTheme> {
                zoomBaseViewport = customViewport ?? renderer.currentViewport
            }

        default:
            break
        }
    }

    /// 应用缩放到 viewport（以锚点为中心，仅缩放 X 轴）
    /// - Parameters:
    ///   - scale: 手势的缩放比例（相对于手势开始时）
    ///   - baseViewport: 手势开始时的viewport（基准）
    ///   - anchor: 缩放锚点的屏幕坐标
    private func applyZoom(scale: CGFloat, baseViewport: CartesianViewport, anchor: CGPoint) {
        guard let renderer = renderer as? CartesianRendererBase<CartesianChartTheme> else { return }

        // 1. 将锚点从屏幕坐标转换为数据坐标（基于基准viewport）
        let plotFrame = renderer.currentPlotFrame
        let anchorData = CartesianGeometry.value(
            at: anchor,
            viewport: baseViewport,
            plotFrame: plotFrame
        )

        // 2. 只缩放 X 轴（类目轴），Y 轴保持不变
        let oldXSpan = baseViewport.xSpan
        let newXSpan = oldXSpan / scale

        // 3. 计算新的 X 轴边界（保持锚点位置不变）
        let xRatio = (anchorData.x - baseViewport.xMin) / oldXSpan
        let newXMin = anchorData.x - newXSpan * xRatio
        let newXMax = anchorData.x + newXSpan * (1 - xRatio)

        // 4. 创建新 viewport（Y 轴保持原值）
        let newViewport = CartesianViewport(
            xMin: newXMin,
            xMax: newXMax,
            yMin: baseViewport.yMin,  // Y 轴不变
            yMax: baseViewport.yMax   // Y 轴不变
        )

        // 5. 保存自定义 viewport 并重新渲染
        customViewport = newViewport
        renderer.zoomToViewport(newViewport)

        // 6. 强制重新渲染
        setNeedsLayout()
    }

    /// 双击重置缩放
    @objc private func onDoubleTap(_ gr: UITapGestureRecognizer) {
        guard isZoomEnabled else { return }
        guard let renderer = renderer as? CartesianRendererBase<CartesianChartTheme> else { return }

        // 重置缩放状态
        customViewport = nil
        renderer.resetZoom()
        currentZoomScale = 1.0

        // 强制重新渲染
        setNeedsLayout()
        layoutIfNeeded()  // 立即应用重置
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
        tooltipController?.removeFromSuperview()
        renderer.unmount(from: self)          // 清理 layer/子视图
    }
}
