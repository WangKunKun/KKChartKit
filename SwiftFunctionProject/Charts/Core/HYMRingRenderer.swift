import UIKit

/// Ring 绘制器：生成圆 / 正多边形 ring 的 CAShapeLayer 或 CGPath。
///
/// 用途：
/// - 雷达图内部装饰 ring（复用 `ringPath`）。
/// - 外界（含 OC）自由绘制大背景 ring：`[HYMRingRenderer ringLayerWith...]` 拿 `CAShapeLayer`，
///   加到自己的背景层。
///
/// `sides` 约定：`0` = 圆形 ring；`N≥3` = 正 N 边形 ring。
@objcMembers
public final class HYMRingRenderer: NSObject {

    /// 生成一个配置好的 ring `CAShapeLayer`（OC 直接 add 到自己的 layer 作背景）。
    /// - Parameters:
    ///   - center: 中心坐标
    ///   - radius: 半径
    ///   - sides: 边数（0 = 圆形；N≥3 = 正 N 边形）
    ///   - strokeColor: 描边色
    ///   - lineWidth: 线宽
    ///   - fillColor: 填充色（nil = 透明）
    ///   - dashed: 是否虚线
    ///   - dashLength: 虚线线段长（dashed=true 时生效）
    ///   - dashGap: 虚线间隔（dashed=true 时生效）
    ///   - startAngle: 起始角度（弧度）；多边形第一个顶点方向，默认 -π/2 朝上
    /// - Returns: 配置好的 `CAShapeLayer`
    @objc public static func ringLayer(
        center: CGPoint,
        radius: CGFloat,
        sides: Int,
        strokeColor: UIColor,
        lineWidth: CGFloat,
        fillColor: UIColor?,
        dashed: Bool,
        dashLength: CGFloat,
        dashGap: CGFloat,
        startAngle: CGFloat
    ) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = ringPath(center: center, radius: radius, sides: sides, startAngle: startAngle)
        layer.strokeColor = strokeColor.cgColor
        layer.lineWidth = lineWidth
        layer.fillColor = (fillColor ?? UIColor.clear).cgColor
        layer.lineDashPattern = dashed ? [dashLength as NSNumber, dashGap as NSNumber] : nil
        return layer
    }

    /// 生成 ring 的 `CGPath`。
    /// - Parameters:
    ///   - center: 中心
    ///   - radius: 半径
    ///   - sides: 边数（0 = 圆形；N≥3 = 正 N 边形；1~2 归一为 3）
    ///   - startAngle: 起始角度（弧度），默认 -π/2 朝上（多边形用）
    /// - Returns: `CGPath`
    @objc public static func ringPath(center: CGPoint, radius: CGFloat, sides: Int, startAngle: CGFloat) -> CGPath {
        let r = max(0, radius)
        if sides <= 0 {
            // 圆形 ring
            return UIBezierPath(arcCenter: center, radius: r,
                                 startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true).cgPath
        }
        // 正多边形 ring
        let n = max(3, sides)
        let path = UIBezierPath()
        for i in 0..<n {
            let a = startAngle + CGFloat(i) * 2 * CGFloat.pi / CGFloat(n)
            let p = CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()
        return path.cgPath
    }
}
