import UIKit

/// 原生适配结果；源描述保留业务身份/元数据，渲染用的 NaN 占位仅存在于 model 中。
/// 配置和 UIKit theme 须在主线程使用，不保证跨线程安全。
public struct HYMChartsSpecificationConfiguration {
    public let kind: HYMCartesianChartKind
    public let model: CartesianChartModel
    public let theme: CartesianChartTheme
    public let source: ChartSpecification
    private let sampleLookup: [String: [Int: ChartSample]]

    init(kind: HYMCartesianChartKind, model: CartesianChartModel, theme: CartesianChartTheme,
         source: ChartSpecification, sampleLookup: [String: [Int: ChartSample]]) {
        self.kind = kind; self.model = model; self.theme = theme; self.source = source
        self.sampleLookup = sampleLookup
    }

    /// 将原生命中的 seriesID/categoryIndex 查回原始样本；隐式空位/越界返回 nil。
    /// 显式缺测仍有样本身份；调用方不能把累计 drawValue 当成该样本 value。
    public func sourceSample(seriesID: String, categoryIndex: Int) -> ChartSample? {
        sampleLookup[seriesID]?[categoryIndex]
    }
}

/// 通用描述 → HYMCharts。只在此层引用 UIKit、Cartesian 和引擎类型。
/// 首版支持类目域、至多双值轴；数值/时间域和反向轴返回能力错误，不转成假等距图。
public struct HYMChartsSpecificationAdapter: ChartAdapter {
    public let backendIdentifier = "hymcharts"
    /// 无共享状态。makeConfiguration 含 UIKit 样式构造，应在主线程调用。
    public init() {}

    /// 逐字段诊断；隐藏系列也校验，保证恢复显示后不会暴露静默丢失的配置。
    public func diagnostics(for specification: ChartSpecification) -> [ChartSpecificationIssue] {
        var issues = specification.validationIssues()
        func unsupported(_ path: String, _ message: String) {
            issues.append(.init(code: .unsupportedCapability, path: path, message: message))
        }
        if case .categories = specification.domain {} else {
            unsupported("domain", "HYMCharts 当前只支持类目索引；真实数值/时间坐标尚未接入")
        }
        if specification.valueAxes.count > 2 { unsupported("valueAxes", "HYMCharts 最多支持两个值轴") }
        if specification.valueAxes.count == 2,
           !specification.valueAxes[0].appearance.showsGridlines,
           specification.valueAxes[1].appearance.showsGridlines {
            unsupported("valueAxes[1].appearance.showsGridlines", "当前原生网格不能单独开启次轴而关闭主轴网格")
        }
        if specification.orientation == .horizontal {
            if specification.valueAxes.count > 1 { unsupported("valueAxes", "水平柱图当前只支持一个值轴") }
            if specification.series.contains(where: { $0.mark != .bar }) {
                unsupported("orientation", "当前水平图只支持 bar 图元")
            }
        }
        for (index, axis) in specification.valueAxes.enumerated() where axis.isReversed {
            unsupported("valueAxes[\(index)].isReversed", "当前原生值轴不支持反向")
        }
        for (index, row) in specification.series.enumerated()
            where row.mark != .bar && row.appearance.valueColorZones?.valueSource == .rawValue {
            unsupported("series[\(index)].appearance.valueColorZones.valueSource",
                        "HYM 线/面积值轴分区仅支持 drawValue；不能把原始贡献当作累计边界")
        }
        for (index, row) in specification.series.enumerated() where row.mark == .bar {
            let path = "series[\(index)]"
            if row.interpolation != .linear { unsupported(path + ".interpolation", "柱图不能应用连线插值") }
            if row.missingValues != .breakPath { unsupported(path + ".missingValues", "柱图不支持跨缺测连线") }
            if row.appearance.lineWidth != nil || row.appearance.strokePattern != .solid {
                unsupported(path + ".appearance", "柱图不能应用逐系列折线线宽/虚线；柱边框需要独立配置")
            }
            if let marker = row.appearance.marker, marker != .none {
                unsupported(path + ".appearance.marker", "柱图不绘制点 marker")
            }
            if row.appearance.markerRadius != nil { unsupported(path + ".appearance.markerRadius", "柱图不绘制点 marker") }
        }
        return issues
    }

