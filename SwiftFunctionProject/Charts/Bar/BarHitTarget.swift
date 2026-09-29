import Foundation
import UIKit

/// 条形图命中目标
public struct BarHitTarget: HYMChartHitTarget, CartesianHitDataSource {
    /// 明确的数据语义。旧 value 继续表示历史绘制值，业务请使用 rawValue/displayValue。
    public let datum: CartesianDatum?
    public var rawValue: Double? { datum?.rawValue }
    public var drawValue: Double { datum?.drawValue ?? value }
    public var stackBase: Double? { datum?.stackBase }
    public var percentage: Double? { datum?.percentage }
    public var chartData: [CartesianDatum] { datum.map { [$0] } ?? [] }
    public let seriesID: String?
    public let seriesIndex: Int
    public let categoryIndex: Int
    public let value: Double
    /// 系列名（nil = "系列N" 兜底；弹窗模板数据源用）
    public let name: String?

    public init(seriesIndex: Int, categoryIndex: Int, value: Double, name: String? = nil, seriesID: String? = nil, datum: CartesianDatum? = nil) {
        self.datum = datum
        self.seriesID = seriesID
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
        if let text = CartesianDatumText.text(chartData) { return text }
        let seriesName = "系列\(seriesIndex + 1)"
        let categoryName = "项\(categoryIndex + 1)"
        return "\(seriesName) - \(categoryName): \(value)"
    }
}

extension BarHitTarget: HYMChartTooltipDataSource {
    public var tooltipRows: [(name: String, value: Double, isSecondaryAxis: Bool)] {
        if let datum { return [(datum.name, datum.displayValue, datum.yAxisIndex == 1)] }
        return [(name ?? "系列\(seriesIndex + 1)", value, false)]
    }
    public var tooltipHeaderKey: String? { nil }
}
