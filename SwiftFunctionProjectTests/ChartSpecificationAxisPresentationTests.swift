import XCTest
import UIKit
@testable import SwiftFunctionProject

final class ChartSpecificationAxisPresentationTests: XCTestCase {
    private func fixture() -> ChartSpecification {
        var value = ChartSpecificationDemoSettings().specification(kind: .line)
        value.schemaVersion = 4
        return value
    }

    func testV4RoundTripAllWeightsExplicitEmptyTicksAndLegacyDefaults() throws {
        XCTAssertGreaterThanOrEqual(ChartSpecification.latestSchemaVersion, 4)
        for weight in ChartFontWeight.allCases {
            var value = fixture(); value.categoryLabelInterval = 2
            value.domainAppearance.labelFontWeight = weight
            value.valueAxes[0].appearance.labelFontWeight = weight
            value.valueAxes[0].tickPositions = [-100, 0, 100]
            value.valueAxes[0].labelFormat = .init(unit: "W")
            value.series[0].appearance.valueColorZones = ChartSpecificationDemoSettings.thresholdPreset()
            value.stackedAreaBoundary = .diverging
            XCTAssertEqual(try ChartSpecification.decodeJSON(value.jsonData()), value)
            value.valueAxes[0].tickPositions = []
            XCTAssertEqual(try ChartSpecification.decodeJSON(value.jsonData()).valueAxes[0].tickPositions, [])
        }
        for version in 1...3 {
            var value = fixture(); value.schemaVersion = version
            let data = try value.jsonData()
            XCTAssertEqual(try ChartSpecification.decodeJSON(data), value)
            let text = String(decoding: data, as: UTF8.self)
            for key in ["categoryLabelInterval", "labelFontWeight", "tickPositions", "labelFormat"] {
                XCTAssertFalse(text.contains(key), key)
            }
        }
        XCTAssertEqual(ChartSpecificationDemoSettings().specification(kind: .line).schemaVersion, 1)
    }

