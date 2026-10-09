import SwiftUI

/// 可编辑基础字段的集中登记；复杂枚举/闭包在各专属面板选择预设。
enum DemoThemeFields {
    static func valueFormatItems(_ v: Binding<CartesianValueFormat?>) -> [ChartDemoPanel.Item] {
        var items = [DemoProperty.enabled("每系列数值格式（覆盖全局模板）", v, default: CartesianValueFormat())]
        if v.wrappedValue != nil {
            let f = DemoProperty.optional(v, default: CartesianValueFormat())
            items += [DemoProperty.choice("进位 none/engineering", f.scale),
                DemoProperty.choice("舍入 nearest/towardZero", f.rounding),
                DemoProperty.integer("最多小数位", f.maximumFractionDigits, 0...12),
                .toggle(label: "仅展示绝对值", value: f.showsAbsoluteValue),
                .toggle(label: "千位分隔符", value: f.usesGroupingSeparator),
                .textField(label: "货币符号（空为关闭）", value: f.currencySymbol),
                .textField(label: "Locale（空为系统，例如 en_US/de_DE）", value: Binding(get: { f.wrappedValue.localeIdentifier ?? "" }, set: { f.wrappedValue.localeIdentifier = $0.isEmpty ? nil : $0 }))]
        }
        return items
    }

    static func annotationItems(_ prefix: String, _ v: Binding<CartesianAnnotationLabelStyle>) -> [ChartDemoPanel.Item] {
        var items = DemoProperty.color(prefix + "文字颜色", v.color)
        items += DemoProperty.color(prefix + "文字背景", v.backgroundColor)
        items += [DemoProperty.enabled(prefix + "自定义字体", v.font, default: UIFont.systemFont(ofSize: 12))]
        if v.wrappedValue.font != nil {
            items += DemoProperty.font(prefix + "字体", DemoProperty.optional(v.font, default: UIFont.systemFont(ofSize: 12)))
        }
        items += [DemoProperty.choice(prefix + "水平对齐", v.alignment),
                  DemoProperty.choice(prefix + "垂直对齐", v.verticalAlignment),
                  DemoProperty.number(prefix + "偏移 X", v.offset.width, -100...100),
                  DemoProperty.number(prefix + "偏移 Y", v.offset.height, -100...100),
                  DemoProperty.choice(prefix + "越界策略", v.bounds),
                  .button(label: prefix + "恢复默认文字样式") { v.wrappedValue = .init() }]
        return items
    }

    static func lineSamplingItems(_ v: Binding<LineChartSampling?>) -> [ChartDemoPanel.Item] {
        var items = [DemoProperty.enabled("启用 Min/Max 降采样（非堆叠直线）", v, default: LineChartSampling())]
        if v.wrappedValue != nil {
            let c = DemoProperty.optional(v, default: LineChartSampling())
            items.append(DemoProperty.enabled("按目标点数采样 targetPointCount", c.targetPointCount, default: 200))
            if c.wrappedValue.targetPointCount != nil {
                items.append(.integerInput(label: "每系列目标绘制点数 targetPointCount",
                    value: DemoProperty.optional(c.targetPointCount, default: 200), range: 2...3000))
            }
            items += [DemoProperty.number("分组宽度 bucketWidth（pt）", c.bucketWidth, 1...12, step: 0.5),
                DemoProperty.integer("启动门槛 minimumVisiblePoints（非保留点数）", c.minimumVisiblePoints, 2...3000),
                .toggle(label: "密集时隐藏标记 hidesDenseMarkers", value: c.hidesDenseMarkers),
                .toggle(label: "密集时隐藏标签 hidesDenseDataLabels", value: c.hidesDenseDataLabels)]
        }
        return items
    }

