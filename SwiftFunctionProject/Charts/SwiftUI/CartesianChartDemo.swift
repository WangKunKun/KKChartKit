import SwiftUI

/// 每种轴系图只有一个页面；所有状态使用同一套模型/主题绑定。
struct CartesianChartDemo: View {
    let kind: CartesianDemoKind
    @State private var theme = CartesianChartTheme()
    @State private var tooltipTheme = HYMChartTooltipTheme()
    @State private var interaction = DemoInteractionSettings()
    @State private var report = DemoChartReport()
    @State private var title = "实时属性调试"
    @State private var pointCount = 24
    @State private var seriesCount = 3
    @State private var series = (0..<6).map { DemoSeriesSettings(name: "系列 \($0 + 1)", color: [UIColor.systemBlue, .systemOrange, .systemGreen, .systemPurple, .systemPink, .systemTeal][$0]) }
    @State private var selectedSeries = 0
    @State private var seed = 0
    @State private var negative = false
    @State private var missing = false
    @State private var sharpPeaks = false
    @State private var stacking = "无"
    @State private var percentBase = 300.0
    @State private var dualAxis = false
    @State private var categoryAxis = DemoAxisSettings()
    @State private var primaryAxis = DemoAxisSettings()
    @State private var secondaryAxis = DemoAxisSettings()
    @State private var customLabels = ""
    @State private var timeEnabled = true
    @State private var start = Date(timeIntervalSince1970: 1790208000)
    @State private var daily = true
    @State private var interval = 300.0
    @State private var timeZone = "UTC"
    @State private var dateFormat = "自动"
    @State private var grouping = false
    @State private var groupingConfig = CartesianTimeGrouping()
    @State private var intervalText = "60,300,900,1800,3600,7200,14400,21600,43200,86400"
    @State private var height = 280.0
    @State private var autoLegendHeight = true
    @State private var expandLegend = false
    @State private var lineEnabled = false
    @State private var plotLine = CartesianPlotLine(value: 50, label: "参考线")
    @State private var bandEnabled = false
    @State private var plotBand = CartesianPlotBand(from: 30, to: 70, label: "参考区间")
    @State private var gradient = false
    @State private var gradientA = UIColor.systemBlue.withAlphaComponent(0.4)
    @State private var gradientB = UIColor.systemBlue.withAlphaComponent(0.05)
    @State private var valueFormat = "自动"
    @State private var totalFormat = "自动"
    @State private var command = 0
    @State private var range: Range<Int>?
    @State private var animation = 0
    @State private var resetID = UUID()
    @State private var query = ""

    init(kind: CartesianDemoKind) {
        self.kind = kind
        _pointCount = State(initialValue: kind == .bar ? 6 : 24)
        var controls = DemoInteractionSettings()
        controls.zoomAxis = kind == .bar ? .y : .x
        _interaction = State(initialValue: controls)
    }

