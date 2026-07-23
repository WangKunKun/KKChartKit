import Foundation
import CoreGraphics
import UIKit

/// 单个维度（纯值类型）
public struct RadarDimension {
    /// 顶点文案，如「进攻」
    public var label: String
    /// 当前值
    public var value: Double
    /// 满分值（用于归一化），默认 100
    public var maxValue: Double
    /// 该维度标签颜色（nil → 用 Theme 统一 labelColor）
    public var labelColor: UIColor?
    /// 该维度标签字体（nil → 用 Theme 统一 labelFont）
    public var labelFont: UIFont?
    /// 该维度数据点颜色（nil → 用 Theme 统一 vertexDotColor）
    public var dataDotColor: UIColor?
    /// 该维度最外圈顶点圆点颜色（nil → 用 Theme 统一 labelDotColor）
    public var labelDotColor: UIColor?
    /// 该维度标题顶点圆点是否显示（nil → 用 Theme 统一 showsLabelDots；独立覆盖）
    public var showsLabelDot: Bool?

    public init(label: String, value: Double, maxValue: Double = 100,
                labelColor: UIColor? = nil, labelFont: UIFont? = nil,
                dataDotColor: UIColor? = nil, labelDotColor: UIColor? = nil,
                showsLabelDot: Bool? = nil) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
        self.labelColor = labelColor
        self.labelFont = labelFont
        self.dataDotColor = dataDotColor
        self.labelDotColor = labelDotColor
        self.showsLabelDot = showsLabelDot
    }

    /// 归一化比值 [0,1]，越界裁剪（内部使用）
    public var normalized: CGFloat {
        let m = maxValue > 0 ? maxValue : 1
        return CGFloat(max(0, min(1, value / m)))
    }
}

/// 雷达图数据（theme 分离，由 configure(model:theme:) 单独传入）
public struct RadarChartModel: HYMChartModel {
    public var dimensions: [RadarDimension]
    public var showsCenterScore: Bool
    /// nil = 自动按各维度归一化均值算；非 nil = 用传入值
    public var centerScore: Double?

    public init(dimensions: [RadarDimension],
                showsCenterScore: Bool = true,
                centerScore: Double? = nil) {
        self.dimensions = dimensions
        self.showsCenterScore = showsCenterScore
        self.centerScore = centerScore
    }
}

/// 中心分数三态解析（纯函数，便于 DEBUG 自检）
public func resolvedCenterScore(_ model: RadarChartModel) -> Double? {
    guard model.showsCenterScore else { return nil }
    if let manual = model.centerScore { return manual }
    guard !model.dimensions.isEmpty else { return nil }
    let sum = model.dimensions.reduce(0.0) { $0 + ($1.maxValue > 0 ? $1.value / $1.maxValue : 0) }
    let avg = sum / Double(model.dimensions.count)
    let scale = model.dimensions.first?.maxValue ?? 100
    return avg * scale
}
