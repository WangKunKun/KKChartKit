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
    @State private var backgroundOn = false
    @State private var backgroundColor = UIColor.systemBackground
    @State private var titleColor = CartesianChartTheme().titleColor
    @State private var titleFontSize = 14.0
    @State private var titleBold = true
    @State private var tickFontSize = 10.0
    @State private var gridLineWidth = 0.5
    @State private var axisLineWidth = 1.0
    @State private var axisLabelGap = 4.0
    @State private var insetTop = 12.0
    @State private var insetLeft = 12.0
    @State private var insetBottom = 12.0
    @State private var insetRight = 12.0
    @State private var backgroundCornerRadius = 0.0

    // —— 连接形态 / 交互（阶段 1 新增）——
    @State private var connectionStyle: LineConnectionStyle = .straight
    @State private var isZoomEnabled = true
    @State private var minimumVisibleCategories = 12.0
    /// X 轴时间轴模式：按实际数据量把 24h 均分到每个点（288 点 = 5 分钟/点，1440 点 = 1 分钟/点）
    @State private var useTimeAxis = true

    var body: some View {
        VStack(spacing: 0) {
            LineChart(model: currentModel,
                      theme: currentTheme,
                      onHit: { target, gesture in
                          let timeTag = useTimeAxis
                              ? "（\(ChartDemoPanel.timeLabel(at: target.index, count: pointCount))）"
                              : ""
                          print("🎯 点击数据点：第 \(target.index + 1) 个点\(timeTag) · "
                                + "系列 \(target.seriesIndex + 1) · 值 = \(target.value) · 手势 = \(gesture)")
                      },
                      isZoomEnabled: isZoomEnabled,
                      minimumVisibleCategories: Int(minimumVisibleCategories))
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
            series: [CartesianSeriesElement(name: "2026", data: data)],
            xAxis: CartesianAxisModel(kind: .category(labels: useTimeAxis ? ChartDemoPanel.timeLabels(count: pointCount) : [])))
    }

    private var currentTheme: CartesianChartTheme {
        var t = theme
        t.seriesColor = seriesColor
        t.pointColor = pointColorOn ? pointColor : nil
        t.backgroundColor = backgroundOn ? backgroundColor : nil
        t.backgroundCornerRadius = backgroundCornerRadius
        t.titleColor = titleColor
        t.titleFont = .systemFont(ofSize: titleFontSize, weight: titleBold ? .semibold : .regular)
        t.tickLabelFont = .systemFont(ofSize: tickFontSize)
        t.gridLineWidth = gridLineWidth
        t.axisLineWidth = axisLineWidth
        t.axisLabelGap = axisLabelGap
        t.lineConnectionStyle = connectionStyle
        t.contentInset = UIEdgeInsets(top: insetTop, left: insetLeft,
                                       bottom: insetBottom, right: insetRight)
        return t
    }

    private var panel: ChartDemoPanel {
        let dataSection = ChartDemoPanel.DemoSection(title: "数据", items: [
            .textField(label: "标题", value: $title),
            .slider(label: "数据点数", value: Binding(
                get: { Double(pointCount) },
                set: { pointCount = Int($0) }), range: 2...1440, step: 1),
            .button(label: "🎲 随机重生成数据") {
                data = Self.randomData(count: pointCount)
            },
        ])
        let lineSection = ChartDemoPanel.DemoSection(title: "线条", items: [
            .slider(label: "线宽", value: Binding(
                get: { Double(theme.lineWidth) },
                set: { theme.lineWidth = CGFloat($0) }), range: 0.5...8, step: 0.5),
            .color(label: "系列颜色", value: $seriesColor),
            .picker(label: "连接形态",
                    selection: Binding(
                        get: { connectionStyle.rawValue },
                        set: { connectionStyle = LineConnectionStyle(rawValue: $0) ?? .straight }),
                    options: LineConnectionStyle.allCases.map { $0.rawValue }),
        ])
        let pointSection = ChartDemoPanel.DemoSection(title: "数据点", items: [
            .toggle(label: "显示数据点", value: $theme.showsPoints),
            .slider(label: "点半径", value: Binding(
                get: { Double(theme.pointRadius) },
                set: { theme.pointRadius = CGFloat($0) }), range: 1...10, step: 0.5),
            .toggle(label: "自定义点颜色", value: $pointColorOn),
            .color(label: "点颜色", value: $pointColor),
        ])
        let interactionSection = ChartDemoPanel.DemoSection(title: "交互", items: [
            .toggle(label: "启用缩放（X轴捏合/平移，双击重置）", value: $isZoomEnabled),
            .slider(label: "放大下限（最小可见类目数）", value: $minimumVisibleCategories, range: 2...24, step: 1),
            .toggle(label: "24小时时间轴（按数据量均分）", value: $useTimeAxis),
        ])
        let gridSection = ChartDemoPanel.DemoSection(title: "网格与轴", items: [
            .toggle(label: "横向网格", value: $theme.showsHorizontalGridlines),
            .toggle(label: "纵向网格", value: $theme.showsVerticalGridlines),
            .color(label: "网格颜色", value: $theme.gridColor),
            .slider(label: "网格线宽", value: $gridLineWidth, range: 0.5...3, step: 0.5),
            .color(label: "轴颜色", value: $theme.axisLineColor),
            .slider(label: "轴线宽", value: $axisLineWidth, range: 0.5...3, step: 0.5),
            .color(label: "刻度文字颜色", value: $theme.tickLabelColor),
            .slider(label: "刻度字号", value: $tickFontSize, range: 8...16, step: 1),
            .slider(label: "刻度与轴间距", value: $axisLabelGap, range: 2...12, step: 1),
        ])
        let overallSection = ChartDemoPanel.DemoSection(title: "整体", items: [
            .toggle(label: "背景色", value: $backgroundOn),
            .color(label: "背景颜色", value: $backgroundColor),
            .slider(label: "背景圆角", value: $backgroundCornerRadius, range: 0...20, step: 1),
            .color(label: "标题颜色", value: $titleColor),
            .slider(label: "标题字号", value: $titleFontSize, range: 10...24, step: 1),
            .toggle(label: "标题加粗", value: $titleBold),
            .slider(label: "上边距", value: $insetTop, range: 0...40, step: 1),
            .slider(label: "左边距", value: $insetLeft, range: 0...40, step: 1),
            .slider(label: "下边距", value: $insetBottom, range: 0...40, step: 1),
            .slider(label: "右边距", value: $insetRight, range: 0...40, step: 1),
            .toggle(label: "入场动画", value: $theme.showsEntranceAnimation),
            .toggle(label: "点击弹窗", value: $theme.showsTooltipOnHit),
        ])
        return ChartDemoPanel(sections: [dataSection, lineSection, interactionSection, pointSection, gridSection, overallSection])
    }

    static func randomData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: 10...100).rounded() }
    }
}
