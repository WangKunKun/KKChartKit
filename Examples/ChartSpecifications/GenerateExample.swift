import Foundation

/// Compile together with Charts/Specification/*.swift; no UIKit or chart engine required.
@main struct GenerateChartSpecificationExample {
    static func main() throws {
        let categories = [ChartCategory(id: "08", label: "08:00"), .init(id: "09", label: "09:00"), .init(id: "10", label: "10:00")]
        var appearance = ChartSeriesAppearance()
        appearance.color = .init(red: 0.12, green: 0.42, blue: 0.88)
        appearance.marker = .circle
        let specification = ChartSpecification(id: "power-trend", title: "功率趋势", domain: .categories(categories),
            valueAxes: [.init(id: "power")], series: [
                .init(id: "solar", name: "光伏", mark: .area, valueAxisID: "power", samples: [
                    .init(id: "solar-08", coordinate: .category("08"), value: 60, metadata: ["meterID": "M1"]),
                    .init(id: "solar-09", coordinate: .category("09"), value: nil),
                    .init(id: "solar-10", coordinate: .category("10"), value: -20)
                ], groupID: "energy", stackID: "supply", unit: "W", interpolation: .monotone, appearance: appearance),
                .init(id: "battery", name: "电池", mark: .line, valueAxisID: "power", samples: [
                    .init(id: "battery-08", coordinate: .category("08"), value: -40),
                    .init(id: "battery-09", coordinate: .category("09"), value: 30),
                    .init(id: "battery-10", coordinate: .category("10"), value: 0)
                ], groupID: "energy", stackID: "supply", unit: "W")
            ], groups: [.init(id: "energy", name: "能源")], stacking: .percentOfAbsoluteTotal)
        let data = try specification.jsonData()
        guard CommandLine.arguments.count >= 2 else {
            FileHandle.standardOutput.write(data); return
        }
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        if CommandLine.arguments.count >= 3 {
            var shared = specification
            shared.schemaVersion = 2
            shared.stackedAreaBoundary = .diverging
            try shared.jsonData().write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        }
        if CommandLine.arguments.count >= 4 {
            var zoned = specification
            zoned.schemaVersion = 3
            zoned.stackedAreaBoundary = .diverging
            zoned.series[0].appearance.valueColorZones = .init(zones: [
                .init(upperBound: 0, color: .init(red: 0.85, green: 0.16, blue: 0.22)),
                .init(upperBound: 50, color: .init(red: 0.95, green: 0.55, blue: 0.10)),
                .init(color: .init(red: 0.08, green: 0.62, blue: 0.40))
            ])
            try zoned.jsonData().write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
        }
        if CommandLine.arguments.count >= 5 {
            var axes = specification
            axes.schemaVersion = 4
            axes.stackedAreaBoundary = .diverging
            axes.categoryLabelInterval = 2
            axes.domainAppearance.labelFontWeight = .medium
            axes.valueAxes[0].appearance.labelFontWeight = .bold
            axes.valueAxes[0].tickPositions = [-100, -50, 0, 50, 100]
            var number = ChartValuePresentation(); number.localeIdentifier = "en_US_POSIX"
            axes.valueAxes[0].labelFormat = .init(number: number, unit: "%")
            try axes.jsonData().write(to: URL(fileURLWithPath: CommandLine.arguments[4]))
        }
        if CommandLine.arguments.count >= 6 {
            var annotated = specification
            annotated.schemaVersion = 5; annotated.stackedAreaBoundary = .diverging
            annotated.valueAxes.append(.init(id: "temperature", minimum: -20, maximum: 40))
            let style = ChartAnnotationLabelStyle(color: .init(red: 0, green: 0, blue: 0), fontSize: 13,
                fontWeight: .semibold, backgroundColor: .init(red: 1, green: 1, blue: 1, alpha: 0.95), alignment: .leading)
            annotated.plotLines = [
                .init(id: "limit", valueAxisID: "power", value: 40, color: .init(red: 0.8, green: 0.1, blue: 0.2),
                      lineWidth: 2, strokePattern: .dashed, label: "主轴 40%", labelStyle: style),
                .init(id: "secondary-limit", valueAxisID: "temperature", value: 10, label: "次轴 10%", labelStyle: style),
                .init(id: "hidden-limit", valueAxisID: "power", value: 80, isVisible: false)
            ]
            annotated.plotBands = [.init(id: "range", valueAxisID: "power", from: -20, to: 20,
                color: .init(red: 0, green: 0.6, blue: 0.3, alpha: 0.18), label: "±20%", labelStyle: style)]
            try annotated.jsonData().write(to: URL(fileURLWithPath: CommandLine.arguments[5]))
        }
        if CommandLine.arguments.count >= 7 {
            var interaction = specification
            interaction.schemaVersion = 6; interaction.stackedAreaBoundary = .diverging
            var tooltip = ChartTooltipSpecification()
            tooltip.layout = .columns; tooltip.position = .fixedTop; tooltip.headerTemplate = "当前 {key}"
            tooltip.sampleSelection.offset = -1; tooltip.sampleSelection.boundaryPolicy = .clamp
            tooltip.sampleSelection.offsetsBySeriesID = ["solar": 0]
            tooltip.seriesRules = ["battery": .init(title: "电池（上一时点）")]
            interaction.tooltip = tooltip
            var legend = ChartLegendSpecification(); legend.position = .top; legend.alignment = .leading
            legend.titlesBySeriesID = ["solar": "光伏发电", "battery": "储能"]
            interaction.legend = legend
            try interaction.jsonData().write(to: URL(fileURLWithPath: CommandLine.arguments[6]))
        }
    }
}
