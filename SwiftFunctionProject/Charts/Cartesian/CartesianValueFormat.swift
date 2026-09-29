import Foundation

/// 展示格式，不改变原始数据、值域或堆叠计算。值类型可在任意线程独立使用。
public struct CartesianValueFormat: Equatable {
    public enum Scale: String, CaseIterable { case none, engineering }
    public enum Rounding: String, CaseIterable { case nearest, towardZero }
    public var scale: Scale = .none
    public var rounding: Rounding = .nearest
    public var maximumFractionDigits: Int = 2
    public var showsAbsoluteValue = false
    public var currencySymbol: String = ""
    /// nil 使用调用时的 Locale.current。
    public var localeIdentifier: String?
    public var usesGroupingSeparator = true
    public init() {}

    /// 格式化有限值；nil/NaN/Infinity 返回“无数据”。精度钳制为 0...12。
    /// engineering 按绝对值选择 k/M/G；单位由系列提供，例如 W → kW。
    public func string(from value: Double?, unit: String? = nil) -> String {
        guard var value, value.isFinite else { return "无数据" }
        if showsAbsoluteValue { value = abs(value) }
        var prefix = ""
        if scale == .engineering {
            for (threshold, symbol) in [(1e9, "G"), (1e6, "M"), (1e3, "k")] where abs(value) >= threshold {
                value /= threshold; prefix = symbol; break
            }
        }
        let formatter = NumberFormatter()
        formatter.locale = localeIdentifier.map(Locale.init(identifier:)) ?? .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = usesGroupingSeparator
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = min(12, max(0, maximumFractionDigits))
        formatter.roundingMode = rounding == .towardZero ? .down : .halfUp
        let number = formatter.string(from: NSNumber(value: value)) ?? String(value)
        var result = number
        if !currencySymbol.isEmpty {
            let minus = formatter.minusSign ?? "-"
            result = number.hasPrefix(minus)
                ? minus + currencySymbol + String(number.dropFirst(minus.count)) : currencySymbol + number
        }
        let suffix = prefix + (unit ?? "")
        return result + (suffix.isEmpty ? "" : " " + suffix)
    }
}
