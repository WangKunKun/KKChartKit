import Foundation
import CoreGraphics

/// 单个维度（纯值类型）
public struct RadarDimension {
    /// 顶点文案，如「进攻」
    public var label: String
    /// 当前值
    public var value: Double
    /// 满分值（用于归一化），默认 100
    public var maxValue: Double

    public init(label: String, value: Double, maxValue: Double = 100) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
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
