import SwiftUI

/// 按稳定轴 ID 保存示例展示；不改原始采样或业务单位。
struct ChartSpecificationAxisDemoSettings {
    var explicitTicks = false
    var formatted = false
    var weight: ChartFontWeight?
    var isConfigured: Bool { explicitTicks || formatted || weight != nil }
}

/// 同一图表调试页中的通用模型入口；输入只构造 Specification，再经过真实适配器。
struct ChartSpecificationDemoSettings {
    var missing = true
    var percent = false
    var interpolation: ChartInterpolation = .monotone
    var legend = true
    var reversedAxis = false
    var numericDomain = false
    var area = true
    var boundary: ChartStackedAreaBoundary = .independent
    var secondaryAxis = false
    var categoryLabelInterval: Int?
    var axisPresentation: [String: ChartSpecificationAxisDemoSettings] = [:]

    func axis(_ id: String) -> ChartAxisSpecification {
        let settings = axisPresentation[id] ?? .init()
        var appearance = ChartAxisAppearance(); appearance.labelFontWeight = settings.weight
        var number = ChartValuePresentation(); number.localeIdentifier = "en_US_POSIX"
        return .init(id: id, isReversed: id == "power" && reversedAxis, appearance: appearance,
                     tickPositions: settings.explicitTicks ? (id == "power" ? [-100, -50, 0, 50, 100, 150] : [-50, 0, 25, 50, 100]) : nil,
                     labelFormat: settings.formatted ? .init(number: number, unit: percent ? "%" : id == "power" ? "W" : "°C") : nil)
    }
    // 与数组下标/当前选中无关；逐系列 ID 保存，关闭只移除该系列配置。
    var valueColorZones: [String: ChartValueColorZones] = [:]

    static func thresholdPreset(_ source: ChartZoneValueSource = .drawValue) -> ChartValueColorZones {
        .init(valueSource: source, zones: [
            .init(upperBound: 0, color: .init(red: 0.85, green: 0.16, blue: 0.22)),
            .init(upperBound: 50, color: .init(red: 0.95, green: 0.55, blue: 0.10)),
            .init(color: .init(red: 0.08, green: 0.62, blue: 0.40))
        ])
    }

    func specification(kind: CartesianDemoKind) -> ChartSpecification {
        let categories = (0..<6).map { ChartCategory(id: "slot-\($0)", label: "\(8 + $0):00") }
        let hasSecondary = secondaryAxis && kind != .bar
        let rows = (0..<(kind == .combined ? 3 : 2)).map { index -> ChartSeriesSpecification in
            let mark: ChartMark = kind == .bar || kind == .column || (kind == .combined && index == 0)
                ? .bar : area ? .area : .line
            let values: [Double] = index == 0 ? [40, 60, -20, -50, 30, 80]
                : index == 1 ? [20, 30, -10, -20, 40, 30] : [5, -3, 8, -4, 2, 6]
            let samples = categories.enumerated().map { slot, category in
                ChartSample(id: "sample-\(index)-\(slot)",
                            coordinate: numericDomain ? .number(Double(slot * slot)) : .category(category.id),
                            value: missing && slot == 2 && index == (kind == .combined ? 1 : 0) ? nil : values[slot], metadata: ["device": "demo-\(index)"])
            }
            var appearance = ChartSeriesAppearance()
            appearance.color = index == 0 ? .init(red: 0.12, green: 0.42, blue: 0.88)
                : index == 1 ? .init(red: 0.95, green: 0.45, blue: 0.12) : .init(red: 0.08, green: 0.62, blue: 0.52)
            appearance.valueColorZones = valueColorZones["source-\(index)"]
            if mark != .bar { appearance.marker = .circle; appearance.lineWidth = 2 }
            return .init(id: "source-\(index)", name: index == 0 ? "光伏" : index == 1 ? "电池" : "薄层贡献", mark: mark,
                         valueAxisID: hasSecondary && index == (kind == .combined ? 2 : 1) ? "temperature" : "power",
                         samples: samples, groupID: "energy", stackID: "supply",
                         unit: hasSecondary && index == (kind == .combined ? 2 : 1) ? "°C" : "W",
                         interpolation: mark == .bar ? .linear : interpolation, appearance: appearance)
        }
        let axes = [axis("power")] + (hasSecondary ? [axis("temperature")] : [])
        var domainStyle = ChartAxisAppearance(); domainStyle.labelFontWeight = axisPresentation["domain"]?.weight
        let hasAxisPresentation = categoryLabelInterval != nil || domainStyle.labelFontWeight != nil
            || axes.contains { $0.tickPositions != nil || $0.labelFormat != nil || $0.appearance.labelFontWeight != nil }
        return .init(id: "energy-preview", title: "通用模型预览", orientation: kind == .bar ? .horizontal : .vertical,
                     domain: numericDomain ? .numeric : .categories(categories),
                     valueAxes: axes, series: rows,
                     groups: [.init(id: "energy", name: "能源")],
                     stacking: percent ? .percentOfAbsoluteTotal : .sum, showsLegend: legend,
                     domainAppearance: domainStyle,
                     schemaVersion: hasAxisPresentation ? 4 : rows.contains { $0.appearance.valueColorZones != nil } ? 3 : boundary == .independent ? 1 : 2,
                     stackedAreaBoundary: boundary, categoryLabelInterval: categoryLabelInterval)
    }
}

