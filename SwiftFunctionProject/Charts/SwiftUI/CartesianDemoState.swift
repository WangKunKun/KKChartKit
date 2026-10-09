import SwiftUI

/// Demo 配置的唯一数据源；模型、预设与面板绑定共用，便于回归测试。
struct CartesianDemoState {
    let kind: CartesianDemoKind
    var theme = CartesianChartTheme()
    var tooltipTheme = HYMChartTooltipTheme()
    var interaction = DemoInteractionSettings()
    var report = DemoChartReport()
    var title = "实时属性调试"
    var pointCount = 24
    var seriesCount = 3
    var series = (0..<6).map { DemoSeriesSettings(name: "系列 \($0 + 1)", color: [UIColor.systemBlue, .systemOrange, .systemGreen, .systemPurple, .systemPink, .systemTeal][$0]) }
    var selectedSeries = 0
    var seed = 0
    var negative = false
    var missing = false
    var sharpPeaks = false
    var stacking = "无"
    var stackGroupCount = 2
    var percentBase = 300.0
    var dualAxis = false
    var categoryAxis = DemoAxisSettings()
    var primaryAxis = DemoAxisSettings()
    var secondaryAxis = DemoAxisSettings()
    var customLabels = ""
    var timeEnabled = true
    var start = Date(timeIntervalSince1970: 1790208000)
    var daily = true
    var interval = 300.0
    var timeZone = "UTC"
    var dateFormat = "自动"
    var grouping = false
    var groupingConfig = CartesianTimeGrouping()
    var intervalText = "60,300,900,1800,3600,7200,14400,21600,43200,86400"
    var height = 280.0
    var autoLegendHeight = true
    var expandLegend = false
    var lineEnabled = false
    var plotLine = CartesianPlotLine(value: 50, label: "参考线")
    var bandEnabled = false
    var plotBand = CartesianPlotBand(from: 30, to: 70, label: "参考区间")
    var gradient = false
    var gradientA = UIColor.systemBlue.withAlphaComponent(0.4)
    var gradientB = UIColor.systemBlue.withAlphaComponent(0.05)
    var valueFormat = "自动"
    var totalFormat = "自动"
    var command = 0
    var range: Range<Int>?
    var rangeStart = 0
    var rangeEnd = 24
    var animation = 0
    var resetID = UUID()
    var query = ""

