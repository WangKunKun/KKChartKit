import UIKit

/// 通用图表弹窗外观主题（纯值类型；所有图表的 tooltip 外观集中于此）。
///
/// tooltip 外观归通用容器（`HYMChartView.tooltipTheme`），不嵌入各图表 Theme，
/// 以保持各图表 Theme 只承载自身图表外观。
public struct HYMChartTooltipTheme {
    /// 背景色。
    public var backgroundColor: UIColor
    /// 文字色。
    public var textColor: UIColor
    /// 文字字体。
    public var font: UIFont
    /// 背景圆角。
    public var cornerRadius: CGFloat
    /// 文字内边距。
    public var contentInset: UIEdgeInsets
    /// 长文本换行上限（保证弹窗窄于典型图表宽度，配合贴边规则不溢出 container）。
    public var maxWidth: CGFloat
    /// 是否绘制指向锚点的小箭头。
    public var showsArrow: Bool
    /// 箭头尺寸（宽 × 高）。
    public var arrowSize: CGSize
    /// 阴影色；nil = 无阴影。
    public var shadowColor: UIColor?
    /// 是否启用显示/隐藏的淡入 + 轻缩放动画。
    public var showsAnimation: Bool
    /// 弹窗与锚点间距。
    public var gap: CGFloat

    public init(backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.8),
                textColor: UIColor = .white,
                font: UIFont = .systemFont(ofSize: 12),
                cornerRadius: CGFloat = 6,
                contentInset: UIEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8),
                maxWidth: CGFloat = 180,
                showsArrow: Bool = true,
                arrowSize: CGSize = CGSize(width: 10, height: 6),
                shadowColor: UIColor? = UIColor.black.withAlphaComponent(0.15),
                showsAnimation: Bool = true,
                gap: CGFloat = 6) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.font = font
        self.cornerRadius = cornerRadius
        self.contentInset = contentInset
        self.maxWidth = maxWidth
        self.showsArrow = showsArrow
        self.arrowSize = arrowSize
        self.shadowColor = shadowColor
        self.showsAnimation = showsAnimation
        self.gap = gap
    }

    /// 默认主题。
    public static let `default` = HYMChartTooltipTheme()
}
