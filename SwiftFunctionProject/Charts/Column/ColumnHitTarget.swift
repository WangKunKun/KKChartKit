import Foundation
import UIKit

/// 柱状图命中目标
public struct ColumnHitTarget: HYMChartHitTarget {
    public let seriesIndex: Int
    public let categoryIndex: Int
    public let value: Double
    /// 绑定的值轴（0 = 主轴/左，1 = 次轴/右）。
    public let yAxisIndex: Int

    public init(seriesIndex: Int, categoryIndex: Int, value: Double, yAxisIndex: Int = 0) {
        self.seriesIndex = seriesIndex
        self.categoryIndex = categoryIndex
        self.value = value
        self.yAxisIndex = yAxisIndex
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
        let seriesName = "系列\(seriesIndex + 1)"
        let categoryName = "项\(categoryIndex + 1)"
        return "\(seriesName) - \(categoryName): \(value)"
    }
}
