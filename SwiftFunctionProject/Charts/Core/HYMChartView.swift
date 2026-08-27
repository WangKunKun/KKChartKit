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
        panGesture.isEnabled = isZoomEnabled
      }
    }

    /// 最小缩放级别（防止缩放过小，默认 1.0 = 100%）
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
    private lazy var zoomGesture = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
    private lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
    private lazy var doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap(_:)))

    /// 平移偏移量（内容滚动）
    private var contentOffset: CGPoint = .zero

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

    // MARK: - 缩放手势（物理缩放）
    @objc private func onPinch(_ gr: UIPinchGestureRecognizer) {
        guard isZoomEnabled else { return }

        switch gr.state {
        case .began:
            zoomAnchorPoint = gr.location(in: self)
            currentZoomScale = 1.0

        case .changed:
            let scale = gr.scale
            // 限制缩放范围
            let boundedScale = min(max(scale, minimumZoomScale), maximumZoomScale)

            // 应用物理缩放（以锚点为中心）
            applyPhysicalZoom(scale: boundedScale, anchor: zoomAnchorPoint)

        case .ended, .cancelled:
            // 更新当前缩放比例
            currentZoomScale = gr.scale

        default:
            break
        }
    }

    /// 应用物理缩放（使用 UIView transform）
    private func applyPhysicalZoom(scale: CGFloat, anchor: CGPoint) {
        // 计算缩放后的新 scale
        let newScale = scale

        // 计算锚点相对于视图中心的位置
        let anchorRelativeToCenter = CGPoint(
            x: anchor.x - bounds.midX,
            y: anchor.y - bounds.midY
        )

        // 计算缩放后的位置调整（保持锚点不动）
        let positionAdjustment = CGPoint(
            x: anchorRelativeToCenter.x * (newScale - 1.0) / newScale,
            y: anchorRelativeToCenter.y * (newScale - 1.0) / newScale
        )

        // 应用视图级别的 transform（缩放整个图表）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DMakeScale(newScale, newScale, 1.0)
        layer.position = CGPoint(
            x: bounds.midX - positionAdjustment.x,
            y: bounds.midY - positionAdjustment.y
        )
        CATransaction.commit()

        // 通过 renderer 应用内容平移
        renderer.applyPhysicalZoomAndPan(scale: newScale, contentOffset: contentOffset, bounds: bounds)

        currentZoomScale = newScale
    }

    // MARK: - 平移手势
    @objc private func onPan(_ gr: UIPanGestureRecognizer) {
        guard isZoomEnabled else { return }

        switch gr.state {
        case .began:
            // 记录起始位置
            break

        case .changed:
            let translation = gr.translation(in: self)

            // 只允许X轴平移（左右滑动）
            // 计算缩放调整后的平移量
            let adjustedTranslation = CGPoint(
                x: translation.x / currentZoomScale,
                y: 0  // Y轴不平移
            )

            // 更新contentOffset
            contentOffset = CGPoint(
                x: max(0, adjustedTranslation.x),
                y: 0
            )

            // 应用平移（只平移X轴内容）
            applyPan()

        case .ended, .cancelled:
            break

        default:
            break
        }
    }

    /// 应用平移（内容滚动）
    private func applyPan() {
        // 限制平移范围（不能平移超出内容）
        let maxOffset = max(0, (bounds.width * currentZoomScale) - bounds.width)
        contentOffset.x = min(contentOffset.x, maxOffset)

        // 通过 renderer 应用平移
        renderer.applyPhysicalZoomAndPan(scale: currentZoomScale, contentOffset: contentOffset, bounds: bounds)
    }

    /// 双击重置缩放和平移
    @objc private func onDoubleTap(_ gr: UITapGestureRecognizer) {
        guard isZoomEnabled else { return }

        // 重置缩放和平移状态
        currentZoomScale = 1.0
        contentOffset = .zero

        // 通过 renderer 重置缩放和平移
        renderer.applyPhysicalZoomAndPan(scale: 1.0, contentOffset: .zero, bounds: bounds)

        // 重置视图层的 transform
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DIdentity
        layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
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
