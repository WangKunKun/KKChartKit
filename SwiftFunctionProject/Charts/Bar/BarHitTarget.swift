import Foundation
import UIKit

/// 条形图命中目标
public struct BarHitTarget: HYMChartHitTarget {
    public let seriesIndex: Int
    public let categoryIndex: Int
    public let value: Double
    /// 系列名（nil = "系列N" 兜底；弹窗模板数据源用）
    public let name: String?

    public init(seriesIndex: Int, categoryIndex: Int, value: Double, name: String? = nil) {
        self.seriesIndex = seriesIndex
        self.categoryIndex = categoryIndex
        self.value = value
        self.name = name
    }

    // MARK: - HYMChartHitTarget

    public let kind = "bar"

    public var identifier: String {
        return "bar:\(seriesIndex):\(categoryIndex)"
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

extension BarHitTarget: HYMChartTooltipDataSource {
    public var tooltipRows: [(name: String, value: Double, isSecondaryAxis: Bool)] {
        [(name ?? "系列\(seriesIndex + 1)", value, false)]
    }
    public var tooltipHeaderKey: String? { nil }
}
