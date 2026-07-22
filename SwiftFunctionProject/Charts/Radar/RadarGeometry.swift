import CoreGraphics

/// 极坐标几何纯函数（便于 DEBUG 自检）
public enum RadarGeometry {
    /// 第 i 个顶点角度（弧度），i=0 朝正上方（-π/2）
    public static func angle(index i: Int, count n: Int) -> CGFloat {
        guard n > 0 else { return 0 }
        return -CGFloat.pi / 2 + CGFloat(i) * 2 * CGFloat.pi / CGFloat(n)
    }

    /// 第 i 个数据顶点坐标（ratio 为归一化比值 0~1，越界裁剪）
    public static func point(
        index i: Int, count n: Int,
        center: CGPoint, radius: CGFloat, ratio: CGFloat
    ) -> CGPoint {
        let a = angle(index: i, count: n)
        let r = radius * max(0, min(1, ratio))
        return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
    }

    /// 第 k 圈（k = 0 ..< ringCount）的网格多边形顶点数组
    public static func ringPoints(
        count n: Int, center: CGPoint, radius: CGFloat,
        ringIndex k: Int, ringCount: Int
    ) -> [CGPoint] {
        guard ringCount > 0 else { return [] }
        let ratio = CGFloat(k + 1) / CGFloat(ringCount)
        return (0..<n).map { point(index: $0, count: n, center: center, radius: radius, ratio: ratio) }
    }
}
