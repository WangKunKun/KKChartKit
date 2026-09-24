import Foundation

/// 轴系图表可见窗口（值域坐标）。
///
/// 手势改 viewport，`CartesianGeometry` 读 viewport 做值↔屏幕映射。
/// 数据更新时可保留用户窗口，并限制到更新后的数据域。
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

    /// 数据更新的严格约束，不保留手势橡皮筋余量。nil 表示跟随全量域。
    static func constrainedUserRange(_ range: ClosedRange<Double>?,
                                     fullDomain: ClosedRange<Double>,
                                     minimumSpan: Double) -> ClosedRange<Double>? {
        guard let range, range.lowerBound.isFinite, range.upperBound.isFinite else { return nil }
        let fullSpan = fullDomain.upperBound - fullDomain.lowerBound
        guard fullSpan.isFinite, fullSpan > 0 else { return nil }
        let span = min(max(range.upperBound - range.lowerBound, max(0, minimumSpan)), fullSpan)
        guard span < fullSpan else { return nil }
        let lo = min(max(range.lowerBound, fullDomain.lowerBound), fullDomain.upperBound - span)
        return lo...(lo + span)
    }
}
