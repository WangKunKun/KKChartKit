import SwiftUI

/// 折线图 demo：上方图表 + 下方实时属性面板（规格 §8.3 标配）。
/// 面板属性改动即时经 LineChart → configure 重绘。
struct LineChartDemo: View {
    // —— Model 可调项 ——
    @State private var title = "月度营收（万元）"
    @State private var pointCount = 8
    @State private var data: [[Double]] = (0..<1).map { _ in Self.randomData(count: 8) }
    /// 多系列：每系列独立数据集与颜色（堆叠/双轴都基于这些真实系列）
    @State private var seriesCount = 1
    @State private var seriesColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple]

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

    // —— 面积填充（面积图形态）——
    @State private var showsArea = false
    /// 面积渐变顶部浓度（自动派生渐变的起始透明度）
    @State private var areaTopAlpha = 0.35

    // —— 双轴 / 堆叠 / 刻度自定义 ——
    @State private var dualAxisOn = false
    @State private var stackingMode = "不堆叠"
    /// 上下镜像（正负分开堆叠）：末系列取负，正链从 0 向上、负链从 0 向下
    @State private var mirrorStackOn = false
    /// 堆叠模式下是否叠加面积分层展示（默认开，可关成纯累计折线）
    @State private var stackedAreaOn = true
    @State private var tickCountOn = false
    @State private var tickCount = 6.0
    @State private var useTickPositions = false
    @State private var usePercentFormatter = false
    /// 首末点贴边：类目域压到 0...n-1（默认 -0.5...n-0.5，点居槽位中心）
    @State private var edgePointsOn = false

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
        .onChange(of: pointCount) { _ in regenerateData() }
        .onChange(of: seriesCount) { _ in regenerateData() }
    }

    private var currentModel: CartesianChartModel {
        var y = CartesianAxisModel(kind: .value)
        if tickCountOn { y.tickCount = Int(tickCount) }
        if useTickPositions { y.tickPositions = [0, 30, 60, 100] }
        if usePercentFormatter {
            y.labelFormatter = { "\(Int($0))%" }
        } else if mirrorStackOn {
            // 镜像形态：Y 轴刻度显示绝对值（下方负值域看起来也是正数，AAChartKit 惯用手法）
            y.labelFormatter = { AxisRenderer.format(abs($0)) }
        }

        let stacking: StackConfig? = (stackingMode == "普通堆叠" || mirrorStackOn) ? .normal : nil
        // 真实多系列：按面板系列数量取数据集；末系列在双轴模式下绑右轴；
        // 镜像模式下末系列取负（正链从 0 向上、负链从 0 向下的上下两组形态）
        let series = (0..<seriesCount).map { i in
            let isLast = i == seriesCount - 1
            let rawData = i < data.count ? data[i] : Self.randomData(count: pointCount)
            return CartesianSeriesElement(
                name: "系列\(i + 1)",
                data: (mirrorStackOn && isLast) ? rawData.map { -$0 } : rawData,
                color: seriesColors[i % seriesColors.count],
                yAxisIndex: (dualAxisOn && isLast) ? 1 : 0)
        }

        var secondary: CartesianAxisModel?
        if dualAxisOn {
            var s = CartesianAxisModel(kind: .value, min: 0, max: 100)
            s.labelFormatter = { "\(Int($0))%" }
            secondary = s
        }
        var x = CartesianAxisModel(kind: .category(labels: useTimeAxis ? ChartDemoPanel.timeLabels(count: pointCount) : []))
        if edgePointsOn, pointCount > 1 {
            // 类目域压到 0...n-1：首点贴左缘、末点贴右缘（Highcharts pointPlacement:"on" 同款形态）
            x.min = 0
            x.max = Double(pointCount - 1)
        }
        return CartesianChartModel(
            title: title.isEmpty ? nil : title,
            series: series,
            xAxis: x,
            yAxis: y,
            secondaryYAxis: secondary,
            stacking: stacking)
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
        // 堆叠默认联动开面积（分层展示更直观；可关成纯累计折线）
        let stacked = stackingMode == "普通堆叠" || mirrorStackOn
        let areaOn = showsArea || (stacked && stackedAreaOn)
        t.showsArea = areaOn
        if areaOn, seriesCount == 1 {
            // 单系列：面板系列色 + 浓度可控；多系列留给渲染器按各系列色派生渐变（分层颜色独立）
            t.areaGradientColors = [
                seriesColor.withAlphaComponent(areaTopAlpha),
                seriesColor.withAlphaComponent(0.04)
            ]
        }
        t.contentInset = UIEdgeInsets(top: insetTop, left: insetLeft,
                                       bottom: insetBottom, right: insetRight)
        return t
    }

    private var panel: ChartDemoPanel {
        let dataSection = ChartDemoPanel.DemoSection(title: "数据", items: [
            .textField(label: "标题", value: $title),
            .stepper(label: "系列数量（多数据集）", value: Binding(
                get: { Double(seriesCount) },
                set: { seriesCount = min(max(Int($0), 1), 4) }), step: 1),
            .slider(label: "数据点数", value: Binding(
                get: { Double(pointCount) },
                set: { pointCount = Int($0) }), range: 2...1440, step: 1),
            .button(label: "🎲 随机重生成数据") {
                regenerateData()
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
        let axisSection = ChartDemoPanel.DemoSection(title: "轴系", items: [
            .toggle(label: "双轴（末系列绑右轴）", value: $dualAxisOn),
            .picker(label: "堆叠模式", selection: $stackingMode, options: ["不堆叠", "普通堆叠"]),
            .toggle(label: "堆叠时面积分层", value: $stackedAreaOn),
            .toggle(label: "上下镜像（末系列取负，正上负下）", value: $mirrorStackOn),
            .toggle(label: "自定义刻度数量", value: $tickCountOn),
            .slider(label: "刻度数量", value: $tickCount, range: 2...12, step: 1),
            .toggle(label: "显式刻度位置（0/30/60/100）", value: $useTickPositions),
            .toggle(label: "刻度文本加 %", value: $usePercentFormatter),
            .toggle(label: "首末点贴边（类目域 0...n-1）", value: $edgePointsOn),
        ])
        let areaSection = ChartDemoPanel.DemoSection(title: "面积填充", items: [
            .toggle(label: "填充折线下方区域（面积图）", value: $showsArea),
            .slider(label: "渐变顶部浓度", value: $areaTopAlpha, range: 0.05...0.8, step: 0.05),
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
        return ChartDemoPanel(sections: [dataSection, axisSection, lineSection, areaSection, interactionSection, pointSection, gridSection, overallSection])
    }

    static func randomData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: 10...100).rounded() }
    }

    private func regenerateData() {
        data = (0..<seriesCount).map { _ in Self.randomData(count: pointCount) }
    }
}