    func testPriorVersionsRejectEveryReservedKeyEvenNullThroughBothDecoders() throws {
        let paths = ["categoryLabelInterval", "domainAppearance.labelFontWeight", "valueAxes[0].tickPositions",
                     "valueAxes[0].labelFormat", "valueAxes[0].appearance.labelFontWeight"]
        for version in 1...3 {
            var value = fixture(); value.schemaVersion = version
            for path in paths {
                for bad in [NSNull(), "invalid"] as [Any] {
                    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: value.jsonData()) as? [String: Any])
                    if path == "categoryLabelInterval" { json[path] = bad }
                    else if path.hasPrefix("domainAppearance") {
                        var style = try XCTUnwrap(json["domainAppearance"] as? [String: Any])
                        style["labelFontWeight"] = bad; json["domainAppearance"] = style
                    } else {
                        var axes = try XCTUnwrap(json["valueAxes"] as? [[String: Any]])
                        if path.contains("appearance") {
                            var style = try XCTUnwrap(axes[0]["appearance"] as? [String: Any])
                            style["labelFontWeight"] = bad; axes[0]["appearance"] = style
                        } else { axes[0][path.hasSuffix("tickPositions") ? "tickPositions" : "labelFormat"] = bad }
                        json["valueAxes"] = axes
                    }
                    let data = try JSONSerialization.data(withJSONObject: json)
                    for decode in [ChartSpecification.decodeJSON, { try JSONDecoder().decode(ChartSpecification.self, from: $0) }] {
                        XCTAssertThrowsError(try decode(data)) { error in
                            XCTAssertEqual((error as? ChartSpecificationError)?.issues.first?.path, path)
                        }
                    }
                }
            }
        }
    }

    func testDowngradeRejectsEachFeatureWithoutSilentLoss() throws {
        let changes: [(String, (inout ChartSpecification) -> Void)] = [
            ("categoryLabelInterval", { $0.categoryLabelInterval = 2 }),
            ("domainAppearance.labelFontWeight", { $0.domainAppearance.labelFontWeight = .bold }),
            ("valueAxes[0].appearance.labelFontWeight", { $0.valueAxes[0].appearance.labelFontWeight = .thin }),
            ("valueAxes[0].tickPositions", { $0.valueAxes[0].tickPositions = [] }),
            ("valueAxes[0].labelFormat", { $0.valueAxes[0].labelFormat = .init() })
        ]
        for version in 1...3 {
            for (path, change) in changes {
                var value = fixture(); change(&value); value.schemaVersion = version
                XCTAssertTrue(value.validationIssues().contains { $0.path == path })
                XCTAssertThrowsError(try value.jsonData()); XCTAssertThrowsError(try JSONEncoder().encode(value))
            }
        }
    }

    func testInvalidTicksIntervalsAndNumberPrecisionHaveExactPaths() throws {
        for positions in [[0, 0], [1, 0], [0, .nan], [.infinity], [-Double.infinity]] {
            var value = fixture(); value.valueAxes[0].tickPositions = positions
            let index = positions.count - 1
            XCTAssertTrue(value.validationIssues().contains { $0.path == "valueAxes[0].tickPositions[\(index)]" })
        }
        for interval in [0, -1] {
            var value = fixture(); value.categoryLabelInterval = interval
            XCTAssertTrue(value.validationIssues().contains { $0.path == "categoryLabelInterval" })
        }
        for domain in [ChartDomain.numeric, .time] {
            var value = fixture(); value.domain = domain; value.categoryLabelInterval = 2
            XCTAssertTrue(value.validationIssues().contains { $0.path == "categoryLabelInterval" })
        }
        for digits in [-1, 13, 100] {
            var value = fixture(); value.valueAxes[0].labelFormat = .init()
            value.valueAxes[0].labelFormat?.number.maximumFractionDigits = digits
            XCTAssertTrue(value.validationIssues().contains { $0.path == "valueAxes[0].labelFormat.number.maximumFractionDigits" })
        }
        var value = fixture(); value.categoryLabelInterval = Int.max; value.valueAxes[0].tickPositions = [-1e100, 1e100]
        XCTAssertNoThrow(try value.validate()) // Out of domain is legal and filtered by the renderer.
    }

    func testV4StillRequiresBoundaryAndRejectsUnknownEnumsAndFutureVersions() throws {
        var value = fixture(); value.domainAppearance.labelFontWeight = .bold
        let data = try value.jsonData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "stackedAreaBoundary")
        XCTAssertThrowsError(try ChartSpecification.decodeJSON(JSONSerialization.data(withJSONObject: object)))
        let invalid = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "bold", with: "mysteryWeight")
        XCTAssertThrowsError(try ChartSpecification.decodeJSON(Data(invalid.utf8)))
        XCTAssertThrowsError(try ChartSpecification.decodeJSON(Data("{\"schemaVersion\":\(ChartSpecification.latestSchemaVersion + 1)}".utf8)))
    }
}

