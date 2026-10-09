import UIKit

/// 每轴独立展示；nil 样式继承 theme，不影响值域、网格或数据索引。
public struct CartesianAxisStyle {
    public var labelColor: UIColor?
    public var labelFont: UIFont?
    public var lineColor: UIColor?
    /// nil 或非有限/负数继承主题；0 为零宽线。
    public var lineWidth: CGFloat?
    public var showsLabels: Bool
    public var showsLine: Bool

    public init(labelColor: UIColor? = nil, labelFont: UIFont? = nil,
                lineColor: UIColor? = nil, lineWidth: CGFloat? = nil,
                showsLabels: Bool = true, showsLine: Bool = true) {
        self.labelColor = labelColor; self.labelFont = labelFont
        self.lineColor = lineColor; self.lineWidth = lineWidth
        self.showsLabels = showsLabels; self.showsLine = showsLine
    }

    func resolving(_ theme: CartesianChartTheme) -> CartesianChartTheme {
        var result = theme
        if let labelColor { result.tickLabelColor = labelColor }
        if let labelFont, labelFont.pointSize.isFinite, labelFont.pointSize > 0 {
            result.tickLabelFont = labelFont
        }
        if let lineColor { result.axisLineColor = lineColor }
        if let lineWidth, lineWidth.isFinite, lineWidth >= 0 { result.axisLineWidth = lineWidth }
        return result
    }
}