    init(kind: CartesianDemoKind) {
        self.kind = kind
        pointCount = kind == .bar ? 6 : 24
        var controls = DemoInteractionSettings()
        controls.zoomAxis = kind == .bar ? .y : .x
        interaction = controls
        if kind == .combined {
            var rows = (0..<6).map { DemoSeriesSettings(name: "系列 \($0 + 1)", color: [UIColor.systemBlue, .systemOrange, .systemGreen, .systemPurple, .systemPink, .systemTeal][$0]) }
            rows[1].kind = .line; rows[2].kind = .areaspline
            rows[1].participatesInStack = false; rows[2].participatesInStack = false
            series = rows
        }
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
                showsInLegend: s.showsInLegend, legendOrder: s.legendOrder, aggregation: s.reducer, unit: s.unit.isEmpty ? nil : s.unit,
                groupID: s.groupID.isEmpty ? nil : s.groupID, valueFormat: s.valueFormat,
                kind: kind == .combined ? s.kind : nil, stackID: s.stackID.isEmpty ? nil : s.stackID,
                participatesInStack: s.participatesInStack, style: s.style, gapPolicy: s.gapPolicy, colorZones: s.colorZones)
        }
        let stack: StackConfig? = stacking == "普通" ? .normal : stacking == "百分比" ? .percent : stacking == "固定基准百分比" ? .percentFixed(max: percentBase) : stacking == "序号分组" ? .grouped(groupCount: stackGroupCount) : nil
        var config = groupingConfig
        config.preferredIntervals = intervalText.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }.filter { $0.isFinite && $0 > 0 }
        let zone = TimeZone(identifier: timeZone) ?? TimeZone(secondsFromGMT: 0)!
        let format = dateFormat
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = zone; dateFormatter.dateFormat = format
        let formatter: ((Date) -> String)? = format == "自动" ? nil : { dateFormatter.string(from: $0) }
        var activeLine = plotLine
        var activeBand = plotBand
        if !dualAxis || kind == .bar { activeLine.yAxisIndex = 0; activeBand.yAxisIndex = 0 }
        return CartesianChartModel(title: title.isEmpty ? nil : title, series: rows,
            xAxis: categoryAxis.axis(kind: .category(labels: customLabels.isEmpty ? [] : customLabels.components(separatedBy: ","))),
            yAxis: primaryAxis.axis(kind: .value), secondaryYAxis: dualAxis && kind != .bar ? secondaryAxis.axis(kind: .value) : nil,
            stacking: stack, plotLines: lineEnabled ? [activeLine] : [], plotBands: bandEnabled ? [activeBand] : [],
            timeAxis: timeEnabled ? .init(start: start, interval: daily ? 86400 / Double(max(1, rows.map { $0.data.count }.max() ?? pointCount)) : interval, timeZone: zone, labelFormatter: formatter) : nil,
            timeGrouping: kind == .column && grouping && timeEnabled ? config : nil,
            groups: (0..<seriesCount).reduce(into: [CartesianSeriesGroup]()) { groups, i in
                let item = series[i]
                if !item.groupID.isEmpty && !groups.contains(where: { $0.id == item.groupID }) {
                    groups.append(.init(id: item.groupID, name: item.groupName))
                }
            })
    }
    var builtTheme: CartesianChartTheme {
        var t = theme
        t.showsTooltipOnHit = interaction.tooltip
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
    mutating func reset() { self = Self(kind: kind) }

    /// 场景按钮从确定的基线开始；只保留搜索词，方便连续切换场景。
    mutating func resetForPreset() {
        let search = query
        reset()
        query = search
    }
    mutating func groupedPresentationPreset() {
        resetForPreset()
        seriesCount = 4; pointCount = 3; timeEnabled = false
        customLabels = "08:00,08:05,08:10"
        interaction.shared = true
        interaction.tooltipGrouping.groupsByBusinessID = true
        interaction.tooltipGrouping.showsGroupSubtotals = true
        theme.legend.isEnabled = true; theme.legend.startsNewRowPerGroup = true
        theme.legend.symbolSize = CGSize(width: 24, height: 18)
        tooltipTheme.maxWidth = 260
        for i in 0..<4 {
            series[i].name = ["光伏", "电池", "温度", "备用"][i]
            series[i].dataText = ["100,120,140", "-40,20,0", "25,28,26", "0,0,0"][i]
            series[i].unit = i == 2 ? "°C" : "W"
            series[i].groupID = i < 2 ? "energy" : (i == 2 ? "environment" : "")
            series[i].groupName = i < 2 ? "能源" : "环境"
            series[i].legendContent = i == 1 ? "自定义状态" : "图片"
            series[i].legendImageName = ["sun.max.fill", "battery.100", "thermometer.medium", "bolt.fill"][i]
            series[i].legendBackground = .secondarySystemBackground
            if kind == .combined { series[i].kind = i < 2 ? .column : .line }
        }
        range = nil; command += 1
    }

    mutating func richTooltipPreset() {
        groupedPresentationPreset()
        interaction.tooltipPresentation.layout = .columns
        interaction.tooltipRowPreset = "综合规则"
        tooltipTheme.maxWidth = 300
    }

    mutating func tooltipSelectionPreset() {
        groupedPresentationPreset()
        interaction.tooltipPresentation.layout = .columns
        interaction.tooltipRowPreset = "能源图标"
        interaction.tooltipSampleSelection.offset = -1
        interaction.tooltipSampleSelection.boundaryPolicy = .clamp
        interaction.tooltipSeriesOffsets = "series-2:0,series-3:0"
        tooltipTheme.maxWidth = 300
        tooltipTheme.position = .fixedTop
        tooltipTheme.offset = CGPoint(x: 12, y: 0)
    }

    mutating func generatedPreset(count: Int) {
        resetForPreset()
        pointCount = count
    }
    mutating func densityPreset(peaks: Bool = false) {
        resetForPreset()
        pointCount = 3000; seriesCount = peaks ? 3 : 6
        sharpPeaks = peaks; missing = peaks
        grouping = kind == .column
        if kind == .line { theme.lineSampling = LineChartSampling() }
        theme.legend.isEnabled = true
    }
    mutating func targetSamplingPreset() {
        densityPreset(peaks: true)
        missing = false // 缺测保护会超额；首个点数示例先演示精确预算。
        theme.lineSampling?.targetPointCount = 200
        theme.lineSampling?.hidesDenseMarkers = false
    }
    var samplingEligible: Bool {
        guard kind == .line else { return false }
        return LineChartRenderer.supportsSampling(model: model, theme: builtTheme)
    }
    var samplingStatus: String {
        guard samplingEligible else {
            return "当前保持原始绘制：可见系列含曲线/阶梯，或启用了堆叠（含序号分组）。"
        }
        if let target = theme.lineSampling?.targetPointCount {
            return "Min/Max 配置可用：每系列目标 \(max(2, target)) 点（含边缘邻点），不足不补点；分段端点/极值保护可超额。"
        }
        return "Min/Max 配置可用：启动门槛不是保留点数；绘制规模由分组宽度和可见密度决定。"
    }
    mutating func autoGapPreset() {
        resetForPreset()
        pointCount = 40; seriesCount = 2; selectedSeries = 0
        stacking = "无"; grouping = false; dualAxis = false
        timeEnabled = true; daily = false; interval = 300
        theme.columnSpacing = nil; theme.lineSampling = nil; theme.lineConnectionStyle = .straight
        theme.legend.isEnabled = true; theme.showsPoints = true; theme.showsArea = true
        for i in 0..<2 {
            series[i] = DemoSeriesSettings(name: i == 0 ? "允许 11 个空点" : "允许 55 分钟缺测",
                                           color: i == 0 ? .systemBlue : .systemOrange)
            series[i].kind = i == 0 ? .area : .spline
            series[i].gapMode = i == 0 ? "按空点数量" : "按缺测时长"
            series[i].dataText = DemoSeriesSettings.autoGapSample
            if i == 1 {
                series[i].style.lineConnectionStyle = .smooth
                series[i].style.showsArea = false
            }
        }
        range = nil; command += 1
    }
    mutating func colorZonesPreset(axis: CartesianZoneAxis?) {
        resetForPreset()
        pointCount = 9; seriesCount = 1; selectedSeries = 0
        stacking = "无"; grouping = false; dualAxis = false; timeEnabled = false
        categoryAxis.manualRange = false; primaryAxis.manualRange = false
        theme.columnSpacing = nil; theme.lineSampling = nil; theme.lineConnectionStyle = .smooth
        theme.legend.isEnabled = true; theme.showsPoints = true; theme.showsArea = true
        series[0] = DemoSeriesSettings(name: "跨零曲线与面积", color: .systemBlue)
        series[0].kind = .areaspline
        series[0].negativeColor = .systemRed
        series[0].dataText = "-30,25,60,15,-40,-10,45,nan,30"
        series[0].zoneMode = axis.map { $0 == .x ? "X 原始索引" : "Y 绘制值" } ?? "关闭"
        series[0].zoneThreshold = axis == .x ? 3.5 : 0
        series[0].zoneFill = axis != nil
        range = nil; report.selectedRange = nil; command += 1
    }
    mutating func bodySelectionPreset() {
        resetForPreset()
        pointCount = 8; seriesCount = 3; timeEnabled = false; stacking = "普通"
        theme.selection = .init(isEnabled: true, color: .systemYellow, lineWidth: 3, fillOpacity: 0.25, pointRadius: 9)
        interaction.shared = true; interaction.crosshair = true
        for i in 0..<3 {
            series[i].dataText = i == 0 ? "10,20,15,25,18,22,16,24" : i == 1 ? "5,8,6,4,7,3,5,6" : "25,30,28,32,27,31,26,34"
            if kind == .combined { series[i].kind = i == 2 ? .line : .column; series[i].participatesInStack = i != 2 }
        }
        command += 1
    }

    mutating func annotationPreset() {
        resetForPreset()
        pointCount = 12; seriesCount = 2; timeEnabled = false; stacking = "普通"
        theme.showsDataLabels = true; theme.showsStackTotalLabels = kind != .line
        theme.dataLabelAvoidsOverlap = true; theme.dataLabelColor = .label
        theme.dataLabelBackgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        for i in 0..<2 {
            series[i].dataText = i == 0 ? "20,21,18,25,22,19,26,23,18,20,21,25" : "5,4,6,3,5,7,3,5,4,6,4,5"
            if kind == .combined { series[i].kind = i == 0 ? .column : .line }
        }
        lineEnabled = true; bandEnabled = true
        plotLine = .init(value: 26, label: "上限 26", labelStyle: .init(color: .label,
            font: .boldSystemFont(ofSize: 15), backgroundColor: .systemBackground,
            alignment: .trailing, verticalAlignment: .top, offset: CGSize(width: -5, height: -24)))
        plotBand = .init(from: 16, to: 23, label: "推荐区间 16–23", labelStyle: .init(color: .systemGreen,
            font: .systemFont(ofSize: 13), backgroundColor: .systemBackground,
            alignment: .leading, verticalAlignment: .bottom))
        command += 1
    }

    mutating func independentAxesPreset() {
        resetForPreset()
        pointCount = 12; seriesCount = 2; timeEnabled = false; dualAxis = kind != .bar
        customLabels = (1...12).map { "周期\($0)" }.joined(separator: ",")
        categoryAxis.categoryLabelInterval = 2
        categoryAxis.rotation = kind == .bar ? 0 : -35
        categoryAxis.style = .init(labelColor: .systemPurple, labelFont: .boldSystemFont(ofSize: 16),
                                   lineColor: .systemPurple, lineWidth: 2)
        primaryAxis.style = .init(labelColor: .systemBlue, labelFont: .systemFont(ofSize: 13),
                                  lineColor: .systemBlue, lineWidth: 2)
        secondaryAxis.style = .init(labelColor: .systemOrange, labelFont: .systemFont(ofSize: 18),
                                    lineColor: .systemOrange, lineWidth: 3)
        primaryAxis.suffix = " W"; secondaryAxis.suffix = " %"
        series[1].axis = dualAxis ? 1 : 0
        series[1].dataText = "10,20,30,40,50,60,70,80,90,100,90,80"
        theme.legend.isEnabled = true
        command += 1
    }

    mutating func columnColorZonesPreset() {
        resetForPreset()
        pointCount = 8; seriesCount = kind == .combined ? 3 : 2; selectedSeries = 1
        stacking = "普通"; timeEnabled = false
        theme.legend.isEnabled = true; theme.showsDataLabels = true
        customLabels = "负阈值,负中值,正阈下,正阈值,正阈上,缺测,负阈上,高值"
        for i in 0..<2 {
            series[i] = DemoSeriesSettings(name: i == 0 ? "基底 40" : "阈值分段", color: i == 0 ? .systemBlue : .systemOrange)
            series[i].kind = .column
            series[i].dataText = i == 0 ? "-40,-40,40,40,40,40,-40,40" : "-20,-10,19,20,21,nan,-19,60"
        }
        series[1].zoneMode = "Y 绘制值"; series[1].zoneThreshold = 20
        series[1].lowerZoneColor = .systemRed; series[1].upperZoneColor = .systemGreen
        series[1].negativeColor = .systemPurple; series[1].palette = true
        if kind == .combined {
            series[2] = DemoSeriesSettings(name: "目标线", color: .systemTeal)
            series[2].kind = .line; series[2].participatesInStack = false
            series[2].dataText = "80,80,80,80,80,80,80,80"
        }
        range = nil; report.selectedRange = nil; command += 1
    }

    mutating func stackedAreaSeamPreset() {
        resetForPreset()
        pointCount = 12; seriesCount = 3; selectedSeries = 2
        stacking = "普通"; timeEnabled = false
        theme.showsArea = true; theme.lineConnectionStyle = .smooth
        theme.legend.isEnabled = true
        let names = ["底层曲线", "正负与缺测", "上层缺测"]
        let samples = ["10,25,15,30,20,35,25,40,30,45,35,50",
                       "20,40,10,-10,-20,-5,nan,30,10,35,20,40",
                       "12,12,12,12,12,12,12,12,nan,12,12,12"]
        for i in 0..<3 {
            let color = [UIColor.systemBlue, .systemOrange, .systemGreen][i]
            series[i] = DemoSeriesSettings(name: names[i], color: color)
            series[i].dataText = samples[i]; series[i].kind = .areaspline
            series[i].style.areaGradientColors = [color.withAlphaComponent(0.55)]
        }
        range = nil; command += 1
    }
    mutating func thinStackedAreaPreset() {
        resetForPreset()
        pointCount = 5; seriesCount = 3; selectedSeries = 1
        stacking = "普通"; timeEnabled = false
        theme.showsArea = true; theme.showsPoints = true
        theme.stackedAreaBoundaryMode = .followBaseline
        theme.legend.isEnabled = true
        let samples = ["10,90,10,90,10", "2,2,2,2,2", "3,6,3,6,3"]
        for i in 0..<3 {
            let color = [UIColor.systemBlue, .systemOrange, .systemGreen][i]
            series[i] = DemoSeriesSettings(name: ["底层曲线", "薄层直线", "上层阶梯"][i], color: color)
            series[i].dataText = samples[i]; series[i].kind = i == 0 ? .areaspline : .area
            series[i].style.lineConnectionStyle = [.smooth, .straight, .stepCenter][i]
            series[i].style.areaGradientColors = [color.withAlphaComponent(0.6)]
        }
        range = nil; command += 1
    }
    mutating func crossingStackedAreaPreset() {
        resetForPreset()
        pointCount = 5; seriesCount = 3; selectedSeries = 2
        stacking = "普通"; timeEnabled = false
        theme.showsArea = true; theme.showsPoints = true
        theme.stackedAreaBoundaryMode = .followBaseline; theme.legend.isEnabled = true
        let samples = ["40,55,35,50,40", "-30,-45,-25,-35,-30", "15,-15,15,-15,15"]
        for i in 0..<3 {
            let color = [UIColor.systemBlue, .systemOrange, .systemGreen][i]
            series[i] = DemoSeriesSettings(name: ["正值基线", "负值基线", "跨零面积"][i], color: color)
            series[i].dataText = samples[i]; series[i].kind = i < 2 ? .areaspline : .area
            series[i].style.lineConnectionStyle = i < 2 ? .smooth : .straight
            series[i].style.areaGradientColors = [color.withAlphaComponent(0.6)]
        }
        range = nil; command += 1
    }
    mutating func groupedPreset() {
        resetForPreset()
        pointCount = 6; seriesCount = kind == .combined ? 5 : 4
        selectedSeries = kind == .combined ? 4 : 0
        stacking = "普通"; grouping = false; timeEnabled = false; dualAxis = kind == .combined
        theme.legend.isEnabled = true; theme.showsStackTotalLabels = true
        theme.columnSpacing = kind == .line ? nil : .init(columnWidth: 14, inner: 6, group: 18)
        for i in 0..<seriesCount {
            series[i] = DemoSeriesSettings(name: ["A 光伏", "A 电池", "B 光伏", "B 电池", "目标"][i], color: [UIColor.systemBlue, .systemTeal, .systemOrange, .systemYellow, .systemRed][i])
            series[i].stackID = i < 2 ? "A" : "B"
            series[i].dataText = i == 4 ? "80,90,75,95,85,100" : (i.isMultiple(of: 2) ? "60,80,50,70,90,60" : "20,30,25,15,20,30")
            if i == 4 {
                series[i].kind = .spline; series[i].participatesInStack = false; series[i].axis = 1
                series[i].style.lineWidth = 3; series[i].style.showsPoints = true
            }
        }
        range = nil; command += 1
    }

    mutating func percentStackedAreaPreset() {
        resetForPreset()
        pointCount = 5; seriesCount = 3; selectedSeries = 1
        stacking = "百分比"; timeEnabled = false
        theme.showsArea = true; theme.showsPoints = false
        theme.stackedAreaBoundaryMode = .followBaseline; theme.legend.isEnabled = true
        let samples = ["10,90,10,80,20", "1,1,1,1,1", "20,20,20,20,20"]
        for i in 0..<3 {
            let color = [UIColor.systemBlue, .systemOrange, .systemGreen][i]
            series[i] = DemoSeriesSettings(name: ["底层曲线", "薄层直线", "上层阶梯"][i], color: color)
            series[i].dataText = samples[i]; series[i].kind = i == 0 ? .areaspline : .area
            series[i].style.lineConnectionStyle = [.smooth, .straight, .stepAfter][i]
            series[i].style.areaGradientColors = [color.withAlphaComponent(0.6)]
        }
        range = nil; command += 1
    }

    mutating func gapBoundaryStackedAreaPreset() {
        resetForPreset()
        pointCount = 7; seriesCount = 2; selectedSeries = 1
        stacking = "普通"; timeEnabled = false
        theme.showsArea = true; theme.showsPoints = false
        theme.stackedAreaBoundaryMode = .followBaseline; theme.legend.isEnabled = true
        for i in 0..<2 {
            let color: UIColor = i == 0 ? .systemBlue : .systemOrange
            series[i] = DemoSeriesSettings(name: i == 0 ? "断开的下层" : "跨缺测上层", color: color)
            series[i].dataText = i == 0 ? "10,90,20,nan,70,15,50" : "4,nan,nan,nan,nan,nan,4"
            series[i].kind = i == 0 ? .areaspline : .area
            series[i].style.lineConnectionStyle = i == 0 ? .smooth : .straight
            series[i].connectNulls = i == 1
            series[i].style.areaGradientColors = [color.withAlphaComponent(0.6)]
        }
        range = nil; command += 1
    }

    mutating func sourceSwitchStackedAreaPreset() {
        resetForPreset()
        pointCount = 3; seriesCount = 3; selectedSeries = 2
        stacking = "普通"; timeEnabled = false
        theme.showsArea = true; theme.showsPoints = false
        theme.stackedAreaBoundaryMode = .followBaseline; theme.legend.isEnabled = true
        let samples = ["20,20,20", "30,-30,30", "5,5,5"]
        for i in 0..<3 {
            let color = [UIColor.systemBlue, .systemOrange, .systemGreen][i]
            series[i] = DemoSeriesSettings(name: ["固定基底", "跨零前层", "同符号上层"][i], color: color)
            series[i].dataText = samples[i]; series[i].kind = .areaspline
            series[i].style.lineConnectionStyle = .smooth
            series[i].style.areaGradientColors = [color.withAlphaComponent(0.6)]
        }
        range = nil; command += 1
    }
    mutating func divergingStackedAreaPreset() {
        resetForPreset()
        pointCount = 8; seriesCount = 3; selectedSeries = 2
        stacking = "普通"; timeEnabled = false
        theme.showsArea = true; theme.showsPoints = false
        theme.stackedAreaBoundaryMode = .diverging; theme.legend.isEnabled = true
        let samples = ["20,40,10,-20,-30,20,40,20", "5,-10,5,8,nan,8,-12,10", "2,2,2,2,2,2,2,2"]
        for i in 0..<3 {
            let color = [UIColor.systemBlue, .systemOrange, .systemGreen][i]
            series[i] = DemoSeriesSettings(name: ["正负基底", "跨零缺测", "薄层阶梯"][i], color: color)
            series[i].dataText = samples[i]; series[i].kind = .area
            series[i].style.lineConnectionStyle = [.smooth, .straight, .stepCenter][i]
            series[i].style.areaGradientColors = [color.withAlphaComponent(0.65)]
        }
        range = nil; command += 1
    }

}