    /// 检查后按 category ID 对齐稀疏样本；不重写业务数据、不改符号、不创建业务 ID。
    /// 不支持的输入抛出 ChartSpecificationError，调用方应保留上一次有效配置。
    public func makeConfiguration(from specification: ChartSpecification) throws -> HYMChartsSpecificationConfiguration {
        let issues = diagnostics(for: specification)
        guard issues.isEmpty else { throw ChartSpecificationError(issues: issues, backendIdentifier: backendIdentifier) }
        guard case .categories(let categories) = specification.domain else {
            throw ChartSpecificationError(issues: [.init(code: .unsupportedCapability, path: "domain", message: "需要类目域")], backendIdentifier: backendIdentifier)
        }
        let positions = Dictionary(uniqueKeysWithValues: categories.enumerated().map { ($0.element.id, $0.offset) })
        let axes = Dictionary(uniqueKeysWithValues: specification.valueAxes.enumerated().map { ($0.element.id, $0.offset) })
        var lookup: [String: [Int: ChartSample]] = [:]
        let rows = specification.series.map { row -> CartesianSeriesElement in
            var data = Array(repeating: Double.nan, count: categories.count)
            var samples: [Int: ChartSample] = [:]
            for sample in row.samples {
                if case .category(let id) = sample.coordinate, let index = positions[id] {
                    data[index] = sample.value ?? .nan
                    samples[index] = sample
                }
            }
            lookup[row.id] = samples
            var style = CartesianSeriesStyle()
            style.lineConnectionStyle = connection(row.interpolation)
            style.lineWidth = row.appearance.lineWidth.map { CGFloat($0) }
            style.pointRadius = row.appearance.markerRadius.map { CGFloat($0) }
            if let marker = row.appearance.marker { style.showsPoints = marker != .none }
            style.showsArea = row.mark == .area
            let colorZones = row.appearance.valueColorZones.map { config in
                CartesianColorZones(axis: .y, zones: config.zones.map {
                    CartesianColorZone(upperBound: $0.upperBound, color: $0.color.map(uiColor))
                }, columnValueSource: config.valueSource == .rawValue ? .rawValue : .drawValue)
            }
            switch row.appearance.areaFill {
            case .solid(let color): style.areaGradientColors = [uiColor(color), uiColor(color)]
            case .verticalGradient(let top, let bottom): style.areaGradientColors = [uiColor(top), uiColor(bottom)]
            case nil: break
            }
            return CartesianSeriesElement(name: row.name, data: data,
                color: row.appearance.color.map(uiColor), negativeColor: row.appearance.negativeColor.map(uiColor),
                yAxisIndex: axes[row.valueAxisID]!, lineDashStyle: dash(row.appearance.strokePattern),
                pointSymbol: row.appearance.marker.flatMap(marker), dataLabelsEnabled: row.appearance.showsValueLabels,
                id: row.id, isVisible: row.isVisible, showsInLegend: row.showsInLegend,
                unit: row.unit, groupID: row.groupID, valueFormat: valueFormat(row.valuePresentation),
                kind: row.mark == .bar ? .column : row.mark == .area ? .area : .line,
                stackID: row.stackID, participatesInStack: row.stackID != nil, style: style,
                gapPolicy: gap(row.missingValues), colorZones: colorZones)
        }
        let stacking: StackConfig?
        switch specification.stacking {
        case .none: stacking = nil
        case .sum: stacking = .normal
        case .percentOfAbsoluteTotal: stacking = .percent
        case .percentOfFixedTotal(let total): stacking = .percentFixed(max: total)
        }
        let kind: HYMCartesianChartKind
        let hasBars = rows.contains { $0.kind == .column }
        if specification.orientation == .horizontal { kind = .bar }
        else if hasBars && rows.contains(where: { $0.kind != .column }) { kind = .combined }
        else { kind = hasBars ? .column : .line }
        var model = CartesianChartModel(title: specification.title, series: rows,
            xAxis: .init(kind: .category(labels: categories.map(\.label)),
                         showsGridlines: specification.domainAppearance.showsGridlines,
                         style: axisStyle(specification.domainAppearance),
                         categoryLabelInterval: specification.categoryLabelInterval),
            yAxis: axis(specification.valueAxes[0]),
            secondaryYAxis: specification.valueAxes.count == 2 ? axis(specification.valueAxes[1]) : nil,
            stacking: stacking, groups: specification.groups.map { .init(id: $0.id, name: $0.name) })
        // Stable ID -> native slot only at this boundary. Invisible annotations remain in source.
        model.plotLines = specification.plotLines.filter(\.isVisible).map { line in
            var result = CartesianPlotLine(value: line.value, yAxisIndex: axes[line.valueAxisID]!,
                dashStyle: dash(line.strokePattern), label: line.label, labelStyle: annotationStyle(line.labelStyle))
            if let color = line.color { result.color = uiColor(color) }
            if let width = line.lineWidth { result.lineWidth = CGFloat(width) }
            return result
        }
        model.plotBands = specification.plotBands.filter(\.isVisible).map { band in
            var result = CartesianPlotBand(from: band.from, to: band.to, yAxisIndex: axes[band.valueAxisID]!,
                label: band.label, labelStyle: annotationStyle(band.labelStyle))
            if let color = band.color { result.color = uiColor(color) }
            return result
        }
        var theme = CartesianChartTheme()
        switch specification.stackedAreaBoundary {
        case .independent: theme.stackedAreaBoundaryMode = .independent
        case .followBaseline: theme.stackedAreaBoundaryMode = .followBaseline
        case .diverging: theme.stackedAreaBoundaryMode = .diverging
        }
        theme.legend.isEnabled = specification.showsLegend
        if let legend = specification.legend { theme.legend = legend.nativeConfiguration(isEnabled: specification.showsLegend) }
        if let tooltip = specification.tooltip { theme.showsTooltipOnHit = tooltip.isEnabled }
        // 主值轴/类目网格由屏幕方向主题控制；只设置 AxisModel.showsGridlines 不会生效。
        let valueGrid = specification.valueAxes[0].appearance.showsGridlines
        let domainGrid = specification.domainAppearance.showsGridlines
        theme.showsHorizontalGridlines = specification.orientation == .horizontal ? domainGrid : valueGrid
        theme.showsVerticalGridlines = specification.orientation == .horizontal ? valueGrid : domainGrid
        return .init(kind: kind, model: model, theme: theme, source: specification, sampleLookup: lookup)
    }

