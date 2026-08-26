import Foundation

/// 轴系图表可见窗口（值域坐标）。
///
/// 这是缩放（阶段 4）、平移（阶段 4）、流式追加（阶段 4）的共同底座：
/// 手势改 viewport，`CartesianGeometry` 读 viewport 做值↔屏幕映射。
/// 阶段 0 为固定值域形态——由 Renderer 从 model 一次算出，无手势交互。
public struct CartesianViewport: Equatable {
    public var xMin: Double
    public var xMax: Double
    public var yMin: Double
    public var yMax: Double

    public init(xMin: Double, xMax: Double, yMin: Double, yMax: Double) {
        self.xMin = min(xMin, xMax)
        self.xMax = max(xMin, xMax)
        self.yMin = min(yMin, yMax)
        self.yMax = max(yMin, yMax)
    }

    public var xDomain: ClosedRange<Double> { xMin...xMax }
    public var yDomain: ClosedRange<Double> { yMin...yMax }
    public var xSpan: Double { xMax - xMin }
    public var ySpan: Double { yMax - yMin }

    /// 值裁剪到 x 域（退化域直接返回界值，避免除零路径）。
    public func clamp(x: Double) -> Double { min(max(x, xMin), xMax) }
    /// 值裁剪到 y 域。
    public func clamp(y: Double) -> Double { min(max(y, yMin), yMax) }
}