@MainActor final class HYMChartsSpecificationAxisPresentationTests: XCTestCase {
    private let adapter = HYMChartsSpecificationAdapter()
    private func source(_ kind: CartesianDemoKind = .column, secondary: Bool = false) -> ChartSpecification {
        var settings = ChartSpecificationDemoSettings(); settings.secondaryAxis = secondary
        settings.categoryLabelInterval = 2
        settings.axisPresentation["domain"] = .init(weight: .medium)
        settings.axisPresentation["power"] = .init(explicitTicks: true, formatted: true, weight: .bold)
        settings.axisPresentation["temperature"] = .init(explicitTicks: true, formatted: true, weight: .light)
        var value = settings.specification(kind: kind)
        value.valueAxes[0].minimum = -100; value.valueAxes[0].maximum = 150
        value.valueAxes[0].appearance.labelFontSize = 14
        if value.valueAxes.count == 2 {
            value.valueAxes[1].minimum = -50; value.valueAxes[1].maximum = 100
            value.valueAxes[1].appearance.labelFontSize = 18
        }
        return value
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ source: ChartSpecification) throws -> HYMChartView<R> {
        let config = try adapter.makeConfiguration(from: source)
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 640, height: 400))
        view.configure(model: config.model, theme: config.theme); view.layoutIfNeeded(); return view
    }
    private func labels(_ view: UIView, _ edge: String) -> [UILabel] {
        view.subviews.compactMap { $0 as? UILabel }.filter { $0.accessibilityIdentifier == "chart.axis." + edge }
    }

    func testFourRenderersConsumeIndependentAxisTicksFontsAndFormattedLabels() throws {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ kind: CartesianDemoKind) throws {
            let source = source(kind, secondary: kind != .bar)
            let output = try adapter.makeConfiguration(from: source)
            let view = try chart(type, source), r = view.rendererForTesting
            let valueEdge = kind == .bar ? "bottom" : "left", domainEdge = kind == .bar ? "left" : "bottom"
            XCTAssertEqual(r.currentValueTicks, [-100, -50, 0, 50, 100, 150])
            XCTAssertEqual(output.model.xAxis.categoryLabelInterval, 2)
            let main = labels(view, valueEdge)
            XCTAssertFalse(main.isEmpty)
            XCTAssertTrue(main.allSatisfy { $0.text?.hasSuffix(" W") == true && $0.font == UIFont.systemFont(ofSize: 14, weight: .bold) })
            let category = labels(view, domainEdge)
            XCTAssertFalse(category.isEmpty)
            XCTAssertTrue(category.allSatisfy { ["8:00", "10:00", "12:00"].contains($0.text ?? "") })
            XCTAssertTrue(category.allSatisfy { $0.font == output.model.xAxis.style.labelFont })
            if kind != .bar {
                let other = labels(view, "right")
                XCTAssertFalse(other.isEmpty)
                XCTAssertTrue(other.allSatisfy { $0.text?.hasSuffix(" °C") == true && $0.font == UIFont.systemFont(ofSize: 18, weight: .light) })
                XCTAssertEqual(output.model.secondaryYAxis?.tickPositions, [-50, 0, 25, 50, 100])
            } else { XCTAssertTrue(labels(view, "right").isEmpty) }
            XCTAssertEqual(output.source.series.map(\.samples), source.series.map(\.samples))
            XCTAssertEqual(r.datum(series: 0, category: 0)?.rawValue, 40)
        }
        try check(LineChartRenderer.self, .line); try check(ColumnChartRenderer.self, .column)
        try check(BarChartRenderer.self, .bar); try check(CombinedChartRenderer.self, .combined)
    }

    func testAllSystemFontWeightsAndSizeOnlyDefaultsMapWithoutResourceLookup() throws {
        let weights: [UIFont.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        for (weight, expected) in zip(ChartFontWeight.allCases, weights) {
            var source = source(); source.domainAppearance.labelFontWeight = weight
            source.valueAxes[0].appearance.labelFontWeight = weight
            let output = try adapter.makeConfiguration(from: source)
            XCTAssertEqual(output.model.xAxis.style.labelFont, UIFont.systemFont(ofSize: output.theme.tickLabelFont.pointSize, weight: expected))
            XCTAssertEqual(output.model.yAxis.style.labelFont, UIFont.systemFont(ofSize: 14, weight: expected))
        }
        var input = ChartSpecificationDemoSettings().specification(kind: .line)
        XCTAssertNil(try adapter.makeConfiguration(from: input).model.yAxis.style.labelFont)
        input.valueAxes[0].appearance.labelFontSize = 19
        XCTAssertEqual(try adapter.makeConfiguration(from: input).model.yAxis.style.labelFont, UIFont.systemFont(ofSize: 19))
    }

    func testLabelFormattingIsDisplayOnlyWithExplicitLocaleUnitsAndPercent() throws {
        var input = source(); let samples = input.series.map(\.samples)
        var number = ChartValuePresentation(); number.localeIdentifier = "en_US_POSIX"; number.scale = .engineering
        input.valueAxes[0].labelFormat = .init(number: number, unit: "W")
        var output = try adapter.makeConfiguration(from: input)
        XCTAssertEqual(output.model.yAxis.labelFormatter?(-1500), "-1.5 kW")
        number.scale = .none; number.localeIdentifier = "de_DE"; number.usesGroupingSeparator = false
        input.valueAxes[0].labelFormat = .init(number: number, unit: "°C")
        XCTAssertEqual(try adapter.makeConfiguration(from: input).model.yAxis.labelFormatter?(12.5), "12,5 °C")
        number.localeIdentifier = "en_US_POSIX"; number.rounding = .towardZero; number.maximumFractionDigits = 1
        input.valueAxes[0].labelFormat = .init(number: number)
        XCTAssertEqual(try adapter.makeConfiguration(from: input).model.yAxis.labelFormatter?(-12.59), "-12.5")
        for stacking in [ChartStackingPolicy.percentOfAbsoluteTotal, .percentOfFixedTotal(200)] {
            input.stacking = stacking; input.valueAxes[0].labelFormat = .init(number: number, unit: "%")
            output = try adapter.makeConfiguration(from: input)
            XCTAssertEqual(output.model.yAxis.labelFormatter?(50), "50 %")
            XCTAssertEqual(output.source.series.map(\.samples), samples)
            XCTAssertEqual(output.source.series.map(\.unit), ["W", "W"])
            XCTAssertEqual(output.model.series[0].data[0], 40)
        }
        input.valueAxes[0].labelFormat = nil
        XCTAssertNil(try adapter.makeConfiguration(from: input).model.yAxis.labelFormatter)
    }

    func testExplicitTicksFilterWithoutChangingDomainEmptySuppressesAndNilRestores() throws {
        var input = source(); input.valueAxes[0].tickPositions = [-200, -50, 0, 50, 200]
        let view = try chart(ColumnChartRenderer.self, input), r = view.rendererForTesting
        XCTAssertEqual(r.currentValueTicks, [-50, 0, 50])
        let domain = r.currentViewport, original = r.datum(series: 0, category: 0)
        input.valueAxes[0].tickPositions = []
        var output = try adapter.makeConfiguration(from: input); view.update(model: output.model); view.layoutIfNeeded()
        XCTAssertTrue(r.currentValueTicks.isEmpty); XCTAssertTrue(labels(view, "left").isEmpty)
        XCTAssertEqual(r.currentViewport.yMin, domain.yMin); XCTAssertEqual(r.currentViewport.yMax, domain.yMax)
        input.valueAxes[0].tickPositions = nil
        output = try adapter.makeConfiguration(from: input); view.update(model: output.model); view.layoutIfNeeded()
        XCTAssertFalse(r.currentValueTicks.isEmpty)
        XCTAssertEqual(r.datum(series: 0, category: 0)?.rawValue, original?.rawValue)
        XCTAssertEqual(r.datum(series: 0, category: 0)?.seriesID, original?.seriesID)
        XCTAssertNil(r.datum(series: 0, category: 2))
        XCTAssertEqual(output.sourceSample(seriesID: "source-0", categoryIndex: 2)?.id, "sample-0-2")
    }

    func testCategoryCadenceRemainsAbsoluteAfterZoomAndDoesNotResample() throws {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ kind: CartesianDemoKind) throws {
            var input = source(kind); input.categoryLabelInterval = 3
            let view = try chart(type, input), r = view.rendererForTesting
            // Avoid the adjacent band retained by the native vertical-axis edge policy.
            r.minimumXAxisCategories = 2; r.showCategoryRange(2..<6); view.layoutIfNeeded()
            let edge = kind == .bar ? "left" : "bottom"
            XCTAssertEqual(labels(view, edge).compactMap(\.text), ["11:00"])
            XCTAssertEqual(r.currentModel?.series[0].data.count, 6)
            XCTAssertEqual(r.datum(series: 0, category: 3)?.rawValue, -50)
            input.categoryLabelInterval = Int.max
            let output = try adapter.makeConfiguration(from: input)
            view.update(model: output.model); view.layoutIfNeeded()
            XCTAssertTrue(labels(view, edge).isEmpty) // absolute index zero is outside this viewport
        }
        try check(LineChartRenderer.self, .line); try check(ColumnChartRenderer.self, .column)
        try check(BarChartRenderer.self, .bar); try check(CombinedChartRenderer.self, .combined)
    }

    func testAxesCoexistWithG1ZonesAndDoNotRelaxG6OrHorizontalSecondaryRejections() throws {
        for boundary in ChartStackedAreaBoundary.allCases {
            var input = source(.combined, secondary: true); input.stackedAreaBoundary = boundary
            input.series[0].appearance.valueColorZones = ChartSpecificationDemoSettings.thresholdPreset(.rawValue)
            let output = try adapter.makeConfiguration(from: input)
            XCTAssertEqual(output.model.series.map(\.yAxisIndex), [0, 0, 1])
            XCTAssertEqual(output.model.stackedDrawValues[1][0], 20)
            XCTAssertNotNil(output.model.series[0].colorZones)
            XCTAssertEqual(try chart(CombinedChartRenderer.self, input).rendererForTesting.datum(series: 0, category: 0)?.rawValue, 40)
            input.valueAxes[0].isReversed = true
            XCTAssertTrue(adapter.diagnostics(for: input).contains { $0.code == .unsupportedCapability && $0.path == "valueAxes[0].isReversed" })
        }
        var input = source(.bar); input.valueAxes.append(.init(id: "other"))
        XCTAssertTrue(adapter.diagnostics(for: input).contains { $0.code == .unsupportedCapability && $0.path == "valueAxes" })
        input = source(); input.categoryLabelInterval = nil; input.domain = .numeric
        for i in input.series.indices { for j in input.series[i].samples.indices { input.series[i].samples[j].coordinate = .number(Double(j)) } }
        XCTAssertTrue(adapter.diagnostics(for: input).contains { $0.code == .unsupportedCapability && $0.path == "domain" })
    }

    func testDemoPerAxisStateAndDisablingSecondaryPreservesSettingsUntilReset() throws {
        for kind in [CartesianDemoKind.line, .column, .bar, .combined] {
            var settings = ChartSpecificationDemoSettings(); settings.secondaryAxis = true
            settings.axisPresentation["temperature"] = .init(explicitTicks: true, formatted: true, weight: .bold)
            settings.axisPresentation["domain"] = .init(weight: .thin); settings.categoryLabelInterval = 2
            var input = settings.specification(kind: kind)
            XCTAssertNil(input.valueAxes[0].tickPositions); XCTAssertNil(input.valueAxes[0].labelFormat)
            XCTAssertEqual(input.schemaVersion, 4); XCTAssertEqual(input.domainAppearance.labelFontWeight, .thin)
            XCTAssertNoThrow(try adapter.makeConfiguration(from: input))
            if kind != .bar {
                XCTAssertNotNil(input.valueAxes[1].tickPositions)
                input.valueAxes.reverse()
                let config = try adapter.makeConfiguration(from: input)
                XCTAssertEqual(config.model.yAxis.labelFormatter?(25), "25 °C")
                XCTAssertEqual(config.model.series.last?.yAxisIndex, 0)
            }
            settings.secondaryAxis = false
            XCTAssertEqual(settings.specification(kind: kind).valueAxes.count, 1)
            XCTAssertTrue(settings.axisPresentation["temperature"]?.explicitTicks == true)
            settings = .init(); input = settings.specification(kind: kind)
            XCTAssertEqual(input.schemaVersion, 1); XCTAssertNil(input.categoryLabelInterval)
            XCTAssertNil(input.valueAxes[0].appearance.labelFontWeight)
        }
    }

    func testObjectiveCUpdateFailureAndViewportPreserveResetRetainOriginalDocument() throws {
        var input = source()
        let document = try HYMChartSpecificationDocument(jsonData: input.jsonData())
        let bridge = try document.makeNativeBridge(frame: CGRect(x: 0, y: 0, width: 640, height: 400))
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<ColumnChartRenderer>)
        view.layoutIfNeeded(); let r = view.rendererForTesting
        r.minimumXAxisCategories = 2; r.zoomXAxis(factor: 2, anchorScreenX: r.currentPlotFrame.midX)
        let viewport = r.xAxisViewport
        input.valueAxes[0].tickPositions = [-50, 0, 50]; input.valueAxes[0].labelFormat?.unit = "new"
        try bridge.update(specification: HYMChartSpecificationDocument(specification: input), preserveViewport: true)
        view.layoutIfNeeded(); XCTAssertEqual(r.xAxisViewport, viewport)
        XCTAssertTrue(labels(view, "left").allSatisfy { $0.text?.hasSuffix(" new") == true })
        var invalid = input; invalid.valueAxes[0].tickPositions = [0, 0]
        XCTAssertThrowsError(try HYMChartSpecificationDocument(specification: invalid))
        invalid = input; invalid.valueAxes[0].isReversed = true
        XCTAssertThrowsError(try bridge.update(specification: HYMChartSpecificationDocument(specification: invalid), preserveViewport: false))
        XCTAssertEqual(r.xAxisViewport, viewport)
        XCTAssertEqual(r.currentModel?.yAxis.tickPositions, [-50, 0, 50])
        XCTAssertEqual(try ChartSpecification.decodeJSON(document.jsonData()).valueAxes[0].labelFormat?.unit, "W")
        input.valueAxes[0].tickPositions = nil; input.valueAxes[0].labelFormat = nil
        try bridge.update(specification: HYMChartSpecificationDocument(specification: input), preserveViewport: false)
        view.layoutIfNeeded(); XCTAssertEqual(r.xAxisViewport, r.fullXAxisDomain)
        XCTAssertNil(r.currentModel?.yAxis.labelFormatter)
        XCTAssertEqual(r.datum(series: 0, category: 0)?.rawValue, 40)
    }
}
