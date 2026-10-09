import Foundation

/// 标注文字的屏幕水平对齐；leading/trailing 指屏幕左/右，不随 RTL 或水平图反转。
/// automatic 保留引擎默认位置；其余以标线路径/裁剪后色带矩形为参考。
public enum ChartAnnotationAlignment: String, Codable, CaseIterable, Sendable {
    case automatic, leading, center, trailing
}

/// 标注文字的屏幕垂直对齐，不是数据坐标方向。
public enum ChartAnnotationVerticalAlignment: String, Codable, CaseIterable, Sendable {
    case automatic, top, center, bottom
}

/// 文字越界策略。clamp 限宽、尾部截断并钳入绘图区，高度不足则隐藏；hide 完整文本越界即隐藏。
public enum ChartAnnotationBounds: String, Codable, CaseIterable, Sendable { case clamp, hide }

/// schema v5 标注文字样式；不参与值域、数据、命中或图例。尺寸和偏移使用屏幕逻辑点。
/// nil 继承引擎默认：HYM 文字跟随标注色（色带文字取不透明 RGB），主题刻度字号/system medium，无底色。
public struct ChartAnnotationLabelStyle: Codable, Equatable, Sendable {
    public var color: ChartRGBA?
    public var fontSize: Double?
    public var fontWeight: ChartFontWeight?
    public var backgroundColor: ChartRGBA?
    public var alignment: ChartAnnotationAlignment
    public var verticalAlignment: ChartAnnotationVerticalAlignment
    /// 先对齐再偏移、最后处理边界；有限且绝对值不超过 1e9，避免后端静默钳制偏移。
    public var offsetX: Double
    public var offsetY: Double
    public var bounds: ChartAnnotationBounds

    /// 创建文字覆盖；字号须为正有限值，颜色为 sRGB。任意线程可构造值，同一变量由调用方同步。
    public init(color: ChartRGBA? = nil, fontSize: Double? = nil, fontWeight: ChartFontWeight? = nil,
                backgroundColor: ChartRGBA? = nil, alignment: ChartAnnotationAlignment = .automatic,
                verticalAlignment: ChartAnnotationVerticalAlignment = .automatic,
                offsetX: Double = 0, offsetY: Double = 0, bounds: ChartAnnotationBounds = .clamp) {
        self.color = color; self.fontSize = fontSize; self.fontWeight = fontWeight
        self.backgroundColor = backgroundColor; self.alignment = alignment
        self.verticalAlignment = verticalAlignment; self.offsetX = offsetX; self.offsetY = offsetY; self.bounds = bounds
    }
}

/// schema v5 值轴标线。坐标为绑定轴的逻辑值（百分比图使用百分数），绝不扩展值域。
/// 标线及文字固定在系列上方；数组顺序即同类绘制顺序。不支持 X 标注、任意 zIndex 或可执行格式化。
public struct ChartPlotLine: Codable, Equatable, Sendable {
    /// 在 plotLines + plotBands 中统一非空唯一；不与显示文字或数组下标绑定。
    public var id: String
    public var valueAxisID: String
    public var value: Double
    /// 隐藏仍校验并保留源配置，不传入原生绘制数组；不改变数学数据。
    public var isVisible: Bool
    /// nil 接受引擎默认色；HYM 为 systemRed。
    public var color: ChartRGBA?
    /// 非负有限逻辑点；nil 接受引擎默认（HYM 为 1）。
    public var lineWidth: Double?
    public var strokePattern: ChartStrokePattern
    /// nil/空文字不画标签。非空文字按 labelStyle 布局，不自动加单位。
    public var label: String?
    public var labelStyle: ChartAnnotationLabelStyle

    /// 创建标线；引用、坐标及样式由所属 ChartSpecification.validate() 统一验证。
    public init(id: String, valueAxisID: String, value: Double, isVisible: Bool = true,
                color: ChartRGBA? = nil, lineWidth: Double? = nil, strokePattern: ChartStrokePattern = .solid,
                label: String? = nil, labelStyle: ChartAnnotationLabelStyle = .init()) {
        self.id = id; self.valueAxisID = valueAxisID; self.value = value; self.isVisible = isVisible
        self.color = color; self.lineWidth = lineWidth; self.strokePattern = strokePattern
        self.label = label; self.labelStyle = labelStyle
    }
}

