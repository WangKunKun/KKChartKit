import CoreGraphics
import UIKit

/// 折线数据点标记符号（对齐 Highcharts marker symbol；多系列时形状区分有助于色弱用户）。
public enum PointMarkerSymbol: String, CaseIterable {
    case circle
    case square
    case diamond
    case triangle        // 正三角（向上）
    case triangleDown    // 倒三角（向下）

    /// 以 center 为中心、边距 2r 的路径（正方形内切尺寸统一视觉面积量级）。
    public func path(center: CGPoint, radius: CGFloat) -> CGPath {
        let r = max(radius, 0.5)
        switch self {
        case .circle:
            return CGPath(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                            width: r * 2, height: r * 2), transform: nil)
        case .square:
            return CGPath(rect: CGRect(x: center.x - r, y: center.y - r,
                                       width: r * 2, height: r * 2), transform: nil)
        case .diamond:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: center.x, y: center.y - r))
            p.addLine(to: CGPoint(x: center.x + r, y: center.y))
            p.addLine(to: CGPoint(x: center.x, y: center.y + r))
            p.addLine(to: CGPoint(x: center.x - r, y: center.y))
            p.close()
            return p.cgPath
        case .triangle:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: center.x, y: center.y - r))
            p.addLine(to: CGPoint(x: center.x + r, y: center.y + r))
            p.addLine(to: CGPoint(x: center.x - r, y: center.y + r))
            p.close()
            return p.cgPath
        case .triangleDown:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: center.x, y: center.y + r))
            p.addLine(to: CGPoint(x: center.x + r, y: center.y - r))
            p.addLine(to: CGPoint(x: center.x - r, y: center.y - r))
            p.close()
            return p.cgPath
        }
    }
}