    var model: CartesianChartModel {
        let rows = (0..<seriesCount).map { i -> CartesianSeriesElement in
            let s = series[i]
            let generated = (0..<pointCount).map { p -> Double in
                if missing && p.isMultiple(of: 13) { return .nan }
                if sharpPeaks && p == pointCount / 3 { return 180 + Double(i * 10) }
                if sharpPeaks && p == pointCount * 2 / 3 { return -100 - Double(i * 10) }
                let value = 50 + 35 * sin(Double(p + seed * 7) * (sharpPeaks ? 0.015 : 0.23) + Double(i))
                return negative && p.isMultiple(of: 3) ? -value : value
            }
            let data = s.dataText.isEmpty ? generated : s.dataText.split(separator: ",", omittingEmptySubsequences: false).prefix(3000).map { Double($0.trimmingCharacters(in: .whitespaces)) ?? .nan }
            return CartesianSeriesElement(name: s.name, data: data, color: s.color, negativeColor: s.negativeColor,
                yAxisIndex: kind != .bar && dualAxis ? s.axis : 0, lineDashStyle: LineDashStyle(rawValue: s.dash), connectNulls: s.connectNulls,
                pointSymbol: PointMarkerSymbol(rawValue: s.marker), dataLabelsEnabled: s.labels,
                barColors: s.palette ? [s.paletteA, s.paletteB] : nil, shadow: s.shadow, id: "series-\(i)", isVisible: s.visible,
                showsInLegend: s.showsInLegend, legendOrder: s.legendOrder, aggregation: s.reducer, unit: s.unit.isEmpty ? nil : s.unit)
        }
        let stack: StackConfig? = stacking == "普通" ? .normal : stacking == "百分比" ? .percent : stacking == "固定基准百分比" ? .percentFixed(max: percentBase) : nil
        var config = groupingConfig
        config.preferredIntervals = intervalText.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }.filter { $0.isFinite && $0 > 0 }
        let zone = TimeZone(identifier: timeZone) ?? TimeZone(secondsFromGMT: 0)!
        let format = dateFormat
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = zone; dateFormatter.dateFormat = format
        let formatter: ((Date) -> String)? = format == "自动" ? nil : { dateFormatter.string(from: $0) }
        return CartesianChartModel(title: title.isEmpty ? nil : title, series: rows,
            xAxis: categoryAxis.axis(kind: .category(labels: customLabels.isEmpty ? [] : customLabels.components(separatedBy: ","))),
            yAxis: primaryAxis.axis(kind: .value), secondaryYAxis: dualAxis && kind != .bar ? secondaryAxis.axis(kind: .value) : nil,
            stacking: stack, plotLines: lineEnabled ? [plotLine] : [], plotBands: bandEnabled ? [plotBand] : [],
            timeAxis: timeEnabled ? .init(start: start, interval: daily ? 86400 / Double(pointCount) : interval, timeZone: zone, labelFormatter: formatter) : nil,
            timeGrouping: kind == .column && grouping && timeEnabled ? config : nil)
    }
    var builtTheme: CartesianChartTheme {
        var t = theme
        t.legend.overflow = expandLegend ? .expand : .scroll
        t.legend.itemOverrides = Dictionary(uniqueKeysWithValues: (0..<seriesCount).map { ("series-\($0)", series[$0].legendStyle) })
        t.areaGradientColors = gradient ? [gradientA, gradientB] : nil
        t.dataLabelFormatter = Self.formatter(valueFormat)
        t.stackTotalLabelFormatter = Self.formatter(totalFormat)
        return t
    }
    private static func formatter(_ option: String) -> ((Double) -> String)? {
        switch option {
        case "整数": return { String(format: "%.0f", $0) }
        case "两位小数": return { String(format: "%.2f", $0) }
        case "百分号": return { String(format: "%.1f%%", $0) }
        default: return nil
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let m = model
            let t = builtTheme
            let measurement = ChartLegendMeasurer.measure(model: m, theme: t, availableWidth: max(0, geometry.size.width - 24 - t.contentInset.left - t.contentInset.right))
            VStack(spacing: 6) {
                preview(model: m, theme: t)
                    .id(resetID)
                    .frame(height: min(geometry.size.height * 0.6, height + (autoLegendHeight ? measurement.additionalChartHeight : 0)))
                    .padding(.horizontal, 12)
                DemoHitReadout(report: report)
                if kind == .line && theme.lineSampling != nil {
                    Text(stacking == "无" && theme.lineConnectionStyle == .straight
                         ? "Min/Max 已启用：稀疏时恢复原始点，点击始终读取原始值。"
                         : "当前保持原始绘制：曲线、阶梯及堆叠暂不降采样。")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                        .accessibilityIdentifier("demo.lineSamplingStatus")
                }
                HStack {
                    Button("总览") { range = nil; command += 1 }
                    Button("最近24点") { let n = m.maxPointCount; range = max(0, n - 24)..<n; command += 1 }
                    if kind == .column { Button("所选区间") { if let r = report.selectedRange { range = r; command += 1 } } }
                    Button("重播动画") { animation += 1 }
                }.font(.caption).buttonStyle(.bordered)
                Form {
                    TextField("搜索属性名或分组", text: $query).accessibilityIdentifier("demo.search")
                    if query.isEmpty { Section("布局读数") {
                        Text("图例内容 \(Int(measurement.contentSize.width)) × \(Int(measurement.contentSize.height)) pt · \(measurement.rowCount) 行\n预留高度 \(Int(measurement.additionalChartHeight)) pt · \(measurement.isScrollable ? "滚动" : "完整显示")")
                            .font(.caption)
                        Text("预览最高占页面 60%，给属性面板保留空间。高度不足时可关闭自动追加图例高度或减少图例行数。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    }
                    ChartDemoPanel(sections: sections, query: query)
                    Section {
                        Button("恢复默认配置") { reset() }.accessibilityIdentifier("demo.reset")
                    }
                }
            }
        }
        .navigationTitle(kind.rawValue).navigationBarTitleDisplayMode(.inline)
        .onChange(of: seriesCount) { count in selectedSeries = min(selectedSeries, count - 1) }
        .onChange(of: pointCount) { _ in report.selectedRange = nil }
    }
    @ViewBuilder private func preview(model: CartesianChartModel, theme: CartesianChartTheme) -> some View {
        switch kind {
        case .line: host(LineChartRenderer.self, model, theme)
        case .column: host(ColumnChartRenderer.self, model, theme)
        case .bar: host(BarChartRenderer.self, model, theme)
        }
    }
    private func host<R: HYMChartRenderer>(_ type: R.Type, _ m: CartesianChartModel, _ t: CartesianChartTheme) -> DemoChartHost<R> where R.Model == CartesianChartModel, R.Theme == CartesianChartTheme {
        DemoChartHost(model: m, theme: t, interaction: interaction, tooltipTheme: tooltipTheme,
            report: report, command: command, range: range, animation: animation,
            onVisibility: { id, visible in
                if let index = Int(id.replacingOccurrences(of: "series-", with: "")), series.indices.contains(index) { series[index].visible = visible }
            })
    }
    private func reset() {
        theme = CartesianChartTheme(); tooltipTheme = .default; interaction = DemoInteractionSettings()
        interaction.zoomAxis = kind == .bar ? .y : .x
        title = "实时属性调试"; pointCount = kind == .bar ? 6 : 24; seriesCount = 3; selectedSeries = 0; seed = 0
        series = (0..<6).map { DemoSeriesSettings(name: "系列 \($0 + 1)", color: [UIColor.systemBlue, .systemOrange, .systemGreen, .systemPurple, .systemPink, .systemTeal][$0]) }
        negative = false; missing = false; sharpPeaks = false; stacking = "无"; percentBase = 300; dualAxis = false
        categoryAxis = .init(); primaryAxis = .init(); secondaryAxis = .init(); customLabels = ""
        timeEnabled = true; start = Date(timeIntervalSince1970: 1790208000); daily = true; interval = 300; timeZone = "UTC"; dateFormat = "自动"
        grouping = false; groupingConfig = .init(); intervalText = "60,300,900,1800,3600,7200,14400,21600,43200,86400"
        height = 280; autoLegendHeight = true; expandLegend = false; lineEnabled = false; bandEnabled = false
        plotLine = .init(value: 50, label: "参考线"); plotBand = .init(from: 30, to: 70, label: "参考区间")
        gradient = false; gradientA = .systemBlue.withAlphaComponent(0.4); gradientB = .systemBlue.withAlphaComponent(0.05)
        valueFormat = "自动"; totalFormat = "自动"; range = nil; command = 0; animation = 0
        query = ""; report = DemoChartReport(); resetID = UUID()
    }
    private var sections: [ChartDemoPanel.DemoSection] {
        var result: [ChartDemoPanel.DemoSection] = []
        result.append(.init(title: "数据与布局", items: [
            .textField(label: "图表标题", value: $title), DemoProperty.integer("系列数", $seriesCount, 1...6),
            DemoProperty.integer("数据点数", $pointCount, 2...3000),
            .button(label: "288 点（5 分钟/点）") { pointCount = 288; daily = true },
            .button(label: "1440 点（1 分钟/点）") { pointCount = 1440; daily = true },
            .button(label: "3000 点压力场景") { pointCount = 3000; seriesCount = 6; grouping = kind == .column; if kind == .line { theme.lineSampling = LineChartSampling() }; theme.legend.isEnabled = true },
            .button(label: "更新样本数据") { seed += 1; report.selectedRange = nil },
            .toggle(label: "正负混合", value: $negative), .toggle(label: "包含缺测", value: $missing),
            DemoProperty.number("基础图表高度", $height, 160...500, step: 10), .toggle(label: "测量并追加图例高度", value: $autoLegendHeight)]))
        result.append(.init(title: "当前系列（逐系列配置）", items: [DemoProperty.index("编辑系列序号（从0开始）", $selectedSeries, count: seriesCount)] + DemoSeriesSettings.items(seriesBinding, kind: kind)))
        result.append(.init(title: "堆叠与双轴", items: [
            .picker(label: "堆叠", selection: $stacking, options: ["无", "普通", "百分比", "固定基准百分比"]), DemoProperty.number("固定百分比基准", $percentBase, 1...2000)] + (kind == .bar ? [] : [.toggle(label: "启用次值轴（在系列中指定0/1）", value: $dualAxis)])))
        result.append(.init(title: "类目轴", items: [.textField(label: "标签覆盖（逗号分隔）", value: $customLabels)] + DemoAxisSettings.categoryItems($categoryAxis, isHorizontal: kind == .bar)))
        result.append(.init(title: "主值轴", items: DemoAxisSettings.items($primaryAxis)))
        if kind != .bar && dualAxis { result.append(.init(title: "次值轴", items: DemoAxisSettings.items($secondaryAxis))) }
        result.append(.init(title: "时间轴", items: [
            .toggle(label: "启用时间轴", value: $timeEnabled), .toggle(label: "一天均分采样", value: $daily), DemoProperty.number("采样间隔秒（关闭一天均分后生效）", $interval, 1...3600, step: 1),
            .picker(label: "时区", selection: $timeZone, options: ["UTC", "Asia/Shanghai", "America/Los_Angeles"]),
            .picker(label: "日期格式", selection: $dateFormat, options: ["自动", "HH:mm:ss", "MM-dd HH:mm"]),
            .date(label: "采样起点（设备本地时间输入）", value: $start)]))
        if kind == .line {
            result.append(.init(title: "高密度折线 Min/Max", items: DemoThemeFields.lineSamplingItems($theme.lineSampling) + [
                .toggle(label: "尖峰与低谷样本", value: $sharpPeaks),
                .button(label: "3000 点尖峰降采样场景") {
                    pointCount = 3000; seriesCount = 3; sharpPeaks = true; missing = true
                    stacking = "无"; theme.lineConnectionStyle = .straight
                    theme.lineSampling = LineChartSampling(); theme.legend.isEnabled = true
                    range = nil; command += 1
                },
                .button(label: "查看尖峰附近原始点") {
                    let center = pointCount / 3
                    range = max(0, center - 12)..<min(pointCount, center + 12); command += 1
                }]))
        }
        if kind == .column {
            result.append(.init(title: "高密度时间聚合", items: [
                .toggle(label: "按可用宽度自动聚合（需时间轴）", value: $grouping), DemoProperty.number("最小柱宽 pt", $groupingConfig.minimumColumnWidth, 1...12),
                .toggle(label: "复用聚合与时间标签缓存", value: $groupingConfig.isCacheEnabled),
                DemoProperty.number("缩放粒度切换缓冲比例（0关闭）", $groupingConfig.granularityHysteresis, 0...0.5, step: 0.05),
                .textField(label: "首选聚合区间秒（逗号分隔）", value: $intervalText)]))
        }
        let all = DemoThemeFields.items($theme)
        let lineNames = ["lineWidth", "lineConnectionStyle", "lineDashStyle", "showsPoints", "point", "showsArea"]
        let columns = ["column", "stackSeparator", "showsColumnEntranceAnimation", "showsStackTotalLabels"]
        let specific = kind == .line ? lineNames : columns
        let excluded = kind == .line ? columns : lineNames
        let general = all.filter { item in !(specific + excluded).contains(where: { item.label.contains($0) }) }
        result.append(.init(title: "通用主题（背景/网格/字体/标签）", items: general + [
            .picker(label: "数据标签格式", selection: $valueFormat, options: ["自动", "整数", "两位小数", "百分号"])]))
        result.append(.init(title: kind == .line ? "折线与数据点外观" : "柱体与堆叠外观", items: all.filter { item in specific.contains(where: { item.label.contains($0) }) }))
        if kind == .line {
            result.append(.init(title: "面积渐变", items: [.toggle(label: "自定义渐变（需 showsArea）", value: $gradient), .color(label: "渐变起色", value: $gradientA), .color(label: "渐变末色", value: $gradientB)]))
        } else { result.append(.init(title: "堆叠总量格式", items: [.picker(label: "总量格式", selection: $totalFormat, options: ["自动", "整数", "两位小数", "百分号"])])) }
        result.append(.init(title: "图例布局", items: DemoThemeFields.items($theme.legend) + [.toggle(label: "展开完整图例（关闭为限高滚动）", value: $expandLegend)]))
        result.append(.init(title: "阈值参考线", items: [
            .toggle(label: "启用参考线", value: $lineEnabled), DemoProperty.number("参考值", $plotLine.value, -100...500), DemoProperty.integer("参考线值轴", $plotLine.yAxisIndex, 0...1), .color(label: "参考线颜色", value: $plotLine.color), DemoProperty.number("参考线宽", $plotLine.lineWidth, 0.5...6), DemoProperty.choice("参考线样式", $plotLine.dashStyle), .textField(label: "参考线标签", value: DemoProperty.optional($plotLine.label, default: ""))]))
        result.append(.init(title: "区间色带", items: [
            .toggle(label: "启用色带", value: $bandEnabled), DemoProperty.number("色带起点", $plotBand.from, -100...500), DemoProperty.number("色带终点", $plotBand.to, -100...500), DemoProperty.integer("色带值轴", $plotBand.yAxisIndex, 0...1), .color(label: "色带颜色", value: $plotBand.color), .textField(label: "色带标签", value: DemoProperty.optional($plotBand.label, default: ""))]))
        result.append(.init(title: "交互与弹窗行为", items: DemoInteractionSettings.items($interaction)))
        result.append(.init(title: "弹窗外观", items: DemoThemeFields.items($tooltipTheme)))
        return result
    }
    private var seriesBinding: Binding<DemoSeriesSettings> {
        Binding(get: { series[min(selectedSeries, seriesCount - 1)] }, set: { series[min(selectedSeries, seriesCount - 1)] = $0 })
    }
}
