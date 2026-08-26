import UIKit

/// 轴系图表主题（纯值类型；所有外观集中于此）。折线/柱状等共用，
/// 各类型特有外观（如柱宽）由该类型 Theme 扩展属性补充——阶段 1 起按需拆分。
public struct CartesianChartTheme: HYMChartTheme {
    // —— 整体 ——
    /// 背景（nil 透明）。
    public var backgroundColor: UIColor?
    public var backgroundCornerRadius: CGFloat
    public var contentInset: UIEdgeInsets
    /// 标题颜色/字体（model.title 非 nil 时渲染）。
    public var titleColor: UIColor
    public var titleFont: UIFont

    // —— 网格 ——
    public var showsHorizontalGridlines: Bool
    public var showsVerticalGridlines: Bool
    public var gridColor: UIColor
    public var gridLineWidth: CGFloat

    // —— 轴 ——
    public var axisLineColor: UIColor
    public var axisLineWidth: CGFloat
    public var tickLabelColor: UIColor
    public var tickLabelFont: UIFont
    /// 刻度 label 与 plot 边缘间距。
    public var axisLabelGap: CGFloat

    // —— 系列（折线阶段 0 直接消费；多系列配色阶段 3 引入调色板）——
    /// series 未指定颜色时的默认色。
    public var seriesColor: UIColor
    public var lineWidth: CGFloat
    /// 是否绘制数据点圆点。
    public var showsPoints: Bool
    public var pointRadius: CGFloat
    public var pointColor: UIColor?

    // —— 行为 ——
    public var showsEntranceAnimation: Bool
    public var showsTooltipOnHit: Bool

    public init(
        backgroundColor: UIColor? = nil,
        backgroundCornerRadius: CGFloat = 0,
        contentInset: UIEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
        titleColor: UIColor = UIColor(red: 0.23, green: 0.25, blue: 0.28, alpha: 1),
        titleFont: UIFont = .systemFont(ofSize: 14, weight: .semibold),
        showsHorizontalGridlines: Bool = true,
        showsVerticalGridlines: Bool = false,
        gridColor: UIColor = UIColor(white: 0.9, alpha: 1),
        gridLineWidth: CGFloat = 0.5,
        axisLineColor: UIColor = UIColor(white: 0.78, alpha: 1),
        axisLineWidth: CGFloat = 1,
        tickLabelColor: UIColor = UIColor(red: 0.35, green: 0.38, blue: 0.4, alpha: 1),
        tickLabelFont: UIFont = .systemFont(ofSize: 10),
        axisLabelGap: CGFloat = 4,
        seriesColor: UIColor = UIColor(red: 0x21/255.0, green: 0x6e/255.0, blue: 0x39/255.0, alpha: 1),
        lineWidth: CGFloat = 2,
        showsPoints: Bool = true,
        pointRadius: CGFloat = 3,
        pointColor: UIColor? = nil,
        showsEntranceAnimation: Bool = true,
        showsTooltipOnHit: Bool = true
    ) {
        self.backgroundColor = backgroundColor
        self.backgroundCornerRadius = max(0, backgroundCornerRadius)
        self.contentInset = contentInset
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.showsHorizontalGridlines = showsHorizontalGridlines
        self.showsVerticalGridlines = showsVerticalGridlines
        self.gridColor = gridColor
        self.gridLineWidth = max(0, gridLineWidth)
        self.axisLineColor = axisLineColor
        self.axisLineWidth = max(0, axisLineWidth)
        self.tickLabelColor = tickLabelColor
        self.tickLabelFont = tickLabelFont
        self.axisLabelGap = max(0, axisLabelGap)
        self.seriesColor = seriesColor
        self.lineWidth = max(0, lineWidth)
        self.showsPoints = showsPoints
        self.pointRadius = max(0, pointRadius)
        self.pointColor = pointColor
        self.showsEntranceAnimation = showsEntranceAnimation
        self.showsTooltipOnHit = showsTooltipOnHit
    }
}
