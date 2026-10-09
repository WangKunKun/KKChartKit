import Foundation

/// 值轴分区的比较坐标；只决定颜色，不修改数据、堆叠或命中身份。
public enum ChartZoneValueSource: String, Codable, CaseIterable, Sendable {
    /// 原始业务贡献（百分比堆叠时仍为原始单位）。HYM 当前仅支持柱/条图。
    case rawValue
    /// 最终绘制的值轴坐标：包含累计基线，百分比堆叠时为百分数。
    case drawValue
}

/// 值轴上的一个半开颜色区间 [前一上界, upperBound)，第一段下界为负无穷。
/// 阈值相等时进入下一段；nil 上界表示正无穷，只能用于最后一段。
public struct ChartValueColorZone: Codable, Equatable, Sendable {
    public var upperBound: Double?
    /// nil 继承系列颜色；不会重新使用 negativeColor。此配置不覆盖面积填充。
    public var color: ChartRGBA?

    /// 只保存配置；有限、严格递增的阈值和 RGBA 范围由 ChartSpecification.validate 检查。
    public init(upperBound: Double? = nil, color: ChartRGBA? = nil) {
        self.upperBound = upperBound
        self.color = color
    }
}

/// schema v3 的逐系列值轴颜色分区；阈值始终使用该系列绑定的逻辑值轴，
/// 包括水平 Bar（屏幕 X）。不是类目索引、真实 X 坐标或分区面积渐变。
/// 至少一段；若最后一段有有限上界，剩余部分继承系列颜色。
/// 有效分区优先于负值/逐柱配色；缺测仍为缺测，不影响 domain 和数据身份。
public struct ChartValueColorZones: Codable, Equatable, Sendable {
    public var valueSource: ChartZoneValueSource
    public var zones: [ChartValueColorZone]

    /// 默认按最终绘制坐标比较。关闭分区请将 appearance.valueColorZones 设为 nil。
    public init(valueSource: ChartZoneValueSource = .drawValue, zones: [ChartValueColorZone]) {
        self.valueSource = valueSource
        self.zones = zones
    }
}
