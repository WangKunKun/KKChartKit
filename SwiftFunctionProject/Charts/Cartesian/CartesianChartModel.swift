import Foundation
import CoreGraphics
import UIKit

/// 轴类型。阶段 0 仅实现 `.category` 的渲染；`.value` 为阶段 5 散点图预留。
public enum CartesianAxisKind {
    /// 类目轴。`labels` 为空时自动生成数字标签 "1"..."n"（n = 最长 series 点数）。
    case category(labels: [String])
    /// 数值轴（阶段 5 实现 x 向数值映射；阶段 0 按类目处理）。
    case value
}

/// 轴配置（x/y 通用）。
public struct CartesianAxisModel {
    public var kind: CartesianAxisKind
    /// 显式值域下界；nil = 自动（y 轴自动时走 nice scale，x 轴自动按类目数）。
    public var min: Double?
    /// 显式值域上界；nil = 自动。
    public var max: Double?
    /// 显式刻度步长；nil = 自动（nice step）。显式时须与 min/max 同显式，否则忽略。
    public var tickInterval: Double?

    public init(kind: CartesianAxisKind,
                min: Double? = nil, max: Double? = nil, tickInterval: Double? = nil) {
        self.kind = kind
        self.min = min
        self.max = max
        self.tickInterval = tickInterval
    }
}

/// 单个数据系列（阶段 0：等距数值数组，按索引对位类目）。
public struct CartesianSeriesElement {
    public var name: String
    public var data: [Double]
    /// nil → 用主题默认系列色。
    public var color: UIColor?

    public init(name: String, data: [Double], color: UIColor? = nil) {
        self.name = name
        self.data = data
        self.color = color
    }
}

/// 轴系图表数据（折线/柱状等共用）。
public struct CartesianChartModel: HYMChartModel {
    public var title: String?
    public var series: [CartesianSeriesElement]
    public var xAxis: CartesianAxisModel
    public var yAxis: CartesianAxisModel

    public init(title: String? = nil,
                series: [CartesianSeriesElement],
                xAxis: CartesianAxisModel = CartesianAxisModel(kind: .category(labels: [])),
                yAxis: CartesianAxisModel = CartesianAxisModel(kind: .value)) {
        self.title = title
        self.series = series
        self.xAxis = xAxis
        self.yAxis = yAxis
    }

    /// 最长 series 的点数（类目数）。
    public var maxPointCount: Int {
        series.map { $0.data.count }.max() ?? 0
    }

    /// 所有 series 数据的全局 (min, max)；任一有效数据都没有时为 nil。
    public var dataBounds: (min: Double, max: Double)? {
        let flat = series.flatMap { $0.data }
        guard let lo = flat.min(), let hi = flat.max() else { return nil }
        return (lo, hi)
    }

    /// 实际生效的类目标签：显式非空优先；否则自动 "1"..."n"。
    public var categoryLabels: [String] {
        if case .category(let labels) = xAxis.kind, !labels.isEmpty {
            return Array(labels.prefix(maxPointCount))
        }
        return (1...maxPointCount).map { String($0) }
    }
}
