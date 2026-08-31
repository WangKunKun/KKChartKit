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

/// 弹窗锚点（绘图驱动）：锚点 frame（view 坐标系）+ 偏好放置方向。
public struct HYMChartTooltipAnchor {
    public var frame: CGRect
    public var preferredPlacements: [HYMChartTooltipPlacement]
    public init(frame: CGRect, preferredPlacements: [HYMChartTooltipPlacement]) {
        self.frame = frame
        self.preferredPlacements = preferredPlacements
    }
}

/// 图表渲染器契约：给定 model/theme/context，重建 layer 子树与子视图。
/// 具体图表（如 RadarChartRenderer）实现此协议；通用容器 HYMChartView 注入使用。
///
/// 注意：本协议只承载**所有图表通用**的能力。某类图表特有的数据/动画
/// （如雷达图「中心分数」）不得在此定义，应放进该图表特有的 Model/Renderer。
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

    /// 入场动画逐帧回调（容器驱动 DisplayLink，传归一化且已 ease 的进度 0...1）。
    /// Renderer 据此更新自身需要的逐帧子视图动画（通用；具体含义由各图表自定义）。
    func updateEntranceAnimation(progress: Double)

    // —— 交互能力（声明为 requirement，保证 override 走 witness table 可靠动态派发）——
    /// 命中测试：坐标 → 语义目标；默认 nil
    func hitTest(_ point: CGPoint) -> HYMChartHitTarget?
    /// 选中态视觉反馈（预留）；默认空
    func applySelection(_ target: HYMChartHitTarget?)
    /// 弹窗锚点：命中目标 → 锚点（绘图驱动）；默认 nil
    func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor?
    /// 命中单元的几何 frame（view 坐标系），供外部自定义弹窗定位；独立于 tooltip 开关。默认 nil。
    func hitFrame(for target: HYMChartHitTarget) -> CGRect?
}

/// 默认实现：交互与逐帧回调为可选；不关心的图表无需实现这些方法
public extension HYMChartRenderer {
    func hitTest(_ point: CGPoint) -> HYMChartHitTarget? { nil }
    func applySelection(_ target: HYMChartHitTarget?) {}
    func updateEntranceAnimation(progress: Double) {}
    func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? { nil }
    func hitFrame(for target: HYMChartHitTarget) -> CGRect? { nil }
}

/// X 轴视口缩放能力（轴系图表专属；雷达图/热力图等不实现即自动不支持）。
///
/// 交互模型：**只有 X 轴（宽度方向）参与缩放/平移，Y 轴视口始终由数据驱动**。
/// 通用容器 `HYMChartView` 识别手势后以增量方式调用本协议；
/// 实现方（`CartesianRendererBase`）只修改 viewport 的 x 域并整体重布局，
/// 由此 Y 轴刻度/横网格/零轴天然固定，柱体/折线/竖网格/X 标签天然跟随。
public protocol HYMChartXAxisZoomable: HYMChartRenderer {
    /// 当前 X 轴视口（值域）；未缩放时等于 `fullXAxisDomain`。
    var xAxisViewport: ClosedRange<Double> { get }
    /// 全量 X 域（缩放/平移的 clamp 边界）。
    var fullXAxisDomain: ClosedRange<Double> { get }
    /// 当前 X 轴缩放倍率（全量跨度 / 当前跨度；未缩放时 1）。
    var xAxisZoomScale: CGFloat { get }
    /// 最大放大倍数（与 `minimumXAxisCategories` 共同约束放大下限，取更保守者）。
    var maximumXAxisZoomScale: CGFloat { get set }
    /// 最小可见类目数（放大下限：视口跨度不小于该数量的类目；默认 12）。
    /// 固定倍数上限对大数据量无意义（1440 点 × 10 倍仍一屏 144 类目），
    /// 按类目数约束才能保证"放大到底一定能看清单根柱子"。
    var minimumXAxisCategories: Int { get set }

    /// 增量缩放 X 视口。
    ///
    /// 每次调用以**当前视口**为基础乘 `factor`（>1 放大、<1 缩小），
    /// `anchorScreenX`（view 坐标系）处的数据点保持在原地不动——
    /// 连续调用的复合即累计效果，调用方无需维护快照。
    /// - Parameters:
    ///   - factor: 本次增量倍率（UIPinchGestureRecognizer 两帧间 scale 的比值）
    ///   - anchorScreenX: 缩放锚点的屏幕 x（通常取捏合中心）
    func zoomXAxis(factor: CGFloat, anchorScreenX: CGFloat)

    /// 增量平移 X 视口。
    ///
    /// - Parameter screenDeltaX: 本次屏幕位移（px，右滑为正 → 视口左移看后面数据）。
    ///   与 `zoomXAxis` 同为增量语义，连续调用自动复合。
    func panXAxis(screenDeltaX: CGFloat)

    /// 增量平移 X 视口（橡皮筋变体）。
    ///
    /// `allowsRubberBand` 为 true 时允许把视口拖出全量域一段距离（阻尼衰减，
    /// 越界余量上限为全量跨度的 25%），供松手回弹；false 与 `panXAxis` 一致。
    func panXAxis(screenDeltaX: CGFloat, allowsRubberBand: Bool)

    /// 直接设置 X 视口（值域）。
    ///
    /// 钳制到全量域 ± 橡皮筋余量内。用于程序化定位与回弹动画的逐帧插值，
    /// 常规手势请用增量接口。
    func setXAxisViewport(_ range: ClosedRange<Double>)

    /// 当前视口是否越出了全量域（橡皮筋拖拽中）。
    var isXAxisOvershooting: Bool { get }

    /// 重置视口到全量数据（双击等场景）。
    func resetXAxisViewport()
}

/// 整列命中（shared tooltip）提供者：点击按类目取该 X 位置**所有系列**的数据。
/// 实现者返回组合好的 target（tooltipText 已含各系列值）与弹窗锚点。
public protocol HYMChartSharedHitProvider: HYMChartRenderer {
    /// - Returns: 该点的整列命中（含十字准线 frame，坐标同 host；nil = 不支持/点在绘图区外）
    func sharedHit(at point: CGPoint) -> (target: any HYMChartHitTarget,
                                          anchor: HYMChartTooltipAnchor,
                                          crosshair: CGRect)?
}

/// 吸附命中提供者：点击没落在任何数据点上时，吸附到**横向最近类目**上离触点
/// 最近的系列数据点（DGCharts 同款"永远有反馈"语义）。
public protocol HYMChartSnapHitProvider: HYMChartRenderer {
    /// - Returns: 吸附到的数据点 target；nil = 点在绘图区外（无吸附对象）
    func snapHit(at point: CGPoint) -> (any HYMChartHitTarget)?
}
