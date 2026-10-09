import SwiftUI

/// 按稳定值轴 ID 保存两种示例对象；关闭次轴只暂时排除其标注，恢复时保留配置。
struct ChartSpecificationAnnotationDemoSettings {
    var lineEnabled = false
    var bandEnabled = false
    var line: ChartPlotLine
    var band: ChartPlotBand
    init(axisID: String) {
        let labelStyle = ChartAnnotationLabelStyle(color: .init(red: 0, green: 0, blue: 0), fontSize: 13,
            fontWeight: .semibold, backgroundColor: .init(red: 1, green: 1, blue: 1, alpha: 0.95), alignment: .leading)
        line = .init(id: "limit-" + axisID, valueAxisID: axisID, value: axisID == "power" ? 40 : 10,
                     color: .init(red: 0.8, green: 0.1, blue: 0.2), lineWidth: 2, strokePattern: .dashed,
                     label: "上限 " + axisID, labelStyle: labelStyle)
        band = .init(id: "range-" + axisID, valueAxisID: axisID, from: axisID == "power" ? 10 : -5,
                     to: axisID == "power" ? 30 : 5, color: .init(red: 0, green: 0.6, blue: 0.3, alpha: 0.18),
                     label: "区间 " + axisID, labelStyle: labelStyle)
    }
}

struct ChartSpecificationAnnotationControls: View {
    @Binding var settings: [String: ChartSpecificationAnnotationDemoSettings]
    let axisIDs: [String]
    @State private var axisID = "power"
    @State private var editsBand = false
    private var activeID: String { axisIDs.contains(axisID) ? axisID : "power" }
    private func binding<T>(_ key: WritableKeyPath<ChartSpecificationAnnotationDemoSettings, T>) -> Binding<T> {
        .init(get: { (settings[activeID] ?? .init(axisID: activeID))[keyPath: key] }, set: {
            settings[activeID, default: .init(axisID: activeID)][keyPath: key] = $0
        })
    }
    private var style: Binding<ChartAnnotationLabelStyle> {
        editsBand ? binding(\.band.labelStyle) : binding(\.line.labelStyle)
    }
    private var label: Binding<String?> { editsBand ? binding(\.band.label) : binding(\.line.label) }
    private var visible: Binding<Bool> { editsBand ? binding(\.band.isVisible) : binding(\.line.isVisible) }
    private var color: Binding<ChartRGBA?> { editsBand ? binding(\.band.color) : binding(\.line.color) }

    var body: some View {
        Section("值轴标线／色带 · 通用模型 v5") {
            Picker("标注值轴", selection: Binding(get: { activeID }, set: { axisID = $0 })) {
                ForEach(axisIDs, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.menu).accessibilityIdentifier("specification.annotationAxis")
            Toggle("启用标线", isOn: binding(\.lineEnabled)).accessibilityIdentifier("specification.plotLine")
            Toggle("启用色带", isOn: binding(\.bandEnabled)).accessibilityIdentifier("specification.plotBand")
            let current = settings[activeID] ?? .init(axisID: activeID)
            Text("标注 \(activeID) · line=\(current.lineEnabled ? "on" : "off") · band=\(current.bandEnabled ? "on" : "off") · \(editsBand ? current.band.id : current.line.id)")
                .font(.caption).accessibilityIdentifier("specification.annotationStatus")
            Text("坐标采用绑定值轴单位（百分比用 %）；不扩大值域。带体在系列后，线与文字在前；偏移/对齐为屏幕方向。无序区间会报错，不交换端点。")
                .font(.caption)
            DisclosureGroup("标注详细配置") {
                Picker("编辑标注", selection: $editsBand) {
                    Text("标线").tag(false); Text("色带").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("specification.annotationKind")
                Toggle("标注可见", isOn: visible).accessibilityIdentifier("specification.annotationVisible")
                if editsBand {
                    number("下界", binding(\.band.from)); number("上界", binding(\.band.to))
                } else {
                    number("标线值", binding(\.line.value))
                    Toggle("覆盖标线宽度", isOn: .init(get: { binding(\.line.lineWidth).wrappedValue != nil }, set: {
                        binding(\.line.lineWidth).wrappedValue = $0 ? 2 : nil
                    }))
                    if binding(\.line.lineWidth).wrappedValue != nil {
                        number("线宽", .init(get: { binding(\.line.lineWidth).wrappedValue ?? 1 }, set: { binding(\.line.lineWidth).wrappedValue = $0 }))
                    }
                    Picker("线型", selection: binding(\.line.strokePattern)) {
                        Text("实线").tag(ChartStrokePattern.solid)
                        Text("虚线").tag(ChartStrokePattern.dashed)
                        Text("点线").tag(ChartStrokePattern.dotted)
                    }
                }
                optionalColor("标注颜色", color)
                Toggle("显示标注文字", isOn: .init(get: { label.wrappedValue != nil }, set: { label.wrappedValue = $0 ? "标注 " + activeID : nil }))
                if label.wrappedValue != nil {
                    TextField("标注文字", text: .init(get: { label.wrappedValue ?? "" }, set: { label.wrappedValue = $0 }))
                    labelControls
                }
            }.accessibilityIdentifier("specification.annotationDetails")
            Button("恢复当前轴标注") { settings.removeValue(forKey: activeID) }
                .accessibilityIdentifier("specification.annotationReset")
        }
    }

    private var labelControls: some View {
        Group {
            optionalColor("文字颜色", style.color)
            optionalColor("文字底色", style.backgroundColor)
            Toggle("覆盖文字字号", isOn: .init(get: { style.wrappedValue.fontSize != nil }, set: { style.wrappedValue.fontSize = $0 ? 13 : nil }))
            if style.wrappedValue.fontSize != nil {
                number("字号", .init(get: { style.wrappedValue.fontSize ?? 13 }, set: { style.wrappedValue.fontSize = $0 }))
            }
            Picker("标注字重", selection: style.fontWeight) {
                Text("继承").tag(ChartFontWeight?.none)
                ForEach(ChartFontWeight.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
            }
            Picker("屏幕水平对齐", selection: style.alignment) {
                ForEach(ChartAnnotationAlignment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("屏幕垂直对齐", selection: style.verticalAlignment) {
                ForEach(ChartAnnotationVerticalAlignment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            number("屏幕 X 偏移", style.offsetX); number("屏幕 Y 偏移", style.offsetY)
            Picker("文字边界", selection: style.bounds) {
                Text("钳入绘图区").tag(ChartAnnotationBounds.clamp)
                Text("越界隐藏").tag(ChartAnnotationBounds.hide)
            }.accessibilityIdentifier("specification.annotationBounds")
        }
    }
    private func number(_ title: String, _ value: Binding<Double>) -> some View {
        HStack { Text(title); TextField(title, value: value, format: .number).multilineTextAlignment(.trailing) }
    }
    private func optionalColor(_ title: String, _ value: Binding<ChartRGBA?>) -> some View {
        VStack {
            Toggle("覆盖" + title, isOn: .init(get: { value.wrappedValue != nil }, set: {
                value.wrappedValue = $0 ? .init(red: 0.15, green: 0.45, blue: 0.8) : nil
            }))
            if value.wrappedValue != nil {
                ColorPicker(title, selection: .init(get: {
                    let c = value.wrappedValue ?? .init(red: 0, green: 0, blue: 0)
                    return Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
                }, set: {
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    if UIColor($0).getRed(&r, green: &g, blue: &b, alpha: &a) {
                        value.wrappedValue = .init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
                    }
                }))
            }
        }
    }
}
