import Foundation
import UIKit

/// OC 友好的维度桥接（NSObject）。支持 per-dimension 样式覆盖（nil → 用 Theme 统一）。
@objcMembers
public final class HYMRadarDimensionBridge: NSObject {
    @objc public let label: String
    @objc public let value: Double
    @objc public let maxValue: Double
    /// 该维度标签颜色（nil → Theme 统一 labelColor）
    @objc public var labelColor: UIColor?
    /// 该维度标签字体（nil → Theme 统一 labelFont）
    @objc public var labelFont: UIFont?
    /// 该维度数据点颜色（nil → Theme 统一 vertexDotColor）
    @objc public var dataDotColor: UIColor?
    /// 该维度最外圈顶点圆点颜色（nil → Theme 统一 labelDotColor）
    @objc public var labelDotColor: UIColor?
    /// 该维度标题顶点圆点是否显示（nil → 用 Theme 全局；@YES/@NO → 独立覆盖）
    @objc public var showsLabelDot: NSNumber?

    @objc public init(label: String, value: Double, maxValue: Double = 100,
                      labelColor: UIColor? = nil, labelFont: UIFont? = nil,
                      dataDotColor: UIColor? = nil, labelDotColor: UIColor? = nil,
                      showsLabelDot: NSNumber? = nil) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
        self.labelColor = labelColor
        self.labelFont = labelFont
        self.dataDotColor = dataDotColor
        self.labelDotColor = labelDotColor
        self.showsLabelDot = showsLabelDot
        super.init()
    }

    /// 翻译为内部纯 Swift struct
    internal var dimension: RadarDimension {
        RadarDimension(label: label, value: value, maxValue: maxValue,
                       labelColor: labelColor, labelFont: labelFont,
                       dataDotColor: dataDotColor, labelDotColor: labelDotColor,
                       showsLabelDot: showsLabelDot?.boolValue)
    }
}