    static func items(_ v: Binding<CartesianChartTheme>) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = []
        items += [.toggle(label: "复用图层与标签 reusesRenderingObjects", value: v.reusesRenderingObjects)]
        items += DemoProperty.color("backgroundColor", v.backgroundColor)
        items += [DemoProperty.number("backgroundCornerRadius", v.backgroundCornerRadius, 0...40)]
        items += DemoProperty.insets("contentInset", v.contentInset)
        items += [.color(label: "titleColor", value: v.titleColor)]
        items += DemoProperty.font("titleFont", v.titleFont)
        items += [.toggle(label: "showsHorizontalGridlines", value: v.showsHorizontalGridlines)]
        items += [.toggle(label: "showsVerticalGridlines", value: v.showsVerticalGridlines)]
        items += [.color(label: "gridColor", value: v.gridColor)]
        items += [DemoProperty.number("gridLineWidth", v.gridLineWidth, 0...40)]
        items += [.color(label: "axisLineColor", value: v.axisLineColor)]
        items += [DemoProperty.number("axisLineWidth", v.axisLineWidth, 0...40)]
        items += [.color(label: "tickLabelColor", value: v.tickLabelColor)]
        items += DemoProperty.font("tickLabelFont", v.tickLabelFont)
        items += [DemoProperty.number("axisLabelGap", v.axisLabelGap, 0...40)]
        items += [.color(label: "seriesColor", value: v.seriesColor)]
        items += [DemoProperty.number("lineWidth", v.lineWidth, 0...40)]
        items += [DemoProperty.choice("lineConnectionStyle", v.lineConnectionStyle)]
        items += [DemoProperty.choice("lineDashStyle", v.lineDashStyle)]
        items += [.toggle(label: "showsPoints", value: v.showsPoints)]
        items += [DemoProperty.number("pointRadius", v.pointRadius, 0...40)]
        items += DemoProperty.color("pointColor", v.pointColor)
        items += [DemoProperty.choice("pointSymbol", v.pointSymbol)]
        items += [DemoProperty.number("pointHoleRadius", v.pointHoleRadius, 0...40)]
        items += [.color(label: "pointHoleColor", value: v.pointHoleColor)]
        items += [.toggle(label: "showsArea", value: v.showsArea)]
        items += [DemoProperty.choice("stackedAreaBoundaryMode 堆叠面积边界", v.stackedAreaBoundaryMode)]
        items += [.toggle(label: "showsDataLabels", value: v.showsDataLabels)]
        items += [DemoProperty.number("dataLabelFontSize", v.dataLabelFontSize, 6...40)]
        items += DemoProperty.color("dataLabelColor", v.dataLabelColor)
        items += DemoProperty.color("dataLabelBackgroundColor", v.dataLabelBackgroundColor)
        items += [.toggle(label: "dataLabelAvoidsOverlap 标签避让", value: v.dataLabelAvoidsOverlap)]
        items += [DemoProperty.choice("dataLabelPosition", v.dataLabelPosition)]
        items += [DemoProperty.integer("dataLabelMaxMarkCount", v.dataLabelMaxMarkCount, 0...1000)]
        items += [.toggle(label: "showsEntranceAnimation", value: v.showsEntranceAnimation)]
        items += [.toggle(label: "showsTooltipOnHit", value: v.showsTooltipOnHit)]
        items += [.toggle(label: "selection 主体选中高亮", value: v.selection.isEnabled),
                  .color(label: "selection 高亮颜色", value: v.selection.color),
                  DemoProperty.number("selection 边框宽度", v.selection.lineWidth, 0...20),
                  DemoProperty.number("selection 填充透明度", v.selection.fillOpacity, 0...1, step: 0.05),
                  DemoProperty.number("selection 点环半径", v.selection.pointRadius, 1...30)]
        items += [DemoProperty.enabled("固定间距 columnSpacing（pt）", v.columnSpacing, default: CartesianColumnSpacing(columnWidth: 12))]
        if v.columnSpacing.wrappedValue != nil {
            let spacing = DemoProperty.optional(v.columnSpacing, default: CartesianColumnSpacing(columnWidth: 12))
            items += [DemoProperty.enabled("固定柱宽 columnSpacing.columnWidth（pt）", spacing.columnWidth, default: CGFloat(12))]
            if spacing.columnWidth.wrappedValue != nil {
                items += [DemoProperty.number("柱宽 columnSpacing.columnWidth（pt）", DemoProperty.optional(spacing.columnWidth, default: 12), 1...60)]
            }
            items += [DemoProperty.number("同组柱间距 columnSpacing.inner（pt）", spacing.inner, 0...40)]
            items += [DemoProperty.number("两组间距 columnSpacing.group（pt）", spacing.group, 0...80)]
        } else {
            items += [DemoProperty.number("columnWidthRatio", v.columnWidthRatio, 0.1...1, step: 0.05)]
            items += [DemoProperty.number("columnGroupSpacingRatio", v.columnGroupSpacingRatio, 0...0.5, step: 0.05)]
            items += [DemoProperty.enabled("自定义 columnInnerSpacingRatio", v.columnInnerSpacingRatio, default: 0.5)]
            if v.columnInnerSpacingRatio.wrappedValue != nil { items.append(DemoProperty.number("columnInnerSpacingRatio", DemoProperty.optional(v.columnInnerSpacingRatio, default: 0.5), 0...0.5, step: 0.05)) }
        }
        items += [DemoProperty.number("columnMinPointLength", v.columnMinPointLength, 0...40)]
        items += [DemoProperty.number("columnCornerRadius", v.columnCornerRadius, 0...40)]
        items += DemoProperty.color("columnBorderColor", v.columnBorderColor)
        items += [DemoProperty.number("columnBorderWidth", v.columnBorderWidth, 0...40)]
        items += DemoProperty.color("stackSeparatorColor", v.stackSeparatorColor)
        items += [DemoProperty.number("stackSeparatorWidth", v.stackSeparatorWidth, 0...40)]
        items += [.toggle(label: "showsStackTotalLabels", value: v.showsStackTotalLabels)]
        items += DemoProperty.shadow("seriesShadow", v.seriesShadow)
        items += [.toggle(label: "showsColumnEntranceAnimation", value: v.showsColumnEntranceAnimation)]
        return items
    }
    static func items(_ v: Binding<RadarChartTheme>) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = []
        items += [.color(label: "backgroundGradientStart", value: v.backgroundGradientStart)]
        items += [.color(label: "backgroundGradientEnd", value: v.backgroundGradientEnd)]
        items += [.color(label: "gridColor", value: v.gridColor)]
        items += [.color(label: "axisColor", value: v.axisColor)]
        items += [.color(label: "dataFillColor", value: v.dataFillColor)]
        items += [.color(label: "dataStrokeColor", value: v.dataStrokeColor)]
        items += [.color(label: "vertexDotColor", value: v.vertexDotColor)]
        items += [.color(label: "vertexDotRingColor", value: v.vertexDotRingColor)]
        items += [.color(label: "labelColor", value: v.labelColor)]
        items += DemoProperty.font("labelFont", v.labelFont)
        items += [.color(label: "scoreColor", value: v.scoreColor)]
        items += DemoProperty.font("scoreFont", v.scoreFont)
        items += [DemoProperty.integer("gridRingCount", v.gridRingCount, 1...12)]
        items += [DemoProperty.number("cardCornerRadius", v.cardCornerRadius, 0...40)]
        items += [DemoProperty.number("dataLineWidth", v.dataLineWidth, 0...40)]
        items += [DemoProperty.number("labelOuterPadding", v.labelOuterPadding, 0...40)]
        items += [DemoProperty.number("labelMaxLineLength", v.labelMaxLineLength, 0...200)]
        items += [DemoProperty.number("vertexDotRadius", v.vertexDotRadius, 0...40)]
        items += [.toggle(label: "showsGridLines", value: v.showsGridLines)]
        items += [.toggle(label: "showsAxes", value: v.showsAxes)]
        items += [.toggle(label: "showsData", value: v.showsData)]
        items += [.toggle(label: "showsBackground", value: v.showsBackground)]
        items += [.toggle(label: "showsVertexDots", value: v.showsVertexDots)]
        items += [.toggle(label: "showsLabelDots", value: v.showsLabelDots)]
        items += [.color(label: "labelDotColor", value: v.labelDotColor)]
        items += [DemoProperty.number("labelDotRadius", v.labelDotRadius, 0...40)]
        items += [.toggle(label: "showsOuterRing", value: v.showsOuterRing)]
        items += [.color(label: "outerRingColor", value: v.outerRingColor)]
        items += [DemoProperty.number("outerRingLineWidth", v.outerRingLineWidth, 0...40)]
        items += DemoProperty.lineStyle("outerRingLineStyle", v.outerRingLineStyle)
        items += DemoProperty.lineStyle("gridLineStyle", v.gridLineStyle)
        items += DemoProperty.lineStyle("axisLineStyle", v.axisLineStyle)
        items += [.toggle(label: "showsDecorativeRing", value: v.showsDecorativeRing)]
        items += [.color(label: "decorativeRingColor", value: v.decorativeRingColor)]
        items += [DemoProperty.number("decorativeRingLineWidth", v.decorativeRingLineWidth, 0...40)]
        items += DemoProperty.lineStyle("decorativeRingLineStyle", v.decorativeRingLineStyle)
        items += [DemoProperty.number("decorativeRingInset", v.decorativeRingInset, 0...40)]
        items += [DemoProperty.integer("decorativeRingSides", v.decorativeRingSides, -1...12)]
        items += DemoProperty.color("decorativeRingFillColor", v.decorativeRingFillColor)
        items += [DemoProperty.enabled("自定义 decorativeRingRadiusRatio", v.decorativeRingRadiusRatio, default: 0.5)]
        if v.decorativeRingRadiusRatio.wrappedValue != nil { items.append(DemoProperty.number("decorativeRingRadiusRatio", DemoProperty.optional(v.decorativeRingRadiusRatio, default: 0.5), 0...1, step: 0.05)) }
        items += [DemoProperty.number("selectionScale", v.selectionScale, 1...3)]
        items += DemoProperty.color("selectionStrokeColor", v.selectionStrokeColor)
        items += [DemoProperty.number("selectionStrokeWidth", v.selectionStrokeWidth, 0...40)]
        items += DemoProperty.color("selectionColor", v.selectionColor)
        items += [DemoProperty.number("selectionHitPadding", v.selectionHitPadding, 0...40)]
        items += [.toggle(label: "dataVertexTappable", value: v.dataVertexTappable)]
        items += [.toggle(label: "labelVertexTappable", value: v.labelVertexTappable)]
        return items
    }
    static func items(_ v: Binding<HeatmapChartTheme>) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = []
        items += [.color(label: "emptyColor", value: v.emptyColor)]
        items += [.color(label: "baseColor", value: v.baseColor)]
        items += [DemoProperty.number("cellCornerRadius", v.cellCornerRadius, 0...40)]
        items += [DemoProperty.number("rowSpacing", v.rowSpacing, 0...40)]
        items += [DemoProperty.number("columnSpacing", v.columnSpacing, 0...40)]
        items += [DemoProperty.number("contentInset", v.contentInset, 0...40)]
        items += DemoProperty.color("backgroundColor", v.backgroundColor)
        items += [DemoProperty.number("backgroundCornerRadius", v.backgroundCornerRadius, 0...40)]
        items += [.color(label: "labelColor", value: v.labelColor)]
        items += DemoProperty.font("labelFont", v.labelFont)
        items += [DemoProperty.number("labelGap", v.labelGap, 0...40)]
        items += [.toggle(label: "showsRowLabels", value: v.showsRowLabels)]
        items += [.toggle(label: "showsColumnLabels", value: v.showsColumnLabels)]
        items += [.toggle(label: "showsEntranceAnimation", value: v.showsEntranceAnimation)]
        items += DemoProperty.color("selectionBorderColor", v.selectionBorderColor)
        items += [DemoProperty.number("selectionBorderWidth", v.selectionBorderWidth, 0...40)]
        items += [DemoProperty.enabled("自定义 selectionBorderCornerRadius", v.selectionBorderCornerRadius, default: 0.5)]
        if v.selectionBorderCornerRadius.wrappedValue != nil { items.append(DemoProperty.number("selectionBorderCornerRadius", DemoProperty.optional(v.selectionBorderCornerRadius, default: 0.5), 0...20, step: 0.05)) }
        items += [.toggle(label: "showsTooltipOnHit", value: v.showsTooltipOnHit)]

        return items
    }
    static func items(_ v: Binding<HYMChartTooltipTheme>) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = []
        items += [.color(label: "backgroundColor", value: v.backgroundColor)]
        items += [.color(label: "textColor", value: v.textColor)]
        items += DemoProperty.font("font", v.font)
        items += [DemoProperty.number("cornerRadius", v.cornerRadius, 0...40)]
        items += DemoProperty.insets("contentInset", v.contentInset)
        items += [DemoProperty.number("maxWidth", v.maxWidth, 40...400)]
        items += [.toggle(label: "showsArrow", value: v.showsArrow)]
        items += DemoProperty.size("arrowSize", v.arrowSize, 0...200)
        items += DemoProperty.color("shadowColor", v.shadowColor)
        items += [.toggle(label: "showsAnimation", value: v.showsAnimation)]
        items += [DemoProperty.number("gap", v.gap, 0...40)]
        items += [.picker(label: "position", selection: Binding(get: { v.wrappedValue.position.rawValue }, set: { v.wrappedValue.position = HYMChartTooltipPosition(rawValue: $0) ?? .automatic }), options: HYMChartTooltipPosition.allCases.map(\.rawValue)),
                  DemoProperty.number("offset.x", v.offset.x, -100...100),
                  DemoProperty.number("offset.y", v.offset.y, -100...100),
                  DemoProperty.number("fixedTopInset", v.fixedTopInset, 0...40)]
        return items
    }
    static func items(_ v: Binding<ChartLegendConfiguration>) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = []
        items += [.toggle(label: "isEnabled", value: v.isEnabled)]
        items += [DemoProperty.choice("position", v.position)]
        items += [DemoProperty.choice("alignment", v.alignment)]
        items += [DemoProperty.number("itemSpacing", v.itemSpacing, 0...40)]
        items += [DemoProperty.number("rowSpacing", v.rowSpacing, 0...40)]
        items += DemoProperty.size("symbolSize", v.symbolSize, 0...200)
        items += [DemoProperty.number("symbolTextSpacing", v.symbolTextSpacing, 0...40)]
        items += DemoProperty.font("font", v.font)
        items += [.color(label: "textColor", value: v.textColor)]
        items += [DemoProperty.number("hiddenAlpha", v.hiddenAlpha, 0...1, step: 0.05)]
        items += [DemoProperty.number("chartSpacing", v.chartSpacing, 0...40)]
        items += [DemoProperty.integer("maxRows", v.maxRows, 1...12)]
        items += [DemoProperty.number("maxHeight", v.maxHeight, 40...400)]
        items += [DemoProperty.number("maxWidth", v.maxWidth, 40...400)]
        items += DemoProperty.size("minimumPlotSize", v.minimumPlotSize, 0...200)
        items += [.toggle(label: "allowsToggling", value: v.allowsToggling),
                  .toggle(label: "业务组变化时另起一行", value: v.startsNewRowPerGroup)]
        return items
    }
}

