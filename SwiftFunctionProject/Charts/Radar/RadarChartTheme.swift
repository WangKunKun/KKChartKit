import UIKit

/// 网格每圈底色模式
public enum GridRingFill {
    /// 不填充（默认）
    case none
    /// 从最外圈(from)到最内圈(to)线性插值
    case gradient(from: UIColor, to: UIColor)
    /// 每圈独立色；数组长度 < gridRingCount 时，超出圈回退为最后一色
    case colors([UIColor])
}

/// 雷达图主题（纯值类型；所有外观集中于此，改色只动这里）
public struct RadarChartTheme: HYMChartTheme {
    public var backgroundGradientStart: UIColor
    public var backgroundGradientEnd:   UIColor
    public var gridColor:   UIColor
    public var axisColor:   UIColor
    public var dataFillColor:   UIColor
    public var dataStrokeColor: UIColor
    public var vertexDotColor:     UIColor
    public var vertexDotRingColor: UIColor
    public var labelColor: UIColor
    public var labelFont:  UIFont
    public var scoreColor: UIColor
    public var scoreFont:  UIFont
    public var scoreSubtitleColor: UIColor
    public var scoreSubtitleFont:  UIFont
    public var scoreSubtitleText:  String
    public var gridRingCount: Int
    public var cardCornerRadius: CGFloat
    public var dataLineWidth: CGFloat
    public var labelOuterPadding: CGFloat
    public var vertexDotRadius: CGFloat
    public var gridRingFill: GridRingFill
    public var showsGridLines: Bool
    public var showsAxes: Bool
    public var showsData: Bool
    public var showsBackground: Bool

    public init(
        backgroundGradientStart: UIColor = UIColor(red: 0x2A/255.0, green: 0x1B/255.0, blue: 0x5C/255.0, alpha: 1),
        backgroundGradientEnd:   UIColor = UIColor(red: 0x4B/255.0, green: 0x2E/255.0, blue: 0xAA/255.0, alpha: 1),
        gridColor:   UIColor = UIColor.white.withAlphaComponent(0.15),
        axisColor:   UIColor = UIColor.white.withAlphaComponent(0.25),
        dataFillColor:   UIColor = UIColor(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0, alpha: 0.35),
        dataStrokeColor: UIColor = UIColor(red: 0xA7/255.0, green: 0x8B/255.0, blue: 0xFA/255.0, alpha: 1),
        vertexDotColor:     UIColor = UIColor(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0, alpha: 1),
        vertexDotRingColor: UIColor = .white,
        labelColor: UIColor = UIColor(red: 0xE0/255.0, green: 0xE7/255.0, blue: 0xFF/255.0, alpha: 1),
        labelFont:  UIFont = .systemFont(ofSize: 14),
        scoreColor: UIColor = .white,
        scoreFont:  UIFont = .boldSystemFont(ofSize: 36),
        scoreSubtitleColor: UIColor = UIColor(red: 0xC7/255.0, green: 0xD2/255.0, blue: 0xFE/255.0, alpha: 1),
        scoreSubtitleFont:  UIFont = .systemFont(ofSize: 13),
        scoreSubtitleText:  String = "综合评分",
        gridRingCount: Int = 5,
        cardCornerRadius: CGFloat = 16,
        dataLineWidth: CGFloat = 2,
        labelOuterPadding: CGFloat = 22,
        vertexDotRadius: CGFloat = 5,
        gridRingFill: GridRingFill = .none,
        showsGridLines: Bool = true,
        showsAxes: Bool = true,
        showsData: Bool = true,
        showsBackground: Bool = true
    ) {
        self.backgroundGradientStart = backgroundGradientStart
        self.backgroundGradientEnd = backgroundGradientEnd
        self.gridColor = gridColor
        self.axisColor = axisColor
        self.dataFillColor = dataFillColor
        self.dataStrokeColor = dataStrokeColor
        self.vertexDotColor = vertexDotColor
        self.vertexDotRingColor = vertexDotRingColor
        self.labelColor = labelColor
        self.labelFont = labelFont
        self.scoreColor = scoreColor
        self.scoreFont = scoreFont
        self.scoreSubtitleColor = scoreSubtitleColor
        self.scoreSubtitleFont = scoreSubtitleFont
        self.scoreSubtitleText = scoreSubtitleText
        self.gridRingCount = gridRingCount
        self.cardCornerRadius = cardCornerRadius
        self.dataLineWidth = dataLineWidth
        self.labelOuterPadding = labelOuterPadding
        self.vertexDotRadius = vertexDotRadius
        self.gridRingFill = gridRingFill
        self.showsGridLines = showsGridLines
        self.showsAxes = showsAxes
        self.showsData = showsData
        self.showsBackground = showsBackground
    }
}
