import UIKit

/// 混合图的系列形态。nil 类型在 CombinedChart 中按 column 绘制。
public enum CartesianSeriesKind: String, CaseIterable {
    case column, line, spline, area, areaspline
    var isColumn: Bool { self == .column }
}

/// 系列的可选样式覆盖。nil 继承主题；数值为有限非负 pt，透明度限制在 0...1。
/// 值配置可在后台构造；应用到图表须在主线程，勿并发修改同一变量。
public struct CartesianSeriesStyle {
    public var lineConnectionStyle: LineConnectionStyle?
    public var lineWidth: CGFloat?
    public var showsPoints: Bool?
    public var pointRadius: CGFloat?
    public var showsArea: Bool?
    /// nil 继承主题渐变；空数组恢复该系列默认渐变；单色自动扩展为纯色填充。
    public var areaGradientColors: [UIColor]?
    /// 乘在渐变颜色自身 alpha 上；nil = 1。
    public var fillOpacity: CGFloat?
    public init() {}

    func applying(to theme: CartesianChartTheme, kind: CartesianSeriesKind? = nil) -> CartesianChartTheme {
        var result = theme
        if let kind, !kind.isColumn {
            result.lineConnectionStyle = (kind == .spline || kind == .areaspline) ? .smooth : .straight
            result.showsArea = kind == .area || kind == .areaspline
        }
        if let lineConnectionStyle { result.lineConnectionStyle = lineConnectionStyle }
        if let lineWidth, lineWidth.isFinite { result.lineWidth = max(0, lineWidth) }
        if let showsPoints { result.showsPoints = showsPoints }
        if let pointRadius, pointRadius.isFinite { result.pointRadius = max(0, pointRadius) }
        if let showsArea { result.showsArea = showsArea }
        if let areaGradientColors { result.areaGradientColors = areaGradientColors.isEmpty ? nil : areaGradientColors }
        return result
    }
    var resolvedFillOpacity: CGFloat {
        guard let fillOpacity, fillOpacity.isFinite else { return 1 }
        return min(1, max(0, fillOpacity))
    }
}

/// 数学链键：业务 groupID 不参与；跨值轴和柱/线族永不混叠。
struct CartesianStackKey: Hashable {
    let axis: Int
    let stackID: String?
    let partition: Int?
    let column: Bool
    let independentSeries: String?
}
extension CartesianSeriesElement {
    var stackKey: CartesianStackKey {
        .init(axis: effectiveYAxisIndex, stackID: stackID, partition: stackPartition,
              column: stackFamilyIsColumn ?? kind?.isColumn ?? true, independentSeries: participatesInStack ? nil : id)
    }
    func lineTheme(_ theme: CartesianChartTheme) -> CartesianChartTheme {
        style.applying(to: theme, kind: kind)
    }
}