// 每系列新增字段集中登记：所有覆盖均可恢复继承。
extension DemoThemeFields {
    static func seriesStyleItems(_ b: Binding<CartesianSeriesStyle>) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = [
            .picker(label: "系列连线覆盖", selection: Binding(get: { b.wrappedValue.lineConnectionStyle?.rawValue ?? "继承" }, set: { b.wrappedValue.lineConnectionStyle = LineConnectionStyle(rawValue: $0) }), options: ["继承"] + LineConnectionStyle.allCases.map(\.rawValue)),
            DemoProperty.enabled("自定义系列线宽", b.lineWidth, default: 2),
            DemoProperty.triState("系列标记可见", b.showsPoints),
            DemoProperty.enabled("自定义系列标记半径", b.pointRadius, default: 4),
            DemoProperty.triState("系列面积填充", b.showsArea),
            DemoProperty.enabled("自定义系列填充透明度", b.fillOpacity, default: 1),
            DemoProperty.enabled("自定义系列填充颜色", b.areaGradientColors, default: [.systemBlue, .clear])]
        if b.wrappedValue.lineWidth != nil { items.append(DemoProperty.number("系列线宽 pt", DemoProperty.optional(b.lineWidth, default: 2), 0...10)) }
        if b.wrappedValue.pointRadius != nil { items.append(DemoProperty.number("系列标记半径 pt", DemoProperty.optional(b.pointRadius, default: 4), 0...12)) }
        if b.wrappedValue.fillOpacity != nil { items.append(DemoProperty.number("系列填充透明度", DemoProperty.optional(b.fillOpacity, default: 1), 0...1, step: 0.05)) }
        if b.wrappedValue.areaGradientColors != nil {
            for index in 0..<2 {
                items.append(.color(label: index == 0 ? "系列渐变起色" : "系列渐变末色", value: Binding(get: { b.wrappedValue.areaGradientColors?.indices.contains(index) == true ? b.wrappedValue.areaGradientColors![index] : .clear }, set: { color in
                    var colors = b.wrappedValue.areaGradientColors ?? []
                    while colors.count < 2 { colors.append(.clear) }
                    colors[index] = color; b.wrappedValue.areaGradientColors = colors
                })))
            }
            items.append(.button(label: "恢复系列默认渐变（忽略主题渐变）") { b.wrappedValue.areaGradientColors = [] })
        }
        items.append(.button(label: "重置当前系列样式覆盖") { b.wrappedValue = .init() })
        return items
    }
}
