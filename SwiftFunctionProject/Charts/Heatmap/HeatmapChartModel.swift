import Foundation
import CoreGraphics
import UIKit

/// 热力图单个格子（纯值类型）。
public struct HeatmapCell {
    /// 原始数值（如百分比 0~100，或任意量纲）。
    public var value: Double
    /// 单格覆盖色；nil → 由 Theme 色阶按 Model 值域归一化计算。
    public var color: UIColor?
    /// 是否有效；false = 无效占位（占布局位置但不绘制、不命中、不参与色阶）。
    public var isValid: Bool
    /// 该格子弹窗文本；nil → 默认格式化 `value`。仅当 tooltip 启用时生效。
    public var tooltipText: String?

    public init(value: Double, color: UIColor? = nil,
                isValid: Bool = true, tooltipText: String? = nil) {
        self.value = value
        self.color = color
        self.isValid = isValid
        self.tooltipText = tooltipText
    }

    /// 无效占位格：占位但不绘制、不命中、不参与色阶。
    public static func placeholder() -> HeatmapCell {
        HeatmapCell(value: 0, isValid: false)
    }
}

/// 热力图数据（外观分离到 Theme，由 `configure(model:theme:)` 单独传入）。
///
/// `rows` 为二维数组：外层=行（自上而下），内层=该行格子（自左而右）。
/// 行数与每行格子数均不固定，支持锯齿行（每行长度不同）。
///
/// 色阶归一化值域由 `valueRange` 决定（或便捷 `init(minValue:maxValue:)`）；
/// 未指定时默认 `0...有效格value的最大值`——即「值越大越实色」，
/// value=0 全透明、value=max 满色，与 `.alpha` 色阶语义一致。
public struct HeatmapChartModel: HYMChartModel {
    public var rows: [[HeatmapCell]]
    /// 色阶归一化值域；nil → 自动 `0...数据max`。用于跨格子统一可比的色阶映射。
    public var valueRange: ClosedRange<Double>?
    /// 可选行标签（左侧），长度应等于 rows.count；nil 不显示。
    public var rowLabels: [String]?
    /// 可选列标签（顶部），长度应等于 maxColumns；nil 不显示。
    public var columnLabels: [String]?

    /// 主构造：显式 `valueRange` 优先；nil → 自动 `0...数据max`。
    public init(rows: [[HeatmapCell]],
                valueRange: ClosedRange<Double>? = nil,
                rowLabels: [String]? = nil,
                columnLabels: [String]? = nil) {
        self.rows = rows
        self.valueRange = valueRange
        self.rowLabels = rowLabels
        self.columnLabels = columnLabels
    }

    /// 便捷构造：用独立的 min/max 指定值域（内部转成 `valueRange = minValue...maxValue`）。
    /// 适合「值域固定、不随数据变化」的场景，如 0...100 百分比。
    public init(rows: [[HeatmapCell]],
                minValue: Double,
                maxValue: Double,
                rowLabels: [String]? = nil,
                columnLabels: [String]? = nil) {
        self.rows = rows
        self.rowLabels = rowLabels
        self.columnLabels = columnLabels
        let lo = Swift.min(minValue, maxValue)
        let hi = Swift.max(minValue, maxValue)
        self.valueRange = lo...hi
    }

    /// 实际生效的归一化值域（纯函数，便于自检）：
    /// 显式 `valueRange` 优先；否则 `0...有效格value的最大值`；
    /// 数据为空或最大值 <= 0 时回退 `0...1`。
    public var resolvedValueRange: ClosedRange<Double> {
        if let r = valueRange { return r }
        let vals = rows.flatMap { $0 }.compactMap { $0.isValid ? $0.value : nil }
        guard let hi = vals.max(), hi > 0 else {
            return 0...1
        }
        return 0...hi
    }

    /// 最大列数（锯齿行取最长行）。
    public var maxColumns: Int {
        rows.map { $0.count }.max() ?? 0
    }
}
