import SwiftUI

/// 柱状图 demo：上方图表 + 下方实时属性面板（规格 §8.3 标配）。
struct ColumnChartDemo: View {
    // —— Model 可调项 ——
    @State private var title = "季度销售额（万元）"
    @State private var seriesCount = 1
    @State private var pointCount = 4
    @State private var data: [[Double]] = (0..<1).map { _ in Self.randomData(count: 4) }

    // —— Theme 可调项 ——
    @State private var theme = CartesianChartTheme()
    @State private var seriesColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange]
    @State private var columnWidthRatio = 0.8
    /// 组内相邻柱间距（nil = 自动跟随柱宽余量；滑条 0 = 自动）
    @State private var columnInnerSpacing = 0.0
    /// 相邻类目组之间间距占槽宽比例
    @State private var columnGroupSpacing = 0.0
    @State private var columnCornerRadius = 4.0
    @State private var columnBorderOn = false
    @State private var columnBorderColor = UIColor.black
    @State private var stackingMode = "不堆叠"
    @State private var stackSeparatorOn = false
    @State private var stackSeparatorColor = UIColor.white
    /// 双轴：末系列绑右轴
    @State private var dualAxisOn = false
    /// 上下镜像：末系列取负（正链向上、负链向下，与堆叠独立）
    @State private var mirrorStackOn = false
    /// 百分比堆叠统一基准（0 = 每列自动满 100%）
    @State private var percentBaseMax = 0.0
    /// 首末柱贴边（类目域 0...n-1）
    @State private var edgePointsOn = false
    // —— 值轴刻度自定义 ——
    @State private var tickCountOn = false
    @State private var tickCount = 6.0
    @State private var useTickPositions = false
    @State private var usePercentFormatter = false
    // —— 手势体验增强 ——
    @State private var decelerationOn = true
    @State private var highlightPerDragOn = true
    @State private var rubberBandOn = true
    @State private var sharedTooltipOn = true

    // —— 缩放功能测试 ——
    @State private var isZoomEnabled = true
    @State private var minimumVisibleCategories = 12.0
    /// X 轴时间轴模式：按实际数据量把 24h 均分到每个点（288 点 = 5 分钟/点，1440 点 = 1 分钟/点）
    @State private var useTimeAxis = true

    var body: some View {
        VStack(spacing: 0) {
            ColumnChart(model: currentModel, theme: currentTheme,
                        onHit: { target, gesture in
                            let timeTag = useTimeAxis
                                ? "（\(ChartDemoPanel.timeLabel(at: target.categoryIndex, count: pointCount))）"
                                : ""
                            print("🎯 点击柱子：第 \(target.categoryIndex + 1) 个类目\(timeTag) · "
                                  + "系列 \(target.seriesIndex + 1) · 值 = \(target.value) · 手势 = \(gesture)")
                        },
                        isZoomEnabled: isZoomEnabled,
                        minimumVisibleCategories: Int(minimumVisibleCategories),
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
        .navigationTitle("柱状图 demo")
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
                color: seriesColors[index % seriesColors.count],
                yAxisIndex: (dualAxisOn && isLast) ? 1 : 0
            )
        }
        let stacking: StackConfig? = {
            switch stackingMode {
            case "不堆叠": return .none
            case "普通堆叠": return .normal
            case "百分比堆叠":
                return percentBaseMax > 0 ? .percentFixed(max: percentBaseMax) : .percent
            default: return .none
            }
        }()

        var secondary: CartesianAxisModel?
        if dualAxisOn {
            var s = CartesianAxisModel(kind: .value)
            s.labelFormatter = { "\(Int($0))†" }
            secondary = s
        }

        var y = CartesianAxisModel(kind: .value)
        if tickCountOn { y.tickCount = Int(tickCount) }
        if useTickPositions { y.tickPositions = [0, 25, 50, 100] }
        if usePercentFormatter { y.labelFormatter = { "\(Int($0))%" } }
        else if mirrorStackOn { y.labelFormatter = { AxisRenderer.format(abs($0)) } }

        var x = CartesianAxisModel(kind: .category(labels: useTimeAxis ? ChartDemoPanel.timeLabels(count: pointCount) : []))
        if edgePointsOn, pointCount > 1 {
            x.min = 0
            x.max = Double(pointCount - 1)
        }
        return CartesianChartModel(
            title: title.isEmpty ? nil : title,
            series: series,
            xAxis: x,
            yAxis: y,
            secondaryYAxis: secondary,
            stacking: stacking == .none ? nil : stacking
        )
    }

    private var currentTheme: CartesianChartTheme {
        var t = theme
        t.columnWidthRatio = columnWidthRatio
        t.columnInnerSpacingRatio = columnInnerSpacing >= 0.01 ? columnInnerSpacing : nil
        t.columnGroupSpacingRatio = columnGroupSpacing
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

        let columnSection = ChartDemoPanel.DemoSection(title: "柱体外观", items: [
            .slider(label: "柱体宽度比例", value: $columnWidthRatio, range: 0.3...1.0, step: 0.05),
            .slider(label: "组内柱间距（0=自动）", value: $columnInnerSpacing, range: 0...0.5, step: 0.05),
            .slider(label: "组间距（组间空隙比例）", value: $columnGroupSpacing, range: 0...0.5, step: 0.05),
            .slider(label: "圆角半径", value: $columnCornerRadius, range: 0...10, step: 1),
            .toggle(label: "边框", value: $columnBorderOn),
            .color(label: "边框颜色", value: $columnBorderColor),
        ])

        let stackSection = ChartDemoPanel.DemoSection(title: "堆叠", items: [
            .picker(label: "堆叠模式", selection: $stackingMode, options: ["不堆叠", "普通堆叠", "百分比堆叠"]),
            .toggle(label: "双轴（末系列绑右轴）", value: $dualAxisOn),
            .toggle(label: "上下镜像（末系列取负，与堆叠无关）", value: $mirrorStackOn),
            .slider(label: "百分比基准（0=每列自动满100%）", value: $percentBaseMax, range: 0...500, step: 10),
            .toggle(label: "分隔线", value: $stackSeparatorOn),
            .color(label: "分隔线颜色", value: $stackSeparatorColor),
        ])
        let axisSection = ChartDemoPanel.DemoSection(title: "值轴刻度", items: [
            .toggle(label: "自定义刻度数量", value: $tickCountOn),
            .slider(label: "刻度数量", value: $tickCount, range: 2...12, step: 1),
            .toggle(label: "显式刻度位置（0/25/50/100）", value: $useTickPositions),
            .toggle(label: "刻度文本加 %", value: $usePercentFormatter),
            .toggle(label: "首末柱贴边（类目域 0...n-1）", value: $edgePointsOn),
        ])
        let gestureSection = ChartDemoPanel.DemoSection(title: "手势", items: [
            .toggle(label: "拖拽惯性减速", value: $decelerationOn),
            .toggle(label: "滑动选中（全量视图拖拽=划过高亮）", value: $highlightPerDragOn),
            .toggle(label: "边界橡皮筋（越界回弹）", value: $rubberBandOn),
            .toggle(label: "点击弹整列数据（按 X 类目取所有系列）", value: $sharedTooltipOn),
        ])

        let animationSection = ChartDemoPanel.DemoSection(title: "动画与交互", items: [
            .toggle(label: "入场动画", value: $theme.showsColumnEntranceAnimation),
            .toggle(label: "点击弹窗", value: $theme.showsTooltipOnHit),
            .toggle(label: "启用缩放（X轴捏合/平移，双击重置）", value: $isZoomEnabled),
            .slider(label: "放大下限（最小可见类目数）", value: $minimumVisibleCategories, range: 2...24, step: 1),
        ])
        let xAxisSection = ChartDemoPanel.DemoSection(title: "X 轴", items: [
            .toggle(label: "24小时时间轴（按数据量均分）", value: $useTimeAxis),
        ])

        return ChartDemoPanel(sections: [dataSection, xAxisSection, columnSection, stackSection, axisSection, gestureSection, animationSection])
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