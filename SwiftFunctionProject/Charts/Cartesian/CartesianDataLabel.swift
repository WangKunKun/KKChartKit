import UIKit

/// 数据标签位置（Highcharts dataLabels 的 align/verticalAlign 简化版）。
/// 语义随图表形态映射：
/// - 折线：`outsideEnd` = 点上方，`center`/`insideEnd` = 点下方；
/// - 柱状（垂直）：`outsideEnd` = 柱顶外侧（负值柱底外侧）、`center` = 柱段中心、`insideEnd` = 柱顶内侧；
/// - 条形（水平）：镜像到水平方向——`outsideEnd` = 条端右侧（负值左侧）、`center` = 段中心、`insideEnd` = 条端内侧。
public enum CartesianDataLabelPosition: String, CaseIterable {
    case outsideEnd = "端部外侧"
    case center = "中心"
    case insideEnd = "端部内侧"
}

// MARK: - 几何（纯函数，供渲染器与自检共用）

public enum CartesianDataLabelGeometry {

    /// 折线数据点标签中心。
    /// - Parameters:
    ///   - point: 数据点屏幕坐标
    ///   - textSize: 已量好的标签文本尺寸
    ///   - pointRadius: 数据点半径（showsPoints 关闭时传 0）
    public static func labelCenter(point: CGPoint, textSize: CGSize,
                                   position: CartesianDataLabelPosition,
                                   pointRadius: CGFloat) -> CGPoint {
        let gap = pointRadius + textSize.height / 2 + 2
        switch position {
        case .outsideEnd:
            return CGPoint(x: point.x, y: point.y - gap)
        case .center, .insideEnd:
            return CGPoint(x: point.x, y: point.y + gap)
        }
    }

    /// 柱/条段标签中心（rect = 段矩形，view 坐标）。
    /// - Parameters:
    ///   - rect: 柱段/条段矩形
    ///   - textSize: 已量好的标签文本尺寸
    ///   - isHorizontal: 条形图（值轴在 X）时按水平方向镜像
    ///   - isPositive: 正值段端部在上/右，负值段端部在下/左
    public static func labelCenter(rect: CGRect, textSize: CGSize,
                                   position: CartesianDataLabelPosition,
                                   isHorizontal: Bool, isPositive: Bool) -> CGPoint {
        let gap: CGFloat = 3
        if isHorizontal {
            switch position {
            case .outsideEnd:
                let x = isPositive ? rect.maxX + textSize.width / 2 + gap
                                   : rect.minX - textSize.width / 2 - gap
                return CGPoint(x: x, y: rect.midY)
            case .center:
                return CGPoint(x: rect.midX, y: rect.midY)
            case .insideEnd:
                let x = isPositive ? rect.maxX - textSize.width / 2 - gap
                                   : rect.minX + textSize.width / 2 + gap
                return CGPoint(x: x, y: rect.midY)
            }
        }
        switch position {
        case .outsideEnd:
            let y = isPositive ? rect.minY - textSize.height / 2 - gap
                               : rect.maxY + textSize.height / 2 + gap
            return CGPoint(x: rect.midX, y: y)
        case .center:
            return CGPoint(x: rect.midX, y: rect.midY)
        case .insideEnd:
            let y = isPositive ? rect.minY + textSize.height / 2 + gap
                               : rect.maxY - textSize.height / 2 - gap
            return CGPoint(x: rect.midX, y: y)
        }
    }

    /// 默认数值文本：整数不带小数、非整数最多 2 位并去尾零（formatter 优先）。
    public static func labelText(_ value: Double, formatter: ((Double) -> String)? = nil) -> String {
        if let formatter { return formatter(value) }
        guard value.isFinite else { return "–" }
        if abs(value - value.rounded()) < 1e-9 { return String(Int(value.rounded())) }
        let s = String(format: "%.2f", value)
        return s.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
}
