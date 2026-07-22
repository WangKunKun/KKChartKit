import UIKit

/// OC 友好的雷达主题构造器：属性赋值 → build() 成纯 Swift struct。
/// `GridRingFill` 用字符串 "none"/"gradient"/"colors" + 颜色数组映射，OC 零 Swift 特性依赖。
///
/// 字段覆盖范围：本 Builder 仅暴露最常用外观（4 个显隐开关 + 网格底色 + 4 个常用色）。
/// 其余外观（网格/轴/顶点/标签/分数色、字号、gridRingCount、圆角、线宽、padding、副标题等）
/// 使用 RadarChartTheme 默认值；OC 若需全套自定义，请用 Swift 直接构造 RadarChartTheme。
@objcMembers
public final class HYMRadarThemeBuilder: NSObject {
    // 显隐开关（与 RadarChartTheme 默认值一致）
    @objc public var showsData: Bool = true
    @objc public var showsGridLines: Bool = true
    @objc public var showsAxes: Bool = true
    @objc public var showsBackground: Bool = true

    /// 网格每圈底色模式："none" / "gradient" / "colors"
    @objc public var gridRingFill: String = "none"
    /// gradient: 2 个色 [from, to]；colors: 每圈一色；none: 忽略
    @objc public var gridRingColors: [UIColor] = []

    // 常用颜色（nil 用主题默认）
    @objc public var backgroundGradientStart: UIColor?
    @objc public var backgroundGradientEnd: UIColor?
    @objc public var dataFillColor: UIColor?
    @objc public var dataStrokeColor: UIColor?

    @objc public override init() { super.init() }

    /// 翻译为内部纯 Swift struct
    internal func build() -> RadarChartTheme {
        var t = RadarChartTheme()
        t.showsData = showsData
        t.showsGridLines = showsGridLines
        t.showsAxes = showsAxes
        t.showsBackground = showsBackground
        switch gridRingFill.lowercased() {
        case "gradient":
            if gridRingColors.count >= 2 {
                t.gridRingFill = .gradient(from: gridRingColors[0], to: gridRingColors[1])
            }
        case "colors":
            if !gridRingColors.isEmpty {
                t.gridRingFill = .colors(gridRingColors)
            }
        default:
            t.gridRingFill = .none
        }
        if let v = backgroundGradientStart { t.backgroundGradientStart = v }
        if let v = backgroundGradientEnd { t.backgroundGradientEnd = v }
        if let v = dataFillColor { t.dataFillColor = v }
        if let v = dataStrokeColor { t.dataStrokeColor = v }
        return t
    }
}
