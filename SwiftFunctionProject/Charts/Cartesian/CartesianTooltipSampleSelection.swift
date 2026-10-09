import Foundation

/// 取值偏移越过系列首尾时的展示策略；缺测值始终省略，不搜索更远的有效值。
public enum CartesianTooltipSampleBoundaryPolicy: String, CaseIterable {
    case omit
    case clamp
    case current
}

/// 仅改变提示取值的原始索引，默认 0。绘图、表头、准线和 onHit 仍使用当前命中。
/// 实际时间聚合 stride > 1 时保持原有区间统计，不对桶应用单点偏移。
public struct CartesianTooltipSampleSelection: Equatable {
    public var offset = 0
    /// 稳定 series.id 的覆盖，优先于 offset；显式 0 可让某系列保持当前值。
    public var offsetsBySeriesID: [String: Int] = [:]
    public var boundaryPolicy: CartesianTooltipSampleBoundaryPolicy = .omit
    public var showsSourceLabel = true
    /// 仅实际取值索引发生变化时显示；{key} 是该源类目标签，可本地化。
    public var sourceLabelTemplate = "取值 {key}"
    public init() {}

    func index(for current: Int, count: Int, seriesID: String) -> Int? {
        guard current >= 0, current < count else { return nil }
        let delta = offsetsBySeriesID[seriesID] ?? offset
        let addition = current.addingReportingOverflow(delta)
        if !addition.overflow, addition.partialValue >= 0, addition.partialValue < count { return addition.partialValue }
        switch boundaryPolicy {
        case .omit: return nil
        case .current: return current
        case .clamp: return delta < 0 ? 0 : count - 1
        }
    }
}

/// 命中与展示取值的独立快照。两者必须属于同一系列；原始命中数据不被覆盖。
public struct CartesianTooltipSample {
    public let hitDatum: CartesianDatum
    public let displayedDatum: CartesianDatum
    public let sourceLabel: String?
    public init(hitDatum: CartesianDatum, displayedDatum: CartesianDatum, sourceLabel: String? = nil) {
        self.hitDatum = hitDatum; self.displayedDatum = displayedDatum; self.sourceLabel = sourceLabel
    }
}

/// 轴系提示取值能力。自定义 renderer 可实现本协议，通用容器不访问业务数组。
public protocol CartesianTooltipSampleProviding {
    func tooltipSamples(for data: [CartesianDatum], selection: CartesianTooltipSampleSelection) -> [CartesianTooltipSample]
}
