import Foundation
import UIKit

/// 柱状图命中目标
public struct ColumnHitTarget: HYMChartHitTarget {
    public let seriesIndex: Int
    public let categoryIndex: Int
    public let value: Double

    public init(seriesIndex: Int, categoryIndex: Int, value: Double) {
        self.seriesIndex = seriesIndex
        self.categoryIndex = categoryIndex
        self.value = value
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
