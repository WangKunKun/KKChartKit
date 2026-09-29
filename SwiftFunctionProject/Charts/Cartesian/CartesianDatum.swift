import Foundation

/// 业务展示组，不参与数学堆叠。ID 应稳定且在一个模型中唯一。
public struct CartesianSeriesGroup: Equatable {
    public var id: String
    public var name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

/// 单个已命中项的数据语义快照。聚合时 rawValue 为 nil，避免将区间统计冒充单个采样。
public struct CartesianDatum {
    public let seriesID: String
    public let seriesIndex: Int
    public let categoryIndex: Int
    public let name: String
    public let stackID: String?
    public let groupID: String?
    public let groupName: String?
    public let unit: String?
    public let yAxisIndex: Int
    public let rawValue: Double?
    public let aggregatedValue: Double?
    /// 绘图的终点，百分比堆叠时为百分比坐标。
    public let drawValue: Double
    /// 绘图的起点；非堆叠为 0。
    public let stackBase: Double
    /// 仅百分比堆叠提供有符号的百分比；普通堆叠/非堆叠为 nil。
    /// percent 使用当前值轴、图形族、堆叠组中可见系列绝对值之和；percentFixed 使用固定基准。
    public let percentage: Double?
    public let sourceRange: Range<Int>
    public let timeBucket: CartesianTimeBucket?
    public let valueFormat: CartesianValueFormat?
    /// Tooltip/业务展示的数值：原始采样或聚合统计，不是堆叠累计值。
    public var displayValue: Double { aggregatedValue ?? rawValue ?? .nan }
    public var formattedValue: String {
        if let valueFormat { return valueFormat.string(from: displayValue, unit: unit) }
        return HYMChartTooltipTextOptions.formatValue(displayValue, decimals: nil)
            + (unit.flatMap { $0.isEmpty ? nil : " " + $0 } ?? "")
    }
}

/// Line/Column/Bar 的单点、吸附、共享命中均提供同一套数据语义。
public protocol CartesianHitDataSource {
    var chartData: [CartesianDatum] { get }
}

enum CartesianDatumText {
    static func text(_ data: [CartesianDatum], options: HYMChartTooltipTextOptions = .init(), header: String? = nil) -> String? {
        guard !data.isEmpty else { return nil }
        var lines: [String] = []
        let interval = data.first?.timeBucket?.intervalLabel
        if let interval { lines.append(interval) }
        if let template = options.header, let header {
            let title = template.replacingOccurrences(of: "{key}", with: header)
            if title != interval { lines.append(title) }
        }
        for row in data {
            let value: String
            // 显式系列格式优先；未配置的系列沿用全局小数位/后缀模板。
            if row.valueFormat != nil { value = row.formattedValue }
            else {
                value = HYMChartTooltipTextOptions.formatValue(row.displayValue, decimals: options.valueDecimals)
                    + (options.valueSuffix ?? row.unit.flatMap { $0.isEmpty ? nil : " " + $0 } ?? "")
            }
            let detail = row.timeBucket.map { " · " + $0.detailLabel } ?? ""
            lines.append(row.name + detail + ": " + value + (row.yAxisIndex == 1 ? " (右轴)" : ""))
        }
        return lines.joined(separator: "\n")
    }
}

extension CartesianRendererBase {
    /// 从当前已准备的数据构造命中快照；不重算整组堆叠数组。
    func datum(series index: Int, category: Int) -> CartesianDatum? {
        guard let model = currentModel, model.series.indices.contains(index),
              model.series[index].isVisible, model.series[index].data.indices.contains(category),
              currentDrawValues.indices.contains(index), currentDrawValues[index].indices.contains(category),
              currentBaseValues.indices.contains(index), currentBaseValues[index].indices.contains(category) else { return nil }
        let series = model.series[index]
        let value = series.data[category]
        let draw = currentDrawValues[index][category]
        let segment = currentBaseValues[index][category]
        guard value.isFinite, draw.isFinite, segment.isFinite else { return nil }
        let bucket = model.timeBucket(series: index, category: category)
        let aggregated = bucket?.isAggregated == true
        let percentage: Double?
        switch model.stacking {
        case .percent, .percentFixed: percentage = series.participatesInStack ? segment : nil
        default: percentage = nil
        }
        return CartesianDatum(seriesID: series.id, seriesIndex: index, categoryIndex: category,
            name: series.name, stackID: series.stackID, groupID: series.groupID,
            groupName: model.groups.first { $0.id == series.groupID }?.name,
            unit: series.unit, yAxisIndex: isHorizontalValueAxis ? 0 : series.effectiveYAxisIndex,
            rawValue: aggregated ? nil : value, aggregatedValue: aggregated ? value : nil,
            drawValue: draw, stackBase: model.isStacked ? draw - segment : 0,
            percentage: percentage, sourceRange: bucket?.sourceRange ?? category..<(category + 1),
            timeBucket: bucket, valueFormat: series.valueFormat)
    }
}
