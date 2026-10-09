import SwiftUI

/// Demo 的闭包配置采用有名称的预设；业务仍可以直接传自定义闭包。
struct DemoAxisSettings {
    var manualRange = false
    var lower = 0.0
    var upper = 100.0
    var intervalOn = false
    var interval = 20.0
    var countOn = false
    var count = 6
    var positions = ""
    var suffix = ""
    var grid: Bool?
    var rotation: CGFloat = 0
    var style = CartesianAxisStyle()
    var categoryLabelInterval: Int?
    var parsedPositions: [Double]? {
        let values = positions.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }.filter(\.isFinite)
        return values.isEmpty ? nil : Array(Set(values)).sorted()
    }
    var normalizedRange: ClosedRange<Double> {
        let lo = min(lower, upper), hi = max(lower, upper)
        return lo...max(lo + 0.001, hi)
    }
    func axis(kind: CartesianAxisKind) -> CartesianAxisModel {
        CartesianAxisModel(kind: kind, min: manualRange ? normalizedRange.lowerBound : nil,
            max: manualRange ? normalizedRange.upperBound : nil,
            tickInterval: manualRange && intervalOn ? interval : nil, tickCount: countOn ? count : nil,
            tickPositions: parsedPositions,
            labelFormatter: suffix.isEmpty ? nil : { AxisRenderer.format($0) + suffix },
            showsGridlines: grid, tickLabelRotation: rotation, style: style, categoryLabelInterval: categoryLabelInterval)
    }
    static func categoryItems(_ b: Binding<Self>, isHorizontal: Bool) -> [ChartDemoPanel.Item] {
        [DemoProperty.enabled("显式类目标签步长", b.categoryLabelInterval, default: 2)]
        + (b.wrappedValue.categoryLabelInterval == nil ? [] : [DemoProperty.integer("类目标签步长", DemoProperty.optional(b.categoryLabelInterval, default: 2), 1...30)])
        + styleItems(b) + [DemoProperty.triState("类目网格覆盖", b.grid), .toggle(label: "固定类目范围", value: b.manualRange), DemoProperty.number("类目下界", b.lower, -0.5...3000), DemoProperty.number("类目上界", b.upper, 0.5...3000)] + (isHorizontal ? [] : [DemoProperty.number("类目标签旋转", b.rotation, -90...90)])
    }
    static func items(_ b: Binding<Self>) -> [ChartDemoPanel.Item] {
        styleItems(b) + [.toggle(label: "固定值域", value: b.manualRange),
         DemoProperty.number("下界", b.lower, -500...500), DemoProperty.number("上界", b.upper, -400...10000, step: 10),
         .toggle(label: "固定刻度间隔（需固定值域）", value: b.intervalOn), DemoProperty.number("刻度间隔", b.interval, 1...500),
         .toggle(label: "自定义刻度数", value: b.countOn), DemoProperty.integer("刻度数", b.count, 2...20),
         .textField(label: "刻度位置（逗号分隔，空为自动）", value: b.positions),
         .textField(label: "刻度后缀（格式化预设）", value: b.suffix),
         DemoProperty.triState("网格覆盖", b.grid)]
    }
    static func styleItems(_ b: Binding<Self>) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = [
            .toggle(label: "轴标签显示", value: b.style.showsLabels),
            .toggle(label: "轴线显示", value: b.style.showsLine)]
        items += DemoProperty.color("轴标签颜色", b.style.labelColor)
        items.append(DemoProperty.enabled("自定义轴标签字体", b.style.labelFont, default: UIFont.systemFont(ofSize: 14)))
        if b.wrappedValue.style.labelFont != nil {
            items += DemoProperty.font("轴标签", DemoProperty.optional(b.style.labelFont, default: UIFont.systemFont(ofSize: 14)))
        }
        items += DemoProperty.color("轴线颜色", b.style.lineColor)
        items.append(DemoProperty.enabled("自定义轴线宽度", b.style.lineWidth, default: CGFloat(1)))
        if b.wrappedValue.style.lineWidth != nil {
            items.append(DemoProperty.number("轴线宽度", DemoProperty.optional(b.style.lineWidth, default: CGFloat(1)), 0...8))
        }
        return items
    }

}

