import SwiftUI

/// 可编辑基础字段的集中登记；复杂枚举/闭包在各专属面板选择预设。
enum DemoThemeFields {
    static func lineSamplingItems(_ v: Binding<LineChartSampling?>) -> [ChartDemoPanel.Item] {
        var items = [DemoProperty.enabled("启用 Min/Max 降采样（非堆叠直线）", v, default: LineChartSampling())]
        if v.wrappedValue != nil {
            let c = DemoProperty.optional(v, default: LineChartSampling())
            items += [DemoProperty.number("分组宽度 bucketWidth（pt）", c.bucketWidth, 1...12, step: 0.5),
                DemoProperty.integer("可见有效点门槛 minimumVisiblePoints", c.minimumVisiblePoints, 2...3000),
                .toggle(label: "密集时隐藏标记 hidesDenseMarkers", value: c.hidesDenseMarkers),
                .toggle(label: "密集时隐藏标签 hidesDenseDataLabels", value: c.hidesDenseDataLabels)]
        }
        return items
    }

    static func items(_ v: Binding<CartesianChartTheme>) -> [ChartDemoPanel.Item] {
        var items: [ChartDemoPanel.Item] = []
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
        items += [.toggle(label: "showsDataLabels", value: v.showsDataLabels)]
        items += [DemoProperty.number("dataLabelFontSize", v.dataLabelFontSize, 6...40)]
        items += DemoProperty.color("dataLabelColor", v.dataLabelColor)
        items += [DemoProperty.choice("dataLabelPosition", v.dataLabelPosition)]
        items += [DemoProperty.integer("dataLabelMaxMarkCount", v.dataLabelMaxMarkCount, 0...1000)]
        items += [.toggle(label: "showsEntranceAnimation", value: v.showsEntranceAnimation)]
        items += [.toggle(label: "showsTooltipOnHit", value: v.showsTooltipOnHit)]
        items += [DemoProperty.number("columnWidthRatio", v.columnWidthRatio, 0.1...1, step: 0.05)]
        items += [DemoProperty.number("columnGroupSpacingRatio", v.columnGroupSpacingRatio, 0...0.5, step: 0.05)]
        items += [DemoProperty.enabled("自定义 columnInnerSpacingRatio", v.columnInnerSpacingRatio, default: 0.5)]
        if v.columnInnerSpacingRatio.wrappedValue != nil { items.append(DemoProperty.number("columnInnerSpacingRatio", DemoProperty.optional(v.columnInnerSpacingRatio, default: 0.5), 0...0.5, step: 0.05)) }
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
        items += [.toggle(label: "allowsToggling", value: v.allowsToggling)]
        return items
    }
}
