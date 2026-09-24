import SwiftUI

struct HeatmapChartDemo: View {
    @State private var reset = UUID()
    var body: some View {
        HeatmapDemoEditor().id(reset).toolbar { Button("恢复默认") { reset = UUID() } }
    }
}

private struct HeatmapDemoEditor: View {
    @State private var theme = HeatmapChartTheme()
    @State private var tooltipTheme = HYMChartTooltipTheme()
    @State private var interaction = DemoInteractionSettings()
    @State private var report = DemoChartReport()
    @State private var rowCount = 5
    @State private var columnCount = 10
    @State private var selectedRow = 0
    @State private var selectedColumn = 0
    @State private var cells = (0..<12).map { r in (0..<30).map { c in HeatmapCell(value: Double((r * 37 + c * 17) % 101), isValid: (r + c) % 13 != 0) } }
    @State private var ragged = true
    @State private var rowLabels = "W1,W2,W3,W4,W5"
    @State private var columnLabels = "一,二,三,四,五,六,七,八,九,十"
    @State private var fixedRange = false
    @State private var lower = 0.0
    @State private var upper = 100.0
    @State private var scale = "渐变"
    @State private var low = UIColor.systemGreen.withAlphaComponent(0.1)
    @State private var middle = UIColor.systemYellow
    @State private var high = UIColor.systemGreen
    @State private var stopLow = 0.0
    @State private var stopMiddle = 50.0
    @State private var stopHigh = 100.0
    @State private var alignment = "leading"
    @State private var height = 240.0
    @State private var animation = 0
    @State private var query = ""
    private var editableColumnCount: Int {
        ragged && min(selectedRow, rowCount - 1) == rowCount - 1 ? max(1, columnCount / 2) : columnCount
    }
    private var cell: Binding<HeatmapCell> {
        Binding(get: { cells[min(selectedRow, rowCount - 1)][min(selectedColumn, editableColumnCount - 1)] }, set: { cells[min(selectedRow, rowCount - 1)][min(selectedColumn, editableColumnCount - 1)] = $0 })
    }
    private var model: HeatmapChartModel {
        let rows = (0..<rowCount).map { r in Array(cells[r].prefix(ragged && r == rowCount - 1 ? max(1, columnCount / 2) : columnCount)) }
        return HeatmapChartModel(rows: rows, valueRange: fixedRange ? min(lower, upper)...max(lower, upper) : nil,
            rowLabels: rowLabels.isEmpty ? nil : rowLabels.components(separatedBy: ","),
            columnLabels: columnLabels.isEmpty ? nil : columnLabels.components(separatedBy: ","))
    }
    private var builtTheme: HeatmapChartTheme {
        var t = theme
        t.horizontalAlignment = alignment == "leading" ? .leading : alignment == "center" ? .center : .trailing
        switch scale {
        case "单色透明度": t.colorScale = .alpha(high)
        case "分段": t.colorScale = .stops([(stopLow, low), (stopMiddle, middle), (stopHigh, high)].sorted { $0.0 < $1.0 })
        case "不映射": t.colorScale = .none
        default: t.colorScale = .gradient(low: low, high: high)
        }
        return t
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 6) {
                DemoChartHost<HeatmapChartRenderer>(model: model, theme: builtTheme, interaction: interaction,
                    tooltipTheme: tooltipTheme, report: report, animation: animation)
                    .frame(height: min(height, geometry.size.height * 0.6)).padding(.horizontal, 12)
                DemoHitReadout(report: report)
                Button("重播动画") { animation += 1 }.buttonStyle(.bordered)
                Form {
                    TextField("搜索属性名或分组", text: $query)
                    ChartDemoPanel(sections: sections, query: query)
                }
            }
        }
        .navigationTitle("热力图").navigationBarTitleDisplayMode(.inline)
        .onChange(of: rowCount) { selectedRow = min(selectedRow, $0 - 1) }
        .onChange(of: columnCount) { selectedColumn = min(selectedColumn, $0 - 1) }
    }
    private var sections: [ChartDemoPanel.DemoSection] {
        let c = cell
        let dataItems: [ChartDemoPanel.Item] = [DemoProperty.integer("行数", $rowCount, 1...12), DemoProperty.integer("列数", $columnCount, 1...30),
            .toggle(label: "最后一行为半行（锯齿行）", value: $ragged), .textField(label: "行标签（逗号分隔）", value: $rowLabels), .textField(label: "列标签（逗号分隔）", value: $columnLabels),
            .toggle(label: "固定色阶值域", value: $fixedRange), DemoProperty.number("值域下界", $lower, -100...100), DemoProperty.number("值域上界", $upper, 1...200), DemoProperty.number("预览高度", $height, 160...500, step: 10)]
        let cellItems: [ChartDemoPanel.Item] = [DemoProperty.index("编辑行（从0开始）", $selectedRow, count: rowCount), DemoProperty.index("编辑列（从0开始）", $selectedColumn, count: editableColumnCount), DemoProperty.number("单格数值", c.value, -100...200), .toggle(label: "有效格（关闭为缺测占位）", value: c.isValid), DemoProperty.enabled("自定义提示文本", c.tooltipText, default: "自定义提示"), .textField(label: "提示文本", value: DemoProperty.optional(c.tooltipText, default: ""))]
        return [
            .init(title: "数据与布局", items: dataItems),
            .init(title: "单格数据覆盖", items: cellItems + DemoProperty.color("单格颜色", c.color)),
            .init(title: "色阶", items: [.picker(label: "色阶模式", selection: $scale, options: ["渐变", "单色透明度", "分段", "不映射"]), .color(label: "低值颜色", value: $low), .color(label: "中间颜色", value: $middle), .color(label: "高值 / 单色", value: $high), DemoProperty.number("分段低值锚点", $stopLow, -100...200), DemoProperty.number("分段中间锚点", $stopMiddle, -100...200), DemoProperty.number("分段高值锚点", $stopHigh, -100...200)]),
            .init(title: "热力主题（格子/标签/选中）", items: DemoThemeFields.items($theme) + [.picker(label: "水平对齐", selection: $alignment, options: ["leading", "center", "trailing"])]),
            .init(title: "弹窗与回调", items: [.toggle(label: "容器弹窗", value: $interaction.tooltip), .picker(label: "弹窗预设", selection: $interaction.popupMode, options: ["内置", "自定义内容", "位置回调"])]),
            .init(title: "弹窗外观", items: DemoThemeFields.items($tooltipTheme))]
    }
}
