import SwiftUI

/// 同页预设；关闭配置保留编辑内容，整体恢复默认才清空。字典始终按稳定系列 ID 保存。
struct ChartSpecificationInteractionDemoSettings {
    var usesTooltip = false
    var usesLegend = false
    var tooltip: ChartTooltipSpecification = {
        var value = ChartTooltipSpecification(); value.layout = .columns; value.position = .fixedTop
        value.headerTemplate = "当前 {key}"; value.sampleSelection.offset = -1
        value.sampleSelection.boundaryPolicy = .clamp
        return value
    }()
    var legend: ChartLegendSpecification = {
        var value = ChartLegendSpecification(); value.position = .top; value.alignment = .leading
        return value
    }()
    var isConfigured: Bool { usesTooltip || usesLegend }
}

struct ChartSpecificationInteractionControls: View {
    @Binding var settings: ChartSpecificationInteractionDemoSettings
    let seriesIDs: [String]
    @State private var seriesID = "source-0"
    private func rule<T>(_ key: WritableKeyPath<ChartTooltipSeriesRule, T>) -> Binding<T> {
        .init(get: { (settings.tooltip.seriesRules[seriesID] ?? .init())[keyPath: key] }, set: {
            settings.tooltip.seriesRules[seriesID, default: .init()][keyPath: key] = $0
        })
    }
    var body: some View {
        Section("提示 / 图例 · 通用模型 v6") {
            Toggle("使用中立提示配置", isOn: $settings.usesTooltip).accessibilityIdentifier("specification.tooltipConfig")
            Toggle("使用中立图例布局", isOn: $settings.usesLegend).accessibilityIdentifier("specification.legendConfig")
            Text("提示 \(settings.usesTooltip ? settings.tooltip.layout.rawValue : "host") · 取值 \(settings.tooltip.sampleSelection.offset) · 图例 \(settings.usesLegend ? settings.legend.position.rawValue : "default")")
                .font(.caption).accessibilityIdentifier("specification.interactionStatus")
            Text("点击上方图表查看提示。预设取前一槽位并在首尾钳制；表头和命中仍是当前点。图例按屏幕方向布局，不改变数据或堆叠。")
                .font(.caption)
            DisclosureGroup("提示详细配置") {
                Toggle("显示内置提示", isOn: $settings.tooltip.isEnabled).accessibilityIdentifier("specification.tooltipVisible")
                Picker("提示布局", selection: $settings.tooltip.layout) {
                    ForEach(ChartTooltipLayout.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("提示位置", selection: $settings.tooltip.position) {
                    ForEach(ChartTooltipPosition.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                if settings.tooltip.position == .fixedTop {
                    Text("固定顶部提示限制在绘图区内，避开标题和图例；仍覆盖数据，不预留额外空间。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("显示表头", isOn: .init(get: { settings.tooltip.headerTemplate != nil }, set: {
                    settings.tooltip.headerTemplate = $0 ? "当前 {key}" : nil
                }))
                if settings.tooltip.headerTemplate != nil {
                    TextField("表头模板", text: .init(get: { settings.tooltip.headerTemplate ?? "" }, set: { settings.tooltip.headerTemplate = $0 }))
                }
                Toggle("隐藏零取值", isOn: $settings.tooltip.hidesZeroValues)
                Stepper("全局取值偏移：\(settings.tooltip.sampleSelection.offset)", value: $settings.tooltip.sampleSelection.offset, in: -6...6)
                Picker("偏移越界", selection: $settings.tooltip.sampleSelection.boundaryPolicy) {
                    ForEach(ChartTooltipBoundaryPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("显示取值来源", isOn: $settings.tooltip.sampleSelection.showsSourceLabel)
                TextField("来源模板", text: $settings.tooltip.sampleSelection.sourceLabelTemplate)
                Picker("当前系列 ID", selection: $seriesID) {
                    ForEach(seriesIDs, id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("specification.tooltipSeries")
                Toggle("隐藏该提示行", isOn: rule(\.isHidden)).accessibilityIdentifier("specification.tooltipHideRow")
                Toggle("该行只显示名称", isOn: rule(\.hidesValue))
                Toggle("覆盖提示标题", isOn: .init(get: { settings.tooltip.seriesRules[seriesID]?.title != nil }, set: {
                    settings.tooltip.seriesRules[seriesID, default: .init()].title = $0 ? "提示 \(seriesID)" : nil
                }))
                if settings.tooltip.seriesRules[seriesID]?.title != nil {
                    TextField("提示标题", text: .init(get: { settings.tooltip.seriesRules[seriesID]?.title ?? "" }, set: {
                        settings.tooltip.seriesRules[seriesID, default: .init()].title = $0
                    }))
                }
                Toggle("逐系列取值覆盖", isOn: .init(get: { settings.tooltip.sampleSelection.offsetsBySeriesID[seriesID] != nil }, set: {
                    settings.tooltip.sampleSelection.offsetsBySeriesID[seriesID] = $0 ? 0 : nil
                }))
                if settings.tooltip.sampleSelection.offsetsBySeriesID[seriesID] != nil {
                    Stepper("该系列偏移：\(settings.tooltip.sampleSelection.offsetsBySeriesID[seriesID] ?? 0)", value: .init(
                        get: { settings.tooltip.sampleSelection.offsetsBySeriesID[seriesID] ?? 0 },
                        set: { settings.tooltip.sampleSelection.offsetsBySeriesID[seriesID] = $0 }), in: -6...6)
                }
                Button("清除该系列提示覆盖") {
                    settings.tooltip.seriesRules[seriesID] = nil; settings.tooltip.sampleSelection.offsetsBySeriesID[seriesID] = nil
                }
            }
            DisclosureGroup("图例详细配置") {
                Picker("图例位置", selection: $settings.legend.position) {
                    ForEach(ChartLegendPlacement.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("行内对齐", selection: $settings.legend.alignment) {
                    ForEach(ChartLegendRowAlignment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("溢出处理", selection: $settings.legend.overflow) {
                    ForEach(ChartLegendOverflowPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Stepper("最大行数：\(settings.legend.maxRows)", value: $settings.legend.maxRows, in: 1...10)
                Stepper("最大高度：\(Int(settings.legend.maxHeight))", value: $settings.legend.maxHeight, in: 0...240, step: 20)
                Stepper("侧边最大宽度：\(Int(settings.legend.maxWidth))", value: $settings.legend.maxWidth, in: 0...240, step: 20)
                Toggle("允许图例点击显隐", isOn: $settings.legend.allowsToggling)
                Toggle("按相邻组换行", isOn: $settings.legend.startsNewRowPerGroup)
                Picker("标题系列 ID", selection: $seriesID) {
                    ForEach(seriesIDs, id: \.self) { Text($0).tag($0) }
                }
                Toggle("覆盖图例标题", isOn: .init(get: { settings.legend.titlesBySeriesID[seriesID] != nil }, set: {
                    settings.legend.titlesBySeriesID[seriesID] = $0 ? "图例 \(seriesID)" : nil
                }))
                if settings.legend.titlesBySeriesID[seriesID] != nil {
                    TextField("图例标题", text: .init(get: { settings.legend.titlesBySeriesID[seriesID] ?? "" }, set: { settings.legend.titlesBySeriesID[seriesID] = $0 }))
                }
            }
        }
    }
}
