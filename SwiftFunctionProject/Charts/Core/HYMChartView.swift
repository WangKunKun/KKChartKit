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
        renderer.applySelection(target)        // 命中→选中，未命中→取消（通用）
        if let target { onHit?(target, .tap) }
    }

    deinit {
        animator.stop()              // 打破 displayLink ↔ animator 循环
        renderer.unmount(from: self) // 清理 layer/子视图
    }
}
