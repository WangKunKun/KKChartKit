import Foundation
import UIKit

/// 柱状图命中目标
public struct ColumnHitTarget: HYMChartHitTarget {
    public let timeBucket: CartesianTimeBucket?
    /// 聚合前的区间统计值；value 仍为绘制值（堆叠时累计）。
    public var aggregatedValue: Double? { timeBucket?.value }
    public let seriesID: String?
    public let seriesIndex: Int
    public let categoryIndex: Int
    public let value: Double
    /// 绑定的值轴（0 = 主轴/左，1 = 次轴/右）。
    public let yAxisIndex: Int
    /// 系列名（nil = "系列N" 兜底；弹窗模板数据源用）
    public let name: String?

    public init(seriesIndex: Int, categoryIndex: Int, value: Double,
                yAxisIndex: Int = 0, name: String? = nil, seriesID: String? = nil, timeBucket: CartesianTimeBucket? = nil) {
        self.timeBucket = timeBucket
        self.seriesID = seriesID
        self.seriesIndex = seriesIndex
        self.categoryIndex = categoryIndex
        self.value = value
        self.yAxisIndex = yAxisIndex
        self.name = name
    }

    // MARK: - HYMChartHitTarget

    public let kind = "column"

    public var identifier: String {
        return "column:\(seriesIndex):\(categoryIndex)"
    }

    public var index: Int {
        return categoryIndex
    }

    public var tooltipText: String? {
        if let timeBucket {
            return timeBucket.intervalLabel + "\n" + timeBucket.tooltipRow(name: name ?? "系列\(seriesIndex + 1)")
                + (yAxisIndex == 1 ? " (右轴)" : "")
        }
        let seriesName = "系列\(seriesIndex + 1)"
        let categoryName = "项\(categoryIndex + 1)"
        return "\(seriesName) - \(categoryName): \(value)"
    }
}

extension ColumnHitTarget: HYMChartTooltipDataSource {
    public var tooltipRows: [(name: String, value: Double, isSecondaryAxis: Bool)] {
        let label = name ?? "系列\(seriesIndex + 1)"
        if let bucket = timeBucket {
            return [(label + " · " + bucket.detailLabel + (bucket.unit.map { " (" + $0 + ")" } ?? ""),
                     bucket.value ?? value, yAxisIndex == 1)]
        }
        return [(label, value, yAxisIndex == 1)]
    }
    public var tooltipHeaderKey: String? { timeBucket?.intervalLabel }
    public var tooltipContextText: String? { timeBucket?.intervalLabel }
}
