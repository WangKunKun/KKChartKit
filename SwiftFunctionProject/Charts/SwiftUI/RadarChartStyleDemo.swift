import SwiftUI

struct RadarChartStyleDemo: View {
    @State private var reset = UUID()
    var body: some View {
        RadarDemoEditor().id(reset).toolbar { Button("恢复默认") { reset = UUID() } }
    }
}

private struct RadarDemoEditor: View {
    @State private var theme = RadarChartTheme()
    @State private var tooltipTheme = HYMChartTooltipTheme()
    @State private var report = DemoChartReport()
    @State private var interaction = DemoInteractionSettings()
    @State private var dimensions = (0..<12).map { RadarDimension(label: "维度 \($0 + 1)", value: Double(40 + $0 * 7 % 60)) }
    @State private var count = 6
    @State private var selected = 0
    @State private var showsScore = true
    @State private var score: Double?
    @State private var ringFill = "不填充"
    @State private var fillA = UIColor.systemPurple.withAlphaComponent(0.5)
    @State private var fillB = UIColor.systemBlue.withAlphaComponent(0.1)
    @State private var height = 320.0
    @State private var animation = 0
    @State private var query = ""
    private var dimension: Binding<RadarDimension> {
        Binding(get: { dimensions[min(selected, count - 1)] }, set: { dimensions[min(selected, count - 1)] = $0 })
    }
    private var model: RadarChartModel {
        RadarChartModel(dimensions: Array(dimensions.prefix(count)), showsCenterScore: showsScore, centerScore: score)
    }
    private var builtTheme: RadarChartTheme {
        var t = theme
        switch ringFill {
        case "渐变": t.gridRingFill = .gradient(from: fillA, to: fillB)
        case "逐圈配色": t.gridRingFill = .colors((0..<max(1, t.gridRingCount)).map { $0.isMultiple(of: 2) ? fillA : fillB })
        default: t.gridRingFill = .none
        }
        return t
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 6) {
                DemoChartHost<RadarChartRenderer>(model: model, theme: builtTheme, interaction: interaction,
                    tooltipTheme: tooltipTheme, report: report, animation: animation)
                    .frame(height: min(height, geometry.size.height * 0.6))
                    .background(theme.showsBackground ? Color(uiColor: theme.backgroundGradientEnd) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius)).padding(.horizontal, 12)
                DemoHitReadout(report: report)
                Button("重播动画") { animation += 1 }.buttonStyle(.bordered)
                Form {
                    TextField("搜索属性名或分组", text: $query)
                    ChartDemoPanel(sections: sections, query: query)
                }
            }
        }
        .navigationTitle("雷达图").navigationBarTitleDisplayMode(.inline)
        .onChange(of: count) { selected = min(selected, $0 - 1) }
    }
    private var sections: [ChartDemoPanel.DemoSection] {
        let d = dimension
        var dimensionItems: [ChartDemoPanel.Item] = [
            DemoProperty.integer("编辑维度（从0开始）", $selected, 0...Double(count - 1)),
            .textField(label: "标签", value: d.label), DemoProperty.number("数值", d.value, 0...200), DemoProperty.number("满分", d.maxValue, 1...200),
            DemoProperty.triState("标题顶点显隐覆盖", d.showsLabelDot)]
        dimensionItems += DemoProperty.color("标签颜色", d.labelColor) + DemoProperty.color("数据点颜色", d.dataDotColor) + DemoProperty.color("标题点颜色", d.labelDotColor)
        dimensionItems += [DemoProperty.enabled("覆盖维度字体", d.labelFont, default: .systemFont(ofSize: 14))]
        if d.wrappedValue.labelFont != nil { dimensionItems += DemoProperty.font("维度字体", DemoProperty.optional(d.labelFont, default: .systemFont(ofSize: 14))) }
        let scoreItems: [ChartDemoPanel.Item] = [.toggle(label: "显示中心分数", value: $showsScore), DemoProperty.enabled("手动中心分数", $score, default: 80), DemoProperty.number("中心分数", DemoProperty.optional($score, default: 80), 0...200)]
        return [
            .init(title: "数据与布局", items: [DemoProperty.integer("维度数量", $count, 3...12), DemoProperty.number("预览高度", $height, 180...500, step: 10)] + scoreItems),
            .init(title: "维度独立样式", items: dimensionItems),
            .init(title: "雷达主题（颜色/网格/选中/装饰环）", items: DemoThemeFields.items($theme)),
            .init(title: "网格填充", items: [.picker(label: "填充模式", selection: $ringFill, options: ["不填充", "渐变", "逐圈配色"]), .color(label: "填充色 A", value: $fillA), .color(label: "填充色 B", value: $fillB)]),
            .init(title: "弹窗与回调", items: [.toggle(label: "弹窗", value: $interaction.tooltip), .picker(label: "弹窗预设", selection: $interaction.popupMode, options: ["内置", "自定义内容", "位置回调"])]),
            .init(title: "弹窗外观", items: DemoThemeFields.items($tooltipTheme))]
    }
}
