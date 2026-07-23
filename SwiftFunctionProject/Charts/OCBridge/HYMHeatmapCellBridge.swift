import UIKit

/// OC 友好的热力图单格桥接：包装内部 `HeatmapCell`。
@objcMembers
public final class HYMHeatmapCellBridge: NSObject {
    @objc public var value: Double
    @objc public var maxValue: Double
    @objc public var color: UIColor?

    @objc public init(value: Double, maxValue: Double = 100, color: UIColor? = nil) {
        self.value = value
        self.maxValue = maxValue
        self.color = color
        super.init()
    }

    internal var heatCell: HeatmapCell {
        HeatmapCell(value: value, maxValue: maxValue, color: color)
    }
}