    private func uiColor(_ color: ChartRGBA) -> UIColor {
        UIColor(red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: CGFloat(color.alpha))
    }
    private func axisFont(_ appearance: ChartAxisAppearance) -> UIFont? {
        guard appearance.labelFontSize != nil || appearance.labelFontWeight != nil else { return nil }
        let weight: UIFont.Weight
        switch appearance.labelFontWeight ?? .regular {
        case .ultraLight: weight = .ultraLight
        case .thin: weight = .thin
        case .light: weight = .light
        case .regular: weight = .regular
        case .medium: weight = .medium
        case .semibold: weight = .semibold
        case .bold: weight = .bold
        case .heavy: weight = .heavy
        case .black: weight = .black
        }
        let size = appearance.labelFontSize.map { CGFloat($0) } ?? CartesianChartTheme().tickLabelFont.pointSize
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
    private func annotationStyle(_ style: ChartAnnotationLabelStyle) -> CartesianAnnotationLabelStyle {
        var font: UIFont?
        if style.fontSize != nil || style.fontWeight != nil {
            var appearance = ChartAxisAppearance()
            appearance.labelFontSize = style.fontSize; appearance.labelFontWeight = style.fontWeight ?? .medium
            font = axisFont(appearance)
        }
        let horizontal: CartesianAnnotationAlignment
        switch style.alignment {
        case .automatic: horizontal = .automatic
        case .leading: horizontal = .leading
        case .center: horizontal = .center
        case .trailing: horizontal = .trailing
        }
        let vertical: CartesianAnnotationVerticalAlignment
        switch style.verticalAlignment {
        case .automatic: vertical = .automatic
        case .top: vertical = .top
        case .center: vertical = .center
        case .bottom: vertical = .bottom
        }
        return .init(color: style.color.map(uiColor), font: font, backgroundColor: style.backgroundColor.map(uiColor),
                     alignment: horizontal, verticalAlignment: vertical,
                     offset: CGSize(width: style.offsetX, height: style.offsetY), bounds: style.bounds == .clamp ? .clamp : .hide)
    }

    private func axisStyle(_ appearance: ChartAxisAppearance) -> CartesianAxisStyle {
        .init(labelColor: appearance.labelColor.map(uiColor),
              labelFont: axisFont(appearance),
              lineColor: appearance.lineColor.map(uiColor), lineWidth: appearance.lineWidth.map { CGFloat($0) },
              showsLabels: appearance.showsLabels, showsLine: appearance.showsLine)
    }
    private func axis(_ axis: ChartAxisSpecification) -> CartesianAxisModel {
        let formatter: ((Double) -> String)? = axis.labelFormat.map { format in
            let number = valueFormat(format.number)
            return { number.string(from: $0, unit: format.unit) }
        }
        return .init(kind: .value, min: axis.minimum, max: axis.maximum,
                     tickPositions: axis.tickPositions, labelFormatter: formatter,
                     showsGridlines: axis.appearance.showsGridlines, style: axisStyle(axis.appearance))
    }
    private func connection(_ interpolation: ChartInterpolation) -> LineConnectionStyle {
        switch interpolation {
        case .linear: return .straight
        case .monotone: return .smooth
        case .stepBefore: return .stepBefore
        case .stepAfter: return .stepAfter
        case .stepCenter: return .stepCenter
        }
    }
    private func dash(_ pattern: ChartStrokePattern) -> LineDashStyle {
        switch pattern { case .solid: return .solid; case .dashed: return .dash; case .dotted: return .dot }
    }
    private func marker(_ shape: ChartMarkerShape) -> PointMarkerSymbol? {
        switch shape {
        case .none: return nil
        case .circle: return .circle
        case .square: return .square
        case .diamond: return .diamond
        case .triangle: return .triangle
        }
    }
    private func gap(_ policy: ChartMissingValuePolicy) -> CartesianGapPolicy {
        switch policy {
        case .breakPath: return .breakAll
        case .connect: return .connectAll
        case .connectUpTo(let count): return .autoGap(maximumMissingPoints: count)
        }
    }
    private func valueFormat(_ presentation: ChartValuePresentation) -> CartesianValueFormat {
        var result = CartesianValueFormat()
        result.scale = presentation.scale == .engineering ? .engineering : .none
        result.rounding = presentation.rounding == .towardZero ? .towardZero : .nearest
        result.maximumFractionDigits = presentation.maximumFractionDigits
        result.showsAbsoluteValue = presentation.showsAbsoluteValue
        result.currencySymbol = presentation.currencySymbol
        result.localeIdentifier = presentation.localeIdentifier
        result.usesGroupingSeparator = presentation.usesGroupingSeparator
        return result
    }
}