struct DemoSeriesSettings {
    var name: String
    var color: UIColor?
    var negativeColor: UIColor?
    var visible = true
    var showsInLegend = true
    var legendOrder = 0
    var axis = 0
    var dash = "跟随主题"
    var marker = "跟随主题"
    var connectNulls = false
    var gapMode = "跟随跨空值连线"
    var zoneMode = "关闭"
    var zoneThreshold = 0.0
    var lowerZoneColor: UIColor = .systemRed
    var upperZoneColor: UIColor = .systemGreen
    var zoneFill = false
    var columnZoneValueSource = "原值（聚合后）"
    var colorZones: CartesianColorZones? {
        guard zoneMode != "关闭" else { return nil }
        func fill(_ color: UIColor) -> [UIColor]? {
            zoneFill ? [color.withAlphaComponent(0.45), color.withAlphaComponent(0.08)] : nil
        }
        return .init(axis: zoneMode == "X 原始索引" ? .x : .y, zones: [
            .init(upperBound: zoneThreshold, color: lowerZoneColor, areaGradientColors: fill(lowerZoneColor)),
            .init(color: upperZoneColor, areaGradientColors: fill(upperZoneColor))
        ], columnValueSource: columnZoneValueSource == "累计绘制值" ? .drawValue : .rawValue)
    }
    var maximumMissingPoints = 11
    var maximumMissingDuration = 3300.0
    var gapPolicy: CartesianGapPolicy? {
        switch gapMode {
        case "全部断开": return .breakAll
        case "全部连接": return .connectAll
        case "按空点数量": return .autoGap(maximumMissingPoints: maximumMissingPoints)
        case "按缺测时长": return .autoGapDuration(maximumMissingDuration: maximumMissingDuration)
        default: return nil
        }
    }
    /// 三段连续缺测分别为 11、12、13 点；两端始终是原始有效点。
    static let autoGapSample: String = {
        var samples = ["20"]
        for (count, endpoint) in [(11, "50"), (12, "30"), (13, "70")] {
            samples.append(contentsOf: Array(repeating: "nan", count: count))
            samples.append(endpoint)
        }
        return samples.joined(separator: ",")
    }()
    var labels: Bool?
    var shadow: CartesianShadowStyle?
    var palette = false
    var paletteA = UIColor.systemBlue
    var paletteB = UIColor.systemOrange
    var aggregation = "平均"
    var unit = "kW"
    var legendTitle = ""
    var legendSymbol = "自动"
    var legendMarker: PointMarkerSymbol = .circle
    var legendColor: UIColor?
    var legendContent = "默认"
    var legendImageName = "bolt.fill"
    var legendHiddenImageName = "bolt.slash.fill"
    var legendBackground: UIColor?
    var legendCornerRadius: CGFloat = 8
    var dataText = ""
    var groupID = ""
    var groupName = ""
    var valueFormat: CartesianValueFormat?
    var kind: CartesianSeriesKind = .column
    var stackID = ""
    var participatesInStack = true
    var style = CartesianSeriesStyle()
    var reducer: CartesianAggregation? {
        switch aggregation {
        case "求和": return .sum
        case "平均": return .average
        case "最小": return .min
        case "最大": return .max
        case "末值": return .last
        case "自定义：极差": return .custom(name: "极差") { samples in
            guard let lo = samples.map(\.value).min(), let hi = samples.map(\.value).max() else { return nil }; return hi - lo
        }
        default: return nil
        }
    }
    var legendStyle: LegendItemStyle {
        let symbol: ChartLegendSymbol?
        switch legendSymbol {
        case "线": symbol = .line
        case "线和标记": symbol = .lineWithMarker(legendMarker)
        case "标记": symbol = .marker(legendMarker)
        case "矩形": symbol = .rectangle
        case "圆角矩形": symbol = .roundedRectangle
        default: symbol = nil
        }
        return LegendItemStyle(title: legendTitle.isEmpty ? nil : legendTitle, symbol: symbol, symbolColor: legendColor,
            image: legendContent == "图片" ? UIImage(systemName: legendImageName) : nil,
            hiddenImage: legendContent == "图片" ? UIImage(systemName: legendHiddenImageName) : nil,
            backgroundColor: legendBackground, cornerRadius: legendCornerRadius,
            symbolViewProvider: legendContent == "自定义状态" ? { visible in
                let label = UILabel()
                label.text = visible ? "开" : "关"
                label.textAlignment = .center; label.font = .systemFont(ofSize: 10, weight: .bold)
                label.textColor = .white; label.backgroundColor = visible ? .systemGreen : .systemGray
                label.layer.cornerRadius = 4; label.clipsToBounds = true
                return label
            } : nil)
    }
    static func items(_ b: Binding<Self>, kind: CartesianDemoKind) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = [.textField(label: "名称", value: b.name), .toggle(label: "显示系列", value: b.visible), .toggle(label: "加入图例", value: b.showsInLegend), DemoProperty.integer("图例排序", b.legendOrder, 0...10)]
        items += DemoProperty.color("系列颜色", b.color) + DemoProperty.color("负值颜色", b.negativeColor)
        if kind != .bar { items.append(DemoProperty.integer("值轴（0 主轴 / 1 次轴）", b.axis, 0...1)) }
        if kind == .line || kind == .combined {
            items += [.picker(label: "系列虚线", selection: b.dash, options: ["跟随主题"] + LineDashStyle.allCases.map(\.rawValue)), .picker(label: "系列点形状", selection: b.marker, options: ["跟随主题"] + PointMarkerSymbol.allCases.map(\.rawValue)), .toggle(label: "跨空值连线", value: b.connectNulls)]
        }
        if kind == .line || kind == .combined {
            items += [.picker(label: "缺测策略 autoGap", selection: b.gapMode,
                              options: ["跟随跨空值连线", "全部断开", "全部连接", "按空点数量", "按缺测时长"])]
            if b.wrappedValue.gapMode == "按空点数量" {
                items += [DemoProperty.integer("缺测点数上限（含等号）", b.maximumMissingPoints, 0...30)]
            } else if b.wrappedValue.gapMode == "按缺测时长" {
                items += [DemoProperty.number("缺测时长上限秒（需时间轴）", b.maximumMissingDuration, 0...86400, step: 300)]
            }
        }
        let isColumnSeries = kind == .column || kind == .bar || (kind == .combined && b.wrappedValue.kind.isColumn)
        // 内部保留既有 Y 选项值，显示文字按图形族适配，避免切换 kind 留下无效 Picker 值。
        let zoneMode = Binding<String>(
            get: { isColumnSeries && b.wrappedValue.zoneMode == "Y 绘制值" ? "Y 数值" : b.wrappedValue.zoneMode },
            set: { b.wrappedValue.zoneMode = $0 == "Y 数值" ? "Y 绘制值" : $0 })
        items += [.picker(label: "颜色分区 zones", selection: zoneMode,
                          options: ["关闭", "X 原始索引", isColumnSeries ? "Y 数值" : "Y 绘制值"])]
        if b.wrappedValue.zoneMode != "关闭" {
            items += [DemoProperty.number("分区阈值（等于归上段）", b.zoneThreshold, -100...3000, step: 0.5),
                      .color(label: isColumnSeries ? "阈值以下柱色" : "阈值以下线色", value: b.lowerZoneColor),
                      .color(label: isColumnSeries ? "阈值以上柱色" : "阈值以上线色", value: b.upperZoneColor)]
            if isColumnSeries {
                if b.wrappedValue.zoneMode != "X 原始索引" {
                    items += [.picker(label: "柱/条 Y 取色依据", selection: b.columnZoneValueSource,
                                      options: ["原值（聚合后）", "累计绘制值"])]
                }
            } else {
                items += [.toggle(label: "分区面积渐变", value: b.zoneFill)]
            }
        }
        if kind != .line {
            items += [.toggle(label: "逐柱配色", value: b.palette), .color(label: "调色板 A", value: b.paletteA), .color(label: "调色板 B", value: b.paletteB)]
        }
        if kind == .combined { items += [DemoProperty.choice("系列图形 kind", b.kind)] }
        items += [.textField(label: "堆叠组 stackID（空为默认组）", value: b.stackID),
                  .toggle(label: "参与堆叠 participatesInStack", value: b.participatesInStack)]
        if kind == .line || kind == .combined { items += DemoThemeFields.seriesStyleItems(b.style) }
        items += [DemoProperty.triState("数据标签", b.labels)] + DemoProperty.shadow("系列阴影", b.shadow)
        if kind == .column {
            items += [.picker(label: "聚合规则", selection: b.aggregation, options: ["不配置", "求和", "平均", "最小", "最大", "末值", "自定义：极差"])]
        }
        items += [.textField(label: "单位", value: b.unit),
            .textField(label: "业务组 ID（空为不分组）", value: b.groupID),
            .textField(label: "业务组名称（同 ID 使用首项名称）", value: b.groupName)]
        items += DemoThemeFields.valueFormatItems(b.valueFormat)
        items += [.textField(label: "图例标题覆盖（空为系列名）", value: b.legendTitle), .picker(label: "图例符号", selection: b.legendSymbol, options: ["自动", "线", "线和标记", "标记", "矩形", "圆角矩形"]), DemoProperty.choice("图例标记形状", b.legendMarker)]
        items += DemoProperty.color("图例符号颜色", b.legendColor)
        items += [.picker(label: "图例内容预设", selection: b.legendContent, options: ["默认", "图片", "自定义状态"]),
                  .textField(label: "图例图片 SF Symbol", value: b.legendImageName),
                  .textField(label: "隐藏时图例图片 SF Symbol", value: b.legendHiddenImageName)]
        items += DemoProperty.color("图例项背景", b.legendBackground)
        items += [DemoProperty.number("图例项圆角", b.legendCornerRadius, 0...20)]
        items += [.textField(label: "数据覆盖：逗号分隔，nan 缺测，空为生成数据", value: b.dataText)]
        return items
    }
}

enum CartesianDemoKind: String, CaseIterable {
    case line = "折线图", column = "柱状图", bar = "条形图", combined = "混合图"
}

struct DemoInteractionSettings {
    var zoom = true
    var maxZoom: CGFloat = 1000
    var minimumVisible = 2
    var zoomAxis: HYMChartZoomAxisMode = .x
    var deceleration = true
    var highlight = true
    var rubberBand = true
    var shared = false
    var crosshair = true
    var dualCrosshair = false
    var crosshairColor = UIColor.secondaryLabel
    var crosshairWidth: CGFloat = 0.75
    var crosshairDash: LineDashStyle = .solid
    var preserve = true
    var tooltip = true
    var header = "{key}"
    var suffix = ""
    var decimals = "自动"
    var popupMode = "内置"
    var tooltipGrouping = CartesianTooltipOptions()
    var excludedTooltipIDs = ""
    var tooltipPresentation = CartesianTooltipPresentation()
    var tooltipRowPreset = "默认"
    var tooltipSampleSelection = CartesianTooltipSampleSelection()
    var tooltipSeriesOffsets = ""
    var sampleSelection: CartesianTooltipSampleSelection {
        var result = tooltipSampleSelection
        for entry in tooltipSeriesOffsets.split(separator: ",") {
            let parts = entry.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, let offset = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { continue }
            let id = parts[0].trimmingCharacters(in: .whitespaces)
            if !id.isEmpty { result.offsetsBySeriesID[id] = offset }
        }
        return result
    }
    var presentation: CartesianTooltipPresentation {
        var result = tooltipPresentation
        result.rowStyleProvider = DemoTooltipRowRules.provider(tooltipRowPreset)
        return result
    }
    var textOptions: HYMChartTooltipTextOptions {
        var grouping = tooltipGrouping
        grouping.excludedSeriesIDs = Set(excludedTooltipIDs.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })
        return .init(header: header.isEmpty ? nil : header, valueSuffix: suffix.isEmpty ? nil : suffix,
                     valueDecimals: Int(decimals), cartesian: grouping)
    }
    static func items(_ b: Binding<Self>) -> [ChartDemoPanel.Item] {
        [.toggle(label: "缩放", value: b.zoom), DemoProperty.number("最大缩放倍率", b.maxZoom, 1...3000, step: 1), DemoProperty.integer("最小可见类目", b.minimumVisible, 2...30),
         .picker(label: "缩放轴", selection: Binding(get: { b.wrappedValue.zoomAxis.rawValue }, set: { b.wrappedValue.zoomAxis = HYMChartZoomAxisMode(rawValue: $0) ?? .x }), options: ["x", "y", "xy"]),
         .toggle(label: "惯性", value: b.deceleration), .toggle(label: "拖动选中", value: b.highlight), .toggle(label: "边界回弹", value: b.rubberBand), .toggle(label: "共享提示", value: b.shared),
         .toggle(label: "十字准线", value: b.crosshair), .toggle(label: "双向准线", value: b.dualCrosshair), .color(label: "准线颜色", value: b.crosshairColor), DemoProperty.number("准线宽度", b.crosshairWidth, 0.5...5), DemoProperty.choice("准线样式", b.crosshairDash),
         .toggle(label: "属性更新时保留视口", value: b.preserve), .toggle(label: "容器弹窗", value: b.tooltip),
         .picker(label: "弹窗回调预设", selection: b.popupMode, options: ["内置", "自定义内容", "位置回调"]),
         .picker(label: "提示内容布局", selection: Binding(get: { b.wrappedValue.tooltipPresentation.layout.rawValue }, set: { b.wrappedValue.tooltipPresentation.layout = CartesianTooltipLayout(rawValue: $0) ?? .text }), options: CartesianTooltipLayout.allCases.map(\.rawValue)),
         .picker(label: "提示逐点规则预设", selection: b.tooltipRowPreset, options: DemoTooltipRowRules.names),
         DemoProperty.number("提示图标尺寸", b.tooltipPresentation.iconSize, 0...32),
         DemoProperty.number("提示行间距", b.tooltipPresentation.rowSpacing, 0...16),
         DemoProperty.number("提示列间距", b.tooltipPresentation.columnSpacing, 0...24),
         DemoProperty.number("提示组间距", b.tooltipPresentation.sectionSpacing, 0...24),
         .toggle(label: "提示组分隔线", value: b.tooltipPresentation.showsSectionSeparators),
         DemoProperty.integer("提示取值索引偏移", b.tooltipSampleSelection.offset, -24...24),
         .textField(label: "提示逐系列偏移（ID:偏移，逗号分隔）", value: b.tooltipSeriesOffsets),
         .picker(label: "提示越界策略", selection: Binding(get: { b.wrappedValue.tooltipSampleSelection.boundaryPolicy.rawValue }, set: { b.wrappedValue.tooltipSampleSelection.boundaryPolicy = CartesianTooltipSampleBoundaryPolicy(rawValue: $0) ?? .omit }), options: CartesianTooltipSampleBoundaryPolicy.allCases.map(\.rawValue)),
         .toggle(label: "提示显示取值来源", value: b.tooltipSampleSelection.showsSourceLabel),
         .textField(label: "提示取值来源模板", value: b.tooltipSampleSelection.sourceLabelTemplate),
         .toggle(label: "按业务组显示提示", value: b.tooltipGrouping.groupsByBusinessID),
         .toggle(label: "显示组小计", value: b.tooltipGrouping.showsGroupSubtotals),
         .toggle(label: "提示隐藏零值", value: b.tooltipGrouping.hidesZeroValues),
         .textField(label: "提示排除系列 ID（逗号分隔）", value: b.excludedTooltipIDs),
         .textField(label: "未分组标题", value: b.tooltipGrouping.ungroupedTitle),
         .textField(label: "小计标题", value: b.tooltipGrouping.subtotalTitle),
         .textField(label: "表头模板", value: b.header), .textField(label: "数值后缀", value: b.suffix), .picker(label: "小数位", selection: b.decimals, options: ["自动", "0", "1", "2", "3"])]
    }
}