struct ChartSpecificationDemo: View {
    let kind: CartesianDemoKind
    @State private var settings = ChartSpecificationDemoSettings()
    @State private var selectedSeriesID = "source-0"
    @State private var selectedAxisID = "power"

    private func axisBinding<T>(_ keyPath: WritableKeyPath<ChartSpecificationAxisDemoSettings, T>) -> Binding<T> {
        .init(get: { (settings.axisPresentation[selectedAxisID] ?? .init())[keyPath: keyPath] }, set: {
            settings.axisPresentation[selectedAxisID, default: .init()][keyPath: keyPath] = $0
        })
    }
    private var intervalEnabled: Binding<Bool> {
        .init(get: { settings.categoryLabelInterval != nil }, set: { settings.categoryLabelInterval = $0 ? 2 : nil })
    }

    private var selectedIsBar: Bool {
        kind == .column || kind == .bar || (kind == .combined && selectedSeriesID == "source-0")
    }
    private var zonesEnabled: Binding<Bool> {
        .init(get: { settings.valueColorZones[selectedSeriesID] != nil }, set: {
            settings.valueColorZones[selectedSeriesID] = $0 ? ChartSpecificationDemoSettings.thresholdPreset() : nil
        })
    }
    private var zoneSource: Binding<ChartZoneValueSource> {
        .init(get: { settings.valueColorZones[selectedSeriesID]?.valueSource ?? .drawValue }, set: {
            settings.valueColorZones[selectedSeriesID]?.valueSource = $0
        })
    }

    var body: some View {
        let result = Result { try HYMChartsSpecificationAdapter().makeConfiguration(from: settings.specification(kind: kind)) }
        VStack(spacing: 8) {
            switch result {
            case .success(let configuration):
                preview(configuration).frame(height: 270).padding(.horizontal, 12)
                Text("适配成功 · \(configuration.source.series.count) 个稳定系列 ID · 缺测保留 · 原始负值不改写")
                    .font(.caption).accessibilityIdentifier("specification.success")
                Text("schema v\(configuration.source.schemaVersion) · \(configuration.source.stackedAreaBoundary.rawValue)")
                    .font(.caption).accessibilityIdentifier("specification.boundaryStatus")
            case .failure(let error):
                ScrollView { Text(error.localizedDescription).foregroundStyle(.red).padding() }
                    .frame(height: 180).accessibilityIdentifier("specification.error")
            }
            Text("分区 \(selectedSeriesID) · \(settings.valueColorZones[selectedSeriesID]?.valueSource.rawValue ?? "关闭")")
                .font(.caption).accessibilityIdentifier("specification.zoneStatus")
            let axisSettings = settings.axisPresentation[selectedAxisID] ?? .init()
            Text("轴 \(selectedAxisID) · ticks=\(axisSettings.explicitTicks ? "显式" : "自动") · format=\(axisSettings.formatted ? "单位" : "默认") · font=\(axisSettings.weight?.rawValue ?? "默认")")
                .font(.caption2).accessibilityIdentifier("specification.axisStatus")
            Form {
                Section("通用数据与样式") {
                    Toggle("包含缺测", isOn: $settings.missing)
                    Toggle("百分比堆叠", isOn: $settings.percent)
                    Toggle("显示图例", isOn: $settings.legend)
                    if kind == .line || kind == .combined {
                        Toggle("面积填充", isOn: $settings.area)
                        Picker("连线插值", selection: $settings.interpolation) {
                            ForEach(ChartInterpolation.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
                if kind == .line || kind == .combined {
                    Section("G1 堆叠边界 · 通用模型") {
                        Picker("堆叠面积边界", selection: $settings.boundary) {
                            Text("独立插值").tag(ChartStackedAreaBoundary.independent)
                            Text("沿基线").tag(ChartStackedAreaBoundary.followBaseline)
                            Text("正负分链").tag(ChartStackedAreaBoundary.diverging)
                        }.pickerStyle(.segmented).accessibilityIdentifier("specification.boundary")
                        Text(settings.boundary == .diverging
                             ? "v2：同组统一断段优先于逐系列跨空连接；纯折线也参与，正负共用绝对值分母。"
                             : "独立插值保留 v1 默认；沿基线显式使用 v2，并保留逐系列缺测策略。")
                            .font(.caption)
                    }
                }
                Section("值轴颜色分区 · 通用模型 v3") {
                    Picker("分区系列", selection: $selectedSeriesID) {
                        ForEach(0..<(kind == .combined ? 3 : 2), id: \.self) { index in
                            Text("source-\(index)").tag("source-\(index)")
                        }
                    }.accessibilityIdentifier("specification.zoneSeries")
                    Toggle("阈值分区（0 / 50）", isOn: zonesEnabled)
                        .accessibilityIdentifier("specification.zones")
                    if settings.valueColorZones[selectedSeriesID] != nil && selectedIsBar {
                        Picker("取色依据", selection: zoneSource) {
                            Text("原始值").tag(ChartZoneValueSource.rawValue)
                            Text("绘制值").tag(ChartZoneValueSource.drawValue)
                        }.pickerStyle(.segmented).accessibilityIdentifier("specification.zoneSource")
                    }
                    Text("示例：负值红、[0,50) 橙、≥50 绿。线/面积按绘制值，填充保持不变；百分比绘制值使用 %。仅当前系列生效。")
                        .font(.caption)
                }
                Section("轴展示 · 通用模型 v4") {
                    if kind != .bar {
                        Toggle("显示次值轴", isOn: .init(get: { settings.secondaryAxis }, set: {
                            settings.secondaryAxis = $0
                            if !$0 && selectedAxisID == "temperature" { selectedAxisID = "power" }
                        })).accessibilityIdentifier("specification.secondaryAxis")
                    }
                    Picker("当前轴", selection: $selectedAxisID) {
                        Text("power").tag("power")
                        Text("domain").tag("domain")
                        if settings.secondaryAxis && kind != .bar { Text("temperature").tag("temperature") }
                    }.pickerStyle(.menu).accessibilityIdentifier("specification.axisSelection")
                    Picker("系统字重", selection: axisBinding(\.weight)) {
                        Text("默认").tag(ChartFontWeight?.none)
                        ForEach(ChartFontWeight.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                    }.pickerStyle(.menu).accessibilityIdentifier("specification.axisWeight")
                    if selectedAxisID == "domain" {
                        Toggle("指定类目间隔", isOn: intervalEnabled).accessibilityIdentifier("specification.categoryInterval")
                        if settings.categoryLabelInterval != nil {
                            Stepper("类目候选间隔：\(settings.categoryLabelInterval ?? 2)",
                                    value: .init(get: { settings.categoryLabelInterval ?? 2 }, set: { settings.categoryLabelInterval = $0 }), in: 1...6)
                        }
                    } else {
                        Toggle("显式刻度示例", isOn: axisBinding(\.explicitTicks)).accessibilityIdentifier("specification.axisTicks")
                        Toggle("单位格式示例", isOn: axisBinding(\.formatted)).accessibilityIdentifier("specification.axisFormat")
                    }
                    Text("示例使用固定 locale；百分比显示 %，其他轴显示 W / °C。不改值域或系列单位。间隔只是标签候选，空间不足仍会避让；按轴 ID 独立保存。")
                        .font(.caption)
                }
                Section("目标能力检查") {
                    Toggle("真实数值 X（当前后端不支持）", isOn: $settings.numericDomain)
                        .accessibilityIdentifier("specification.numeric")
                    Toggle("反向值轴（当前后端不支持）", isOn: $settings.reversedAxis)
                    Text("不支持时显示字段路径和原因。关闭后恢复原数据；不会改画等距图。")
                        .font(.caption)
                }
                Section { Button("恢复通用模型默认值") { settings = .init(); selectedSeriesID = "source-0"; selectedAxisID = "power" }.accessibilityIdentifier("specification.reset") }
            }
        }
    }

    @ViewBuilder private func preview(_ configuration: HYMChartsSpecificationConfiguration) -> some View {
        switch configuration.kind {
        case .line: LineChart(model: configuration.model, theme: configuration.theme, playsAnimationOnAppear: false)
        case .column: ColumnChart(model: configuration.model, theme: configuration.theme, playsAnimationOnAppear: false)
        case .bar: BarChart(model: configuration.model, theme: configuration.theme, playsAnimationOnAppear: false)
        case .combined: CombinedChart(model: configuration.model, theme: configuration.theme, playsAnimationOnAppear: false)
        }
    }
}
