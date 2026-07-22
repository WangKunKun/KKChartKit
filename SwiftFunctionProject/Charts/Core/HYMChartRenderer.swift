import UIKit

/// 渲染上下文（容器在 layoutSubviews 时提供给 Renderer）
public struct HYMChartRenderContext {
    public let bounds: CGRect
    public let center: CGPoint
    public init(bounds: CGRect, center: CGPoint) {
        self.bounds = bounds
        self.center = center
    }
}

/// 图表渲染器契约：给定 model/theme/context，重建 layer 子树与子视图。
/// 具体图表（如 RadarChartRenderer）实现此协议；通用容器 HYMChartView 注入使用。
public protocol HYMChartRenderer: AnyObject {
    /// 无参构造（供泛型容器 `Renderer()` 实例化）
    init()

    associatedtype Model: HYMChartModel
    associatedtype Theme: HYMChartTheme

    /// 挂载渲染内容（layer 子树 + 子视图）到容器；容器 init 后调一次
    func mount(into view: UIView)
    /// 卸载渲染内容（容器销毁前调）
    func unmount(from view: UIView)
    /// 重建全部 layer 子树 + 子视图（数据/主题/布局变化时由容器调用）
    func render(model: Model, theme: Theme, context: HYMChartRenderContext)

    /// 参加入场动画的 layer（容器统一驱动 scale + opacity）
    var animatableLayers: [CALayer] { get }

    /// 入场动画每帧回调（容器驱动 DisplayLink，传归一化且已 ease 的进度 0...1）。
    /// Renderer 据此更新自身需要数值滚动的子视图（如中心分数 label）。
    func updateEntranceAnimation(progress: Double)

    // —— 交互能力（声明为 requirement，保证 override 走 witness table 可靠动态派发）——
    /// 命中测试：坐标 → 语义目标；默认 nil
    func hitTest(_ point: CGPoint) -> HYMChartHitTarget?
    /// 选中态视觉反馈（预留）；默认空
    func applySelection(_ target: HYMChartHitTarget?)
    /// 数值动画目标（如中心分数）；默认 nil
    var centerScoreTarget: Double? { get }
}

/// 默认实现：可交互为可选；不关心的图表无需实现这些方法
public extension HYMChartRenderer {
    func hitTest(_ point: CGPoint) -> HYMChartHitTarget? { nil }
    func applySelection(_ target: HYMChartHitTarget?) {}
    var centerScoreTarget: Double? { nil }
    func updateEntranceAnimation(progress: Double) {}
}
