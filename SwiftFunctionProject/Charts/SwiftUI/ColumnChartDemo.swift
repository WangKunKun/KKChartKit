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
    @State private var columnCornerRadius = 4.0
    @State private var columnBorderOn = false
    @State private var columnBorderColor = UIColor.black
    @State private var stackingMode = "不堆叠"
    @State private var stackSeparatorOn = false
    @State private var stackSeparatorColor = UIColor.white

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
                        minimumVisibleCategories: Int(minimumVisibleCategories))
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
            CartesianSeriesElement(
                name: "系列\(index + 1)",
                data: index < data.count ? data[index] : Self.randomData(count: pointCount),
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

        return CartesianChartModel(
            title: title.isEmpty ? nil : title,
            series: series,
            xAxis: CartesianAxisModel(kind: .category(labels: useTimeAxis ? ChartDemoPanel.timeLabels(count: pointCount) : [])),
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

        let columnSection = ChartDemoPanel.DemoSection(title: "柱体外观", items: [
            .slider(label: "柱体宽度比例", value: $columnWidthRatio, range: 0.3...1.0, step: 0.05),
            .slider(label: "圆角半径", value: $columnCornerRadius, range: 0...10, step: 1),
            .toggle(label: "边框", value: $columnBorderOn),
            .color(label: "边框颜色", value: $columnBorderColor),
        ])

        let stackSection = ChartDemoPanel.DemoSection(title: "堆叠", items: [
            .picker(label: "堆叠模式", selection: $stackingMode, options: ["不堆叠", "普通堆叠"]),
            .toggle(label: "分隔线", value: $stackSeparatorOn),
            .color(label: "分隔线颜色", value: $stackSeparatorColor),
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

        return ChartDemoPanel(sections: [dataSection, xAxisSection, columnSection, stackSection, animationSection])
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