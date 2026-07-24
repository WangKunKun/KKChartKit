import UIKit

/// OC 友好的热力图单格桥接：包装内部 `HeatmapCell`。
@objcMembers
public final class HYMHeatmapCellBridge: NSObject {
    @objc public var value: Double
    @objc public var color: UIColor?
    /// 是否有效；NO = 无效占位（占位不绘制、不命中、不参与色阶）。默认 YES。
    @objc public var valid: Bool
    /// 该格子弹窗文本；nil → 默认格式化 value。
    @objc public var tooltipText: String?

    @objc public init(value: Double, color: UIColor? = nil,
                      valid: Bool = true, tooltipText: String? = nil) {
        self.value = value
        self.color = color
        self.valid = valid
        self.tooltipText = tooltipText
        super.init()
    }

    internal var heatCell: HeatmapCell {
        HeatmapCell(value: value, color: color, isValid: valid, tooltipText: tooltipText)
    }
}
