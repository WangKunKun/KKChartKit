import Foundation

/// 轴标签的系统字体字重意图（schema v4）；不绑定 UIFont 数值或字体资源名称。
/// 跨引擎允许字形差异，不承诺像素一致。nil 字重保留原有默认。
public enum ChartFontWeight: String, Codable, CaseIterable, Sendable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
}

/// 值轴刻度的可序列化展示（schema v4）；不改变刻度坐标、值域、原值或系列单位。
/// number 复用数字展示契约；unit 是显式显示后缀，不从系列推断或换算。
/// HYM 在非空后缀前加空格；engineering 的 k/M/G 加在 unit 之前。
public struct ChartAxisLabelFormat: Codable, Equatable, Sendable {
    public var number: ChartValuePresentation
    public var unit: String?

    /// nil labelFormat 才表示保留引擎原有自动格式；空配置显式使用 number 的默认值。
    /// localeIdentifier 为 nil 时使用宿主当前 locale；可显式指定 locale 以固定展示。
    public init(number: ChartValuePresentation = .init(), unit: String? = nil) {
        self.number = number; self.unit = unit
    }
}
