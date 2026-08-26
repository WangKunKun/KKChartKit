import SwiftUI

/// 折线图 demo：上方图表 + 下方实时属性面板（规格 §8.3 标配）。
/// 面板属性改动即时经 LineChart → configure 重绘。
struct LineChartDemo: View {
    // —— Model 可调项 ——
    @State private var title = "月度营收（万元）"
    @State private var pointCount = 8
    @State private var data: [Double] = Self.randomData(count: 8)

    // —— Theme 可调项（覆盖全部可调属性；UIColor 项拆出 @State 便于 ColorPicker 绑定）——
    @State private var theme = CartesianChartTheme()
    @State private var seriesColor = CartesianChartTheme().seriesColor
    @State private var pointColorOn = false
    @State private var pointColor = UIColor.systemRed

    var body: some View {
        VStack(spacing: 0) {
            LineChart(model: currentModel, theme: currentTheme)
                .frame(height: 280)
                .padding(.horizontal)
                .padding(.top, 8)
            Form {
                panel
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("折线图 demo")
        .onChange(of: pointCount) { data = Self.randomData(count: $0) }
    }

    private var currentModel: CartesianChartModel {
        CartesianChartModel(
            title: title.isEmpty ? nil : title,
            series: [CartesianSeriesElement(name: "2026", data: data)])
    }

    private var currentTheme: CartesianChartTheme {
        var t = theme
        t.seriesColor = seriesColor
        t.pointColor = pointColorOn ? pointColor : nil
        return t
    }

    private var panel: ChartDemoPanel {
        let dataSection = ChartDemoPanel.DemoSection(title: "数据", items: [
            .textField(label: "标题", value: $title),
            .slider(label: "数据点数", value: Binding(
                get: { Double(pointCount) },
                set: { pointCount = Int($0) }), range: 2...30, step: 1),
            .button(label: "🎲 随机重生成数据") {
                data = Self.randomData(count: pointCount)
            },
        ])
        let lineSection = ChartDemoPanel.DemoSection(title: "线条", items: [
            .slider(label: "线宽", value: Binding(
                get: { Double(theme.lineWidth) },
                set: { theme.lineWidth = CGFloat($0) }), range: 0.5...8, step: 0.5),
            .color(label: "系列颜色", value: $seriesColor),
        ])
        let pointSection = ChartDemoPanel.DemoSection(title: "数据点", items: [
            .toggle(label: "显示数据点", value: $theme.showsPoints),
            .slider(label: "点半径", value: Binding(
                get: { Double(theme.pointRadius) },
                set: { theme.pointRadius = CGFloat($0) }), range: 1...10, step: 0.5),
            .toggle(label: "自定义点颜色", value: $pointColorOn),
            .color(label: "点颜色", value: $pointColor),
        ])
        let gridSection = ChartDemoPanel.DemoSection(title: "网格与轴", items: [
            .toggle(label: "横向网格", value: $theme.showsHorizontalGridlines),
            .toggle(label: "纵向网格", value: $theme.showsVerticalGridlines),
            .color(label: "网格颜色", value: $theme.gridColor),
            .color(label: "轴颜色", value: $theme.axisLineColor),
            .color(label: "刻度文字颜色", value: $theme.tickLabelColor),
        ])
        let overallSection = ChartDemoPanel.DemoSection(title: "整体", items: [
            .toggle(label: "入场动画", value: $theme.showsEntranceAnimation),
            .toggle(label: "点击弹窗", value: $theme.showsTooltipOnHit),
        ])
        return ChartDemoPanel(sections: [dataSection, lineSection, pointSection, gridSection, overallSection])
    }

    static func randomData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: 10...100).rounded() }
    }
}
