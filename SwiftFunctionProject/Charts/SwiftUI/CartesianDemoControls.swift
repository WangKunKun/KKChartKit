import SwiftUI

/// 面板登记表：测试通过同一 Binding 修改实际预览配置。
enum CartesianDemoControls {
    static func sections(_ b: Binding<CartesianDemoState>) -> [ChartDemoPanel.DemoSection] {
        let currentSeries = Binding<DemoSeriesSettings>(
            get: { b.wrappedValue.series[b.wrappedValue.selectedSeries] },
            set: { b.wrappedValue.series[b.wrappedValue.selectedSeries] = $0 })
        var result: [ChartDemoPanel.DemoSection] = []
        result.append(.init(title: "数据与布局", items: [
            .textField(label: "图表标题", value: b.title), DemoProperty.integer("系列数", b.seriesCount, 1...6),
            DemoProperty.integer("数据点数", b.pointCount, 2...3000),
            .button(label: "288 点（5 分钟/点）") { b.wrappedValue.generatedPreset(count: 288) },
            .button(label: "1440 点（1 分钟/点）") { b.wrappedValue.generatedPreset(count: 1440) },
            .button(label: "3000 点压力场景") { b.wrappedValue.densityPreset() },
            .button(label: "数据语义：100 + 50 堆叠") {
                b.wrappedValue.resetForPreset()
                b.wrappedValue.pointCount = 3; b.wrappedValue.seriesCount = 2; b.wrappedValue.stacking = "普通"; b.wrappedValue.grouping = false; b.wrappedValue.dualAxis = false
                b.wrappedValue.timeEnabled = false; b.wrappedValue.theme.columnSpacing = nil; b.wrappedValue.interaction.shared = false
                for i in 0..<2 {
                    b.wrappedValue.series[i] = DemoSeriesSettings(name: i == 0 ? "光伏" : "电池", color: i == 0 ? .systemBlue : .systemOrange)
                    b.wrappedValue.series[i].dataText = i == 0 ? "100,100,100" : "50,-50,50"
                    b.wrappedValue.series[i].unit = "W"; b.wrappedValue.series[i].groupID = "energy"; b.wrappedValue.series[i].groupName = "能源"
                    b.wrappedValue.series[i].valueFormat = CartesianValueFormat()
                }
                b.wrappedValue.range = nil; b.wrappedValue.command += 1
            },
            .button(label: "更新样本数据") { b.wrappedValue.seed += 1; b.wrappedValue.report.selectedRange = nil },
            .toggle(label: "正负混合", value: b.negative), .toggle(label: "包含缺测", value: b.missing),
            DemoProperty.number("基础图表高度", b.height, 160...500, step: 10), .toggle(label: "测量并追加图例高度", value: b.autoLegendHeight)]))
        if b.wrappedValue.kind == .line || b.wrappedValue.kind == .combined {
            result.append(.init(title: "堆叠面积预设", items: [
                .button(label: "正负与缺测堆叠面积接缝场景") { b.wrappedValue.stackedAreaSeamPreset() },
                .button(label: "薄层混合线型面积对照场景") { b.wrappedValue.thinStackedAreaPreset() },
                .button(label: "跨零正负基线面积对照场景") { b.wrappedValue.crossingStackedAreaPreset() },
                .button(label: "前层换链面积对照场景") { b.wrappedValue.sourceSwitchStackedAreaPreset() },
                .button(label: "缺测底边分段面积对照场景") { b.wrappedValue.gapBoundaryStackedAreaPreset() },
                .button(label: "自动百分比面积对照场景") { b.wrappedValue.percentStackedAreaPreset() },
                .button(label: "正负分链统一断段场景") { b.wrappedValue.divergingStackedAreaPreset() }
            ]))
            result.append(.init(title: "缺测连接预设", items: [
                .button(label: "11/12/13 空点 autoGap 场景") { b.wrappedValue.autoGapPreset() }
            ]))
            result.append(.init(title: "颜色分区预设 zones", items: [
                .button(label: "X 分区曲线面积 zones 场景") { b.wrappedValue.colorZonesPreset(axis: .x) },
                .button(label: "Y 分区曲线面积 zones 场景") { b.wrappedValue.colorZonesPreset(axis: .y) },
                .button(label: "曲线负值换色 zones 场景") { b.wrappedValue.colorZonesPreset(axis: nil) }
            ]))
        }
        if b.wrappedValue.kind != .line {
            result.append(.init(title: "柱条阈值着色预设 zones", items: [
                .button(label: "柱条阈值整段换色场景") { b.wrappedValue.columnColorZonesPreset() }
            ]))
        }
        result.append(.init(title: "分组提示与图例预设", items: [
            .button(label: "分组提示与图片图例场景") { b.wrappedValue.groupedPresentationPreset() },
            .button(label: "富内容提示与逐点规则场景") { b.wrappedValue.richTooltipPreset() },
            .button(label: "前值与置顶提示场景") { b.wrappedValue.tooltipSelectionPreset() }
        ]))
        result.append(.init(title: "分组堆叠预设", items: [.button(label: "两组堆叠与目标线") { b.wrappedValue.groupedPreset() }]))
        result.append(.init(title: "当前系列（逐系列配置）", items: [DemoProperty.index("编辑系列序号（从0开始）", b.selectedSeries, count: b.wrappedValue.seriesCount)] + DemoSeriesSettings.items(currentSeries, kind: b.wrappedValue.kind)))
        result.append(.init(title: "堆叠与双轴", items: [
            .picker(label: "堆叠", selection: b.stacking, options: ["无", "普通", "百分比", "固定基准百分比", "序号分组"]), DemoProperty.integer("序号分组数量（显式 stackID 优先）", b.stackGroupCount, 1...6), DemoProperty.number("固定百分比基准", b.percentBase, 1...2000)] + (b.wrappedValue.kind == .bar ? [] : [.toggle(label: "启用次值轴（在系列中指定0/1）", value: b.dualAxis)])))
        result.append(.init(title: "独立轴样式预设", items: [
            .button(label: "独立轴颜色字体与标签步长场景") { b.wrappedValue.independentAxesPreset() }
        ]))
        result.append(.init(title: "类目轴", items: [.textField(label: "标签覆盖（逗号分隔）", value: b.customLabels)] + DemoAxisSettings.categoryItems(b.categoryAxis, isHorizontal: b.wrappedValue.kind == .bar)))
        result.append(.init(title: "主值轴", items: DemoAxisSettings.items(b.primaryAxis)))
        if b.wrappedValue.kind != .bar && b.wrappedValue.dualAxis { result.append(.init(title: "次值轴", items: DemoAxisSettings.items(b.secondaryAxis))) }
        result.append(.init(title: "时间轴", items: [
            .toggle(label: "启用时间轴", value: b.timeEnabled), .toggle(label: "一天均分采样", value: b.daily), DemoProperty.number("采样间隔秒（关闭一天均分后生效）", b.interval, 1...3600, step: 1),
            .picker(label: "时区", selection: b.timeZone, options: ["UTC", "Asia/Shanghai", "America/Los_Angeles"]),
            .picker(label: "日期格式", selection: b.dateFormat, options: ["自动", "HH:mm:ss", "MM-dd HH:mm"]),
            .date(label: "采样起点（设备本地时间输入）", value: b.start)]))
        if b.wrappedValue.kind == .line {
            result.append(.init(title: "高密度折线 Min/Max", items: DemoThemeFields.lineSamplingItems(b.theme.lineSampling) + [
                .toggle(label: "尖峰与低谷样本", value: b.sharpPeaks),
                .button(label: "3000 点尖峰降采样场景") { b.wrappedValue.densityPreset(peaks: true) },
                .button(label: "3000 点目标点数采样场景") { b.wrappedValue.targetSamplingPreset() },
                .button(label: "查看尖峰附近原始点") {
                    let center = b.wrappedValue.pointCount / 3
                    b.wrappedValue.range = max(0, center - 12)..<min(b.wrappedValue.pointCount, center + 12); b.wrappedValue.command += 1
                }]))
        }
        if b.wrappedValue.kind == .column {
            result.append(.init(title: "高密度时间聚合", items: [
                .toggle(label: "按可用宽度自动聚合（需时间轴）", value: b.grouping), DemoProperty.number("最小柱宽 pt", b.groupingConfig.minimumColumnWidth, 1...12),
                .toggle(label: "复用聚合与时间标签缓存", value: b.groupingConfig.isCacheEnabled),
                DemoProperty.number("缩放粒度切换缓冲比例（0关闭）", b.groupingConfig.granularityHysteresis, 0...0.5, step: 0.05),
                .textField(label: "首选聚合区间秒（逗号分隔）", value: b.intervalText)]))
        }
        let all = DemoThemeFields.items(b.theme).filter { $0.label != "showsTooltipOnHit" }
        let lineNames = ["lineWidth", "lineConnectionStyle", "lineDashStyle", "showsPoints", "point", "showsArea", "stackedAreaBoundaryMode"]
        let columns = ["column", "stackSeparator", "showsColumnEntranceAnimation", "showsStackTotalLabels"]
        let specific = b.wrappedValue.kind == .combined ? lineNames + columns : b.wrappedValue.kind == .line ? lineNames : columns
        let excluded = b.wrappedValue.kind == .combined ? [] : b.wrappedValue.kind == .line ? columns : lineNames
        let general = all.filter { item in !(specific + excluded).contains(where: { item.label.contains($0) }) }
        result.append(.init(title: "通用主题（背景/网格/字体/标签）", items: general + [
            .picker(label: "数据标签格式", selection: b.valueFormat, options: ["自动", "整数", "两位小数", "百分号"])]))
        result.append(.init(title: b.wrappedValue.kind == .combined ? "混合图柱体与线型外观" : b.wrappedValue.kind == .line ? "折线与数据点外观" : "柱体与堆叠外观", items: all.filter { item in specific.contains(where: { item.label.contains($0) }) }))
        if b.wrappedValue.kind != .line {
            result.append(.init(title: "固定间距与区间定位", items: [
                DemoProperty.integer("区间起点索引", b.rangeStart, 0...3000),
                DemoProperty.integer("区间终点索引（不含）", b.rangeEnd, 1...3000),
                .button(label: "定位自定义区间") {
                    let lower = min(max(0, b.wrappedValue.rangeStart), max(0, b.wrappedValue.model.maxPointCount - 1))
                    let upper = min(max(lower + 1, b.wrappedValue.rangeEnd), b.wrappedValue.model.maxPointCount)
                    guard lower < upper else { return }
                    b.wrappedValue.range = lower..<upper; b.wrappedValue.command += 1
                },
                .button(label: "固定尺寸滚动示例（60点 × 3系列）") {
                    b.wrappedValue.resetForPreset()
                    b.wrappedValue.pointCount = 60; b.wrappedValue.seriesCount = 3; b.wrappedValue.stacking = "无"; b.wrappedValue.grouping = false
                    for i in 0..<3 { b.wrappedValue.series[i].dataText = ""; b.wrappedValue.series[i].visible = true }
                    b.wrappedValue.theme.columnSpacing = CartesianColumnSpacing(columnWidth: 12, inner: 4, group: 16)
                    b.wrappedValue.range = nil; b.wrappedValue.command += 1
                }
            ]))
        }
        if b.wrappedValue.kind == .line || b.wrappedValue.kind == .combined {
            result.append(.init(title: "面积渐变", items: [.toggle(label: "自定义渐变（需 showsArea）", value: b.gradient), .color(label: "渐变起色", value: b.gradientA), .color(label: "渐变末色", value: b.gradientB)]))
        }
        if b.wrappedValue.kind != .line { result.append(.init(title: "堆叠总量格式", items: [.picker(label: "总量格式", selection: b.totalFormat, options: ["自动", "整数", "两位小数", "百分号"])])) }
        result.append(.init(title: "图例布局", items: DemoThemeFields.items(b.theme.legend) + [.toggle(label: "展开完整图例（关闭为限高滚动）", value: b.expandLegend)]))
        result.append(.init(title: "主体选中验收场景", items: [.button(label: "点柱条与共享选中高亮场景") { b.wrappedValue.bodySelectionPreset() }]))
        result.append(.init(title: "标注验收场景", items: [.button(label: "参考线色带与标签避让场景") { b.wrappedValue.annotationPreset() }]))
        result.append(.init(title: "阈值参考线", items: [
            .toggle(label: "启用参考线", value: b.lineEnabled), DemoProperty.number("参考值", b.plotLine.value, -100...500), DemoProperty.integer("参考线值轴", b.plotLine.yAxisIndex, 0...1), .color(label: "参考线颜色", value: b.plotLine.color), DemoProperty.number("参考线宽", b.plotLine.lineWidth, 0.5...6), DemoProperty.choice("参考线样式", b.plotLine.dashStyle), .textField(label: "参考线标签", value: DemoProperty.optional(b.plotLine.label, default: ""))] + DemoThemeFields.annotationItems("参考线标签", b.plotLine.labelStyle)))
        result.append(.init(title: "区间色带", items: [
            .toggle(label: "启用色带", value: b.bandEnabled), DemoProperty.number("色带起点", b.plotBand.from, -100...500), DemoProperty.number("色带终点", b.plotBand.to, -100...500), DemoProperty.integer("色带值轴", b.plotBand.yAxisIndex, 0...1), .color(label: "色带颜色", value: b.plotBand.color), .textField(label: "色带标签", value: DemoProperty.optional(b.plotBand.label, default: ""))] + DemoThemeFields.annotationItems("色带标签", b.plotBand.labelStyle)))
        result.append(.init(title: "交互与弹窗行为", items: DemoInteractionSettings.items(b.interaction)))
        result.append(.init(title: "弹窗外观", items: DemoThemeFields.items(b.tooltipTheme)))
        return CartesianDemoRules.apply(to: result, state: b.wrappedValue)
    }
}
