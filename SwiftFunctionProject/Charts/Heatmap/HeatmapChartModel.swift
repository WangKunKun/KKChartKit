import Foundation
import CoreGraphics
import UIKit

/// 热力图单个格子（纯值类型）。
public struct HeatmapCell {
    /// 原始数值（如百分比 0~100，或任意量纲）。
    public var value: Double
    /// 满值，用于单格归一化；默认 100。<=0 时按 1 兜底。
    public var maxValue: Double
    /// 单格覆盖色；nil → 由 Theme 色阶按全局值域归一化计算。
    public var color: UIColor?

    public init(value: Double, maxValue: Double = 100, color: UIColor? = nil) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
    }

    /// 单格自归一化比值 [0,1]（越界裁剪；内部使用）。
    public var normalized: CGFloat {
        let m = maxValue > 0 ? maxValue : 1
        return CGFloat(max(0, min(1, value / m)))
    }
}

/// 热力图数据（外观分离到 Theme，由 `configure(model:theme:)` 单独传入）。
///
/// `rows` 为二维数组：外层=行（自上而下），内层=该行格子（自左而右）。
/// 行数与每行格子数均不固定，支持锯齿行（每行长度不同）。
public struct HeatmapChartModel: HYMChartModel {
    public var rows: [[HeatmapCell]]
    /// 色阶归一化基准；nil → 自动按全体 value 的 min/max。用于跨格子统一可比的色阶映射。
    public var valueRange: ClosedRange<Double>?
    /// 可选行标签（左侧），长度应等于 rows.count；nil 不显示。
    public var rowLabels: [String]?
    /// 可选列标签（顶部），长度应等于 maxColumns；nil 不显示。
    public var columnLabels: [String]?

    public init(rows: [[HeatmapCell]],
                valueRange: ClosedRange<Double>? = nil,
                rowLabels: [String]? = nil,
                columnLabels: [String]? = nil) {
        self.rows = rows
        self.valueRange = valueRange
        self.rowLabels = rowLabels
        self.columnLabels = columnLabels
    }

    /// 实际生效的归一化值域；显式 nil/数据为空/极差为 0 时回退 0...1（纯函数，便于自检）。
    public var resolvedValueRange: ClosedRange<Double> {
        if let r = valueRange { return r }
        let vals = rows.flatMap { $0 }.map { $0.value }
        guard let lo = vals.min(), let hi = vals.max(), hi > lo else {
            return 0...1
        }
        return lo...hi
    }

    /// 最大列数（锯齿行取最长行）。
    public var maxColumns: Int {
        rows.map { $0.count }.max() ?? 0
    }
}
