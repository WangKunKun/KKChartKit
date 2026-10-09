import Foundation

/// 轴系内置提示的业务分组与过滤配置；不影响绘图、命中回调或数学堆叠。
/// SwiftUI 通过 tooltipTextOptions.cartesian 传入；更新图表时请在主线程使用。
public struct CartesianTooltipOptions: Equatable {
    /// 按 groupID 分组，组和组内系列均保持首次出现顺序。默认关闭。
    public var groupsByBusinessID = false
    /// 仅为至少两行、同单位/值轴/格式的原始采样显示有符号小计。
    /// 聚合数据、无业务组、混合单位/值轴/格式或溢出时省略小计。
    public var showsGroupSubtotals = false
    /// 只过滤精确为零的展示值；负值与缺测不作零处理。
    public var hidesZeroValues = false
    /// 按稳定 series.id 过滤提示行；图形和回调仍包含这些系列。
    public var excludedSeriesIDs: Set<String> = []
    public var ungroupedTitle = "未分组"
    public var subtotalTitle = "小计"
    public init() {}
}

enum CartesianTooltipGrouping {
    struct Group {
        let id: String?
        var rows: [CartesianDatum]
    }

    static func subtotalValue(_ group: Group, options: HYMChartTooltipTextOptions) -> String? {
        guard group.id != nil, group.rows.count > 1, let first = group.rows.first,
              group.rows.allSatisfy({ row in
                  row.rawValue != nil && row.aggregatedValue == nil && row.sourceRange == first.sourceRange
                    && row.unit == first.unit && row.yAxisIndex == first.yAxisIndex
                    && row.valueFormat == first.valueFormat
              }) else { return nil }
        let sum = group.rows.reduce(0) { $0 + $1.displayValue }
        guard sum.isFinite else { return nil }
        var format = first.valueFormat
        // 小计是原值的代数和，即使系列选择绝对值展示也保留合计的符号。
        format?.showsAbsoluteValue = false
        let value = format?.string(from: sum, unit: first.unit)
            ?? CartesianDatumText.value(sum, unit: first.unit, options: options)
        return value + (first.yAxisIndex == 1 ? " (右轴)" : "")
    }
}
