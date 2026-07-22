import Foundation

/// OC 友好的维度桥接（NSObject）
@objcMembers
public final class HYMRadarDimensionBridge: NSObject {
    @objc public let label: String
    @objc public let value: Double
    @objc public let maxValue: Double

    @objc public init(label: String, value: Double, maxValue: Double = 100) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
        super.init()
    }

    /// 翻译为内部纯 Swift struct
    internal var dimension: RadarDimension {
        RadarDimension(label: label, value: value, maxValue: maxValue)
    }
}
