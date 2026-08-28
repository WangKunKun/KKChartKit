import SwiftUI

/// 条形图 demo：上方图表 + 下方实时属性面板（规格 §8.3 标配）。
struct BarChartDemo: View {
    // —— Model 可调项 ——
    @State private var title = "季度销售额（万元）"
    @State private var seriesCount = 1
    @State private var pointCount = 4
    @State private var data: [[Double]] = (0..<1).map { _ in Self.randomData(count: 4) }

    // —— Theme 可调项 ——
    @State private var theme = CartesianChartTheme()
    @State private var seriesColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange]
    @State private var columnWidthRatio = 0.8
    @State private var columnCornerRadius = 4.0
    @State private var columnBorderOn = false
    @State private var columnBorderColor = UIColor.black
    @State private var stackingMode = "不堆叠"
    @State private var stackSeparatorOn = false
    @State private var stackSeparatorColor = UIColor.white

    // —— 值轴刻度自定义（Bar 的 X 数值轴）——
    @State private var tickCountOn = false
    @State private var tickCount = 6.0
    @State private var useTickPositions = false
    @State private var usePercentFormatter = false
    /// 上下镜像：末系列取负（条形向左为负链）
    @State private var mirrorStackOn = false
    // —— 手势体验增强 ——
    @State private var decelerationOn = true
    @State private var highlightPerDragOn = true
    @State private var rubberBandOn = true
    @State private var sharedTooltipOn = true

    // —— 缩放功能测试 ——
    @State private var isZoomEnabled = true
    /// 类目轴（Y 轴，左侧标签）时间轴模式：按实际数据量把 24h 均分到每个点。
    @State private var useTimeAxis = false

    var body: some View {
        VStack(spacing: 0) {
            BarChart(model: currentModel, theme: currentTheme,
                     onHit: { target, gesture in
                         let timeTag = useTimeAxis
                             ? "（\(ChartDemoPanel.timeLabel(at: target.categoryIndex, count: pointCount))）"
                             : ""
                         print("🎯 点击条形：第 \(target.categoryIndex + 1) 个类目\(timeTag) · "
                               + "系列 \(target.seriesIndex + 1) · 值 = \(target.value) · 手势 = \(gesture)")
                     },
                     isZoomEnabled: isZoomEnabled,
                     isDragDecelerationEnabled: decelerationOn,
                     isHighlightPerDragEnabled: highlightPerDragOn,
                     isRubberBandEnabled: rubberBandOn,
                     isSharedTooltipOnTapEnabled: sharedTooltipOn)
                .frame(height: 280)
                .padding(.horizontal)
                .padding(.top, 8)
            Form {
                panel
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("条形图 demo")
        .onChange(of: pointCount) { _ in regenerateData() }
        .onChange(of: seriesCount) { _ in regenerateData() }
    }

    private var currentModel: CartesianChartModel {
        let series = (0..<seriesCount).map { index in
            let isLast = index == seriesCount - 1
            let rawData = index < data.count ? data[index] : Self.randomData(count: pointCount)
            return CartesianSeriesElement(
                name: "系列\(index + 1)",
                data: (mirrorStackOn && isLast) ? rawData.map { -$0 } : rawData,
                color: seriesColors[index % seriesColors.count]
            )
        }
        let stacking: StackConfig? = {
            switch stackingMode {
            case "不堆叠": return .none
            case "普通堆叠": return .normal
            default: return .none
            }
        }()

        // 值轴刻度自定义（Bar 的值轴在 X，底部刻度）
        var y = CartesianAxisModel(kind: .value)
        if tickCountOn { y.tickCount = Int(tickCount) }
        if useTickPositions { y.tickPositions = [0, 25, 60, 100] }
        if usePercentFormatter {
            y.labelFormatter = { "\(Int($0))%" }
        } else if mirrorStackOn {
            y.labelFormatter = { AxisRenderer.format(abs($0)) }
        }

        return CartesianChartModel(
            title: title.isEmpty ? nil : title,
            series: series,
            xAxis: CartesianAxisModel(kind: .category(labels: useTimeAxis ? ChartDemoPanel.timeLabels(count: pointCount) : [])),
            yAxis: y,
            stacking: stacking == .none ? nil : stacking
        )
    }

    private var currentTheme: CartesianChartTheme {
        var t = theme
        t.columnWidthRatio = columnWidthRatio
        t.columnCornerRadius = columnCornerRadius
        if columnBorderOn {
            t.columnBorderColor = columnBorderColor
        }
        if stackSeparatorOn {
            t.stackSeparatorColor = stackSeparatorColor
        }
        return t
    }

    private var panel: ChartDemoPanel {
        let seriesCountBinding = Binding(
            get: { Double(seriesCount) },
            set: { seriesCount = Int($0) }
        )

        let pointCountBinding = Binding(
            get: { Double(pointCount) },
            set: { pointCount = Int($0) }
        )

        let dataSection = ChartDemoPanel.DemoSection(title: "数据", items: [
            .textField(label: "标题", value: $title),
            .stepper(label: "系列数量", value: seriesCountBinding, step: 1),
            .slider(label: "数据点数", value: pointCountBinding, range: 2...1440, step: 1),
            .button(label: "🎲 随机重生成数据") {
                regenerateData()
            },
            .button(label: "📉 生成负值数据") {
                data = (0..<seriesCount).map { _ in Self.randomNegativeData(count: pointCount) }
            },
        ])

        let barSection = ChartDemoPanel.DemoSection(title: "条形外观", items: [
            .slider(label: "条形高度比例", value: $columnWidthRatio, range: 0.3...1.0, step: 0.05),
            .slider(label: "圆角半径", value: $columnCornerRadius, range: 0...10, step: 1),
            .toggle(label: "边框", value: $columnBorderOn),
            .color(label: "边框颜色", value: $columnBorderColor),
        ])

        let stackSection = ChartDemoPanel.DemoSection(title: "堆叠", items: [
            .picker(label: "堆叠模式", selection: $stackingMode, options: ["不堆叠", "普通堆叠"]),
            .toggle(label: "分隔线", value: $stackSeparatorOn),
            .color(label: "分隔线颜色", value: $stackSeparatorColor),
        ])

        let axisSection = ChartDemoPanel.DemoSection(title: "值轴刻度", items: [
            .toggle(label: "自定义刻度数量", value: $tickCountOn),
            .slider(label: "刻度数量", value: $tickCount, range: 2...12, step: 1),
            .toggle(label: "显式刻度位置（0/25/60/100）", value: $useTickPositions),
            .toggle(label: "刻度文本加 %", value: $usePercentFormatter),
            .toggle(label: "左右镜像（末系列取负，与堆叠无关）", value: $mirrorStackOn),
        ])
        let gestureSection = ChartDemoPanel.DemoSection(title: "手势", items: [
            .toggle(label: "拖拽惯性减速", value: $decelerationOn),
            .toggle(label: "滑动选中（全量视图拖拽=划过整行高亮）", value: $highlightPerDragOn),
            .toggle(label: "边界橡皮筋（越界回弹）", value: $rubberBandOn),
            .toggle(label: "点击弹整行数据（按类目取所有系列）", value: $sharedTooltipOn),
        ])

        let animationSection = ChartDemoPanel.DemoSection(title: "动画与交互", items: [
            .toggle(label: "入场动画", value: $theme.showsColumnEntranceAnimation),
            .toggle(label: "点击弹窗", value: $theme.showsTooltipOnHit),
            .toggle(label: "启用缩放（X轴数值轴捏合/平移，双击重置）", value: $isZoomEnabled),
        ])
        let xAxisSection = ChartDemoPanel.DemoSection(title: "类目轴", items: [
            .toggle(label: "24小时时间轴（按数据量均分）", value: $useTimeAxis),
        ])

        return ChartDemoPanel(sections: [dataSection, xAxisSection, axisSection, gestureSection, barSection, stackSection, animationSection])
    }

    private func regenerateData() {
        data = (0..<seriesCount).map { _ in Self.randomData(count: pointCount) }
    }

    static func randomData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: 20...100).rounded() }
    }

    static func randomNegativeData(count: Int) -> [Double] {
        (0..<count).map { _ in Double.random(in: -80...80).rounded() }
    }
}