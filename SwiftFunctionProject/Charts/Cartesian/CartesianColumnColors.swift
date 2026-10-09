import UIKit

/// 每系列解析一次整柱/整条取色规则，保持 Column、Bar 与 Combined 柱系列完全一致。
/// 不裁切几何；动画/缩放不会改变 Y 阈值所用的最终数据值。
struct CartesianColumnColors {
    private let baseColor: UIColor
    private let negativeColor: UIColor
    private let palette: [UIColor]
    private let zones: CartesianResolvedColorZones?
    private let valueSource: CartesianColumnZoneValueSource

    init(series: CartesianSeriesElement, defaultColor: UIColor) {
        baseColor = series.color ?? defaultColor
        negativeColor = series.negativeColor ?? baseColor
        palette = series.barColors ?? []
        // 不将 negativeColor 合成分区：无效配置必须完整保留旧调色板优先级。
        zones = CartesianResolvedColorZones(configuration: series.colorZones,
                                             negativeColor: nil, baseColor: baseColor)
        valueSource = series.colorZones?.columnValueSource ?? .rawValue
    }

    func color(categoryIndex: Int, sourceIndex: Int, rawValue: Double, drawValue: Double) -> UIColor {
        if let zones {
            return zones.color(x: Double(sourceIndex), y: valueSource == .rawValue ? rawValue : drawValue)
        }
        // 保留既有兼容行为：显式负值色等于系列色时，逐柱调色板仍然生效。
        if drawValue < 0, negativeColor != baseColor { return negativeColor }
        if !palette.isEmpty { return palette[categoryIndex % palette.count] }
        return baseColor
    }
}