/// schema v5 值轴色带。要求有限 from < to，不替调用者交换端点；部分越界裁剪，完全越界不画。
/// 带体固定在系列后、文字在系列前；不扩展值域，不生成数据、命中或图例项。
public struct ChartPlotBand: Codable, Equatable, Sendable {
    public var id: String
    public var valueAxisID: String
    public var from: Double
    public var to: Double
    public var isVisible: Bool
    /// nil 接受引擎默认；HYM 为 systemGreen alpha 0.12。显式 alpha 只应用一次。
    public var color: ChartRGBA?
    public var label: String?
    public var labelStyle: ChartAnnotationLabelStyle

    /// 创建色带。身份在所有标注中唯一，轴通过稳定 ID 绑定；隐藏配置同样必须合法。
    public init(id: String, valueAxisID: String, from: Double, to: Double, isVisible: Bool = true,
                color: ChartRGBA? = nil, label: String? = nil, labelStyle: ChartAnnotationLabelStyle = .init()) {
        self.id = id; self.valueAxisID = valueAxisID; self.from = from; self.to = to; self.isVisible = isVisible
        self.color = color; self.label = label; self.labelStyle = labelStyle
    }
}

extension ChartSpecification {
    // 与核心版本/系列校验分开，保持 Foundation-only，不调用原生几何或归一化非法输入。
    func annotationValidationIssues() -> [ChartSpecificationIssue] {
        var issues: [ChartSpecificationIssue] = []
        func invalid(_ path: String, _ message: String) { issues.append(.init(code: .invalidInput, path: path, message: message)) }
        func color(_ value: ChartRGBA?, _ path: String) {
            if let value, [value.red, value.green, value.blue, value.alpha].contains(where: { !$0.isFinite || !(0...1).contains($0) }) {
                invalid(path, "sRGB/alpha 分量必须在 0...1 内")
            }
        }
        func finite(_ value: Double, _ path: String) { if !value.isFinite { invalid(path, "标注坐标须为有限值") } }
        var ids = Set<String>(); let axes = Set(valueAxes.map(\.id))
        func common(_ id: String, _ axis: String, _ rgba: ChartRGBA?, _ style: ChartAnnotationLabelStyle, _ path: String) {
            if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !ids.insert(id).inserted { invalid(path + ".id", "标线/色带身份必须非空且统一唯一") }
            if !axes.contains(axis) { invalid(path + ".valueAxisID", "必须引用已声明的值轴 ID；不支持 domain 标注") }
            color(rgba, path + ".color"); color(style.color, path + ".labelStyle.color")
            color(style.backgroundColor, path + ".labelStyle.backgroundColor")
            if let size = style.fontSize, !size.isFinite || size <= 0 { invalid(path + ".labelStyle.fontSize", "字号须为正有限值") }
            for (key, offset) in [("offsetX", style.offsetX), ("offsetY", style.offsetY)] where !offset.isFinite || abs(offset) > 1e9 {
                invalid(path + ".labelStyle." + key, "屏幕偏移须为有限值，绝对值不超过 1e9")
            }
        }
        for (key, isEmpty) in [("plotLines", plotLines.isEmpty), ("plotBands", plotBands.isEmpty)] where schemaVersion < 5 && !isEmpty {
            invalid(key, "值轴标注要求 schemaVersion 5；不能静默降级")
        }
        for (index, line) in plotLines.enumerated() {
            let path = "plotLines[\(index)]"
            common(line.id, line.valueAxisID, line.color, line.labelStyle, path); finite(line.value, path + ".value")
            if let width = line.lineWidth, !width.isFinite || width < 0 { invalid(path + ".lineWidth", "线宽须为非负有限值") }
        }
        for (index, band) in plotBands.enumerated() {
            let path = "plotBands[\(index)]"
            common(band.id, band.valueAxisID, band.color, band.labelStyle, path)
            finite(band.from, path + ".from"); finite(band.to, path + ".to")
            if band.from >= band.to { invalid(path, "区间须满足 from < to；不自动交换或扩展端点") }
        }
        return issues
    }
}
