import Foundation

/// 线条虚线/点线样式（对齐 Highcharts/AAChartKit 的 11 种 dashStyle）。
/// 模式为 CAShapeLayer.lineDashPattern 的 [画, 空] 交替长度（pt，配合圆头线帽呈现点/短线）。
public enum LineDashStyle: String, CaseIterable {
    case solid
    case shortDash
    case shortDot
    case shortDashDot
    case shortDashDotDot
    case dot
    case dash
    case dashDot
    case longDash
    case longDashDot
    case longDashDotDot

    /// CAShapeLayer 虚线模式（nil = 实线）。
    public var dashPattern: [NSNumber]? {
        switch self {
        case .solid:            return nil
        case .shortDash:        return [3, 3]
        case .shortDot:         return [1, 2]
        case .shortDashDot:     return [3, 3, 1, 3]
        case .shortDashDotDot:  return [3, 3, 1, 3, 1, 3]
        case .dot:              return [1, 3]
        case .dash:             return [6, 3]
        case .dashDot:          return [6, 3, 1, 3]
        case .longDash:         return [12, 5]
        case .longDashDot:      return [12, 4, 1, 4]
        case .longDashDotDot:   return [12, 4, 1, 4, 1, 4]
        }
    }
}
