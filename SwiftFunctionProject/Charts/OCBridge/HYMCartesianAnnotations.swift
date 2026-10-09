import UIKit

@objc public enum HYMCartesianAnnotationAlignment: Int { case automatic, leading, center, trailing }
@objc public enum HYMCartesianAnnotationVerticalAlignment: Int { case automatic, top, center, bottom }
@objc public enum HYMCartesianAnnotationBounds: Int { case clamp, hide }

/// 标注文字值对象；修改后调用 bridge.update。偏移以屏幕 pt 为单位。
@objcMembers public final class HYMCartesianAnnotationLabelStyle: NSObject {
    public var color: UIColor?
    public var font: UIFont?
    public var backgroundColor: UIColor?
    public var alignment: HYMCartesianAnnotationAlignment = .automatic
    public var verticalAlignment: HYMCartesianAnnotationVerticalAlignment = .automatic
    public var offset: CGSize = .zero
    public var bounds: HYMCartesianAnnotationBounds = .clamp
    func build() -> CartesianAnnotationLabelStyle {
        let horizontal: CartesianAnnotationAlignment
        switch alignment {
        case .automatic: horizontal = .automatic
        case .leading: horizontal = .leading
        case .center: horizontal = .center
        case .trailing: horizontal = .trailing
        }
        let vertical: CartesianAnnotationVerticalAlignment
        switch verticalAlignment {
        case .automatic: vertical = .automatic
        case .top: vertical = .top
        case .center: vertical = .center
        case .bottom: vertical = .bottom
        }
        return .init(color: color, font: font, backgroundColor: backgroundColor,
                     alignment: horizontal, verticalAlignment: vertical, offset: offset,
                     bounds: bounds == .clamp ? .clamp : .hide)
    }
}

@objcMembers public final class HYMCartesianPlotLine: NSObject {
    public var value: Double = 0
    public var yAxisIndex = 0
    public var color: UIColor = .systemRed
    public var lineWidth: CGFloat = 1
    /// LineDashStyle rawValue，例如 solid / dash / dot；非法值回退 solid。
    public var dashStyle = "solid"
    public var label: String?
    public var labelStyle = HYMCartesianAnnotationLabelStyle()
    func build() -> CartesianPlotLine {
        .init(value: value, yAxisIndex: yAxisIndex, color: color, lineWidth: lineWidth,
              dashStyle: LineDashStyle(rawValue: dashStyle) ?? .solid,
              label: label, labelStyle: labelStyle.build())
    }
}

@objcMembers public final class HYMCartesianPlotBand: NSObject {
    public var from: Double = 0
    public var to: Double = 0
    public var yAxisIndex = 0
    public var color: UIColor = .systemGreen.withAlphaComponent(0.12)
    public var label: String?
    public var labelStyle = HYMCartesianAnnotationLabelStyle()
    func build() -> CartesianPlotBand {
        .init(from: from, to: to, yAxisIndex: yAxisIndex, color: color,
              label: label, labelStyle: labelStyle.build())
    }
}

/// 与弹窗开关独立的主体覆盖层，默认关闭；修改后调用 configure/update。
@objcMembers public final class HYMCartesianSelectionStyle: NSObject {
    public var isEnabled = false
    public var color: UIColor = .systemYellow
    public var lineWidth: CGFloat = 2
    public var fillOpacity: CGFloat = 0.16
    public var pointRadius: CGFloat = 7
    func build() -> CartesianSelectionStyle {
        .init(isEnabled: isEnabled, color: color, lineWidth: lineWidth,
              fillOpacity: fillOpacity, pointRadius: pointRadius)
    }
}
