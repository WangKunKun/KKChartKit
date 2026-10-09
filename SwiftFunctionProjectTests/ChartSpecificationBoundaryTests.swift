import XCTest
@testable import SwiftFunctionProject

final class ChartSpecificationBoundaryTests: XCTestCase {
    private func fixture() -> ChartSpecification {
        .init(id: "g1", domain: .categories([.init(id: "a", label: "A"), .init(id: "b", label: "B")]),
              valueAxes: [.init(id: "value")], series: [
                .init(id: "source", name: "Source", mark: .area, valueAxisID: "value", samples: [
                    .init(id: "first", coordinate: .category("a"), value: -40),
                    .init(id: "missing", coordinate: .category("b"), value: nil)
                ], stackID: "stack", unit: "W")
              ], stacking: .sum)
    }

    private func object() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: fixture().jsonData()) as? [String: Any])
    }

    func testV1KeepsIndependentAndOmitsNewFieldOnReencoding() throws {
        let data = try fixture().jsonData()
        let decoded = try ChartSpecification.decodeJSON(data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.stackedAreaBoundary, .independent)
        XCTAssertNil(try object()["stackedAreaBoundary"])
        XCTAssertEqual(try decoded.jsonData(), data)
        // General unknown metadata remains ignored, but the newly reserved boundary key does not.
        var extra = try object(); extra["unrecognizedFutureNote"] = "ignored"
        XCTAssertEqual(try ChartSpecification.decodeJSON(JSONSerialization.data(withJSONObject: extra)), decoded)
    }

    func testV2AllBoundaryAndStackPoliciesRoundTripPreservingInput() throws {
        for boundary in ChartStackedAreaBoundary.allCases {
            for stacking in [ChartStackingPolicy.sum, .percentOfAbsoluteTotal, .percentOfFixedTotal(200)] {
                var source = fixture(); source.schemaVersion = 2
                source.stackedAreaBoundary = boundary; source.stacking = stacking
                let decoded = try ChartSpecification.decodeJSON(source.jsonData())
                XCTAssertEqual(decoded, source)
                XCTAssertEqual(decoded.series, fixture().series)
                let object = try XCTUnwrap(JSONSerialization.jsonObject(with: source.jsonData()) as? [String: Any])
                XCTAssertEqual(object["stackedAreaBoundary"] as? String, boundary.rawValue)
            }
        }
    }

    func testV2RequiresKnownNonNullBoundaryAndRejectsFutureVersionFirst() throws {
        let malformed: [Any?] = [nil, NSNull(), "vendor-chain", 1, ["mode": "diverging"]]
        for value in malformed {
            var json = try object(); json["schemaVersion"] = 2; json["stackedAreaBoundary"] = value
            XCTAssertThrowsError(try ChartSpecification.decodeJSON(JSONSerialization.data(withJSONObject: json)))
        }
        for version in [-1, 0, ChartSpecification.latestSchemaVersion + 1, 999] {
            let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": version])
            XCTAssertThrowsError(try ChartSpecification.decodeJSON(data)) { error in
                XCTAssertEqual((error as? ChartSpecificationError)?.issues.first?.code, .unsupportedVersion)
            }
        }
    }

    func testV1CannotSmuggleBoundaryKeyOrSilentlyDowngradeV2() throws {
        for value in ["independent", "followBaseline", "diverging", NSNull()] as [Any] {
            var json = try object(); json["stackedAreaBoundary"] = value
            XCTAssertThrowsError(try ChartSpecification.decodeJSON(JSONSerialization.data(withJSONObject: json))) { error in
                XCTAssertEqual((error as? ChartSpecificationError)?.issues.first?.path, "stackedAreaBoundary")
            }
        }
        for mode in [ChartStackedAreaBoundary.followBaseline, .diverging] {
            var source = fixture(); source.stackedAreaBoundary = mode
            XCTAssertThrowsError(try source.jsonData())
            XCTAssertThrowsError(try JSONEncoder().encode(source))
            source.schemaVersion = 2
            XCTAssertNoThrow(try source.jsonData())
            source.schemaVersion = 1
            XCTAssertTrue(source.validationIssues().contains { $0.path == "stackedAreaBoundary" })
        }
    }

    func testNonIndependentBoundaryNeedsStackedLineFamilyButAllowsHiddenAndPureLine() throws {
        for boundary in [ChartStackedAreaBoundary.followBaseline, .diverging] {
            var source = fixture(); source.schemaVersion = 2; source.stackedAreaBoundary = boundary
            source.stacking = .none
            XCTAssertThrowsError(try source.validate())
            source.stacking = .sum; source.series[0].mark = .bar
            XCTAssertThrowsError(try source.validate())
            source.series[0].mark = .line; source.series[0].stackID = nil
            XCTAssertThrowsError(try source.validate())
            source.series[0].stackID = "stack"; source.series[0].isVisible = false
            XCTAssertNoThrow(try source.validate())
            source.series = []
            XCTAssertThrowsError(try source.validate())
            source.stackedAreaBoundary = .independent
            XCTAssertNoThrow(try source.validate())
        }
    }
}

@MainActor final class HYMChartsBoundaryAdapterTests: XCTestCase {
    private func source(kind: CartesianDemoKind = .line) -> ChartSpecification {
        var settings = ChartSpecificationDemoSettings(); settings.boundary = .diverging
        return settings.specification(kind: kind)
    }
    private func paths(_ layer: CALayer) -> [CGPath] {
        if let gradient = layer as? CAGradientLayer, let path = (gradient.mask as? CAShapeLayer)?.path { return [path] }
        return (layer.sublayers ?? []).flatMap(paths)
    }
    private func chart(_ source: ChartSpecification) throws -> HYMChartView<LineChartRenderer> {
        let config = try HYMChartsSpecificationAdapter().makeConfiguration(from: source)
        let view = HYMChartView<LineChartRenderer>(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
        view.configure(model: config.model, theme: config.theme); view.layoutIfNeeded()
        return view
    }

    func testBoundaryMapsAllModesWithoutChangingSourceOrStackValues() throws {
        for (boundary, native) in [(ChartStackedAreaBoundary.independent, StackedAreaBoundaryMode.independent),
                                   (.followBaseline, .followBaseline), (.diverging, .diverging)] {
            var input = source(); input.stackedAreaBoundary = boundary
            let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: input)
            XCTAssertEqual(output.theme.stackedAreaBoundaryMode, native)
            XCTAssertEqual(output.source, input)
            XCTAssertEqual(output.model.series.map(\.id), input.series.map(\.id))
            XCTAssertEqual(output.model.stackedDrawValues[1][3], -70)
            XCTAssertEqual(output.sourceSample(seriesID: "source-1", categoryIndex: 2)?.value, -10)
            let view = try chart(input)
            XCTAssertEqual(view.rendererForTesting.divergingBoundarySeries, boundary == .diverging ? [0, 1] : [])
        }
    }

    func testDivergingOverridesConnectForGeometryButPreservesRawMissingAndHitIdentity() throws {
        var input = source()
        for index in input.series.indices { input.series[index].missingValues = .connect }
        let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: input)
        let view = try chart(input), renderer = view.rendererForTesting
        XCTAssertEqual(renderer.divergingBoundarySeries, [0, 1])
        XCTAssertNil(renderer.datum(series: 0, category: 2))
        let datum = try XCTUnwrap(renderer.datum(series: 1, category: 2))
        XCTAssertEqual(datum.rawValue, -10)
        XCTAssertEqual(output.sourceSample(seriesID: datum.seriesID, categoryIndex: datum.categoryIndex)?.id, "sample-1-2")
        XCTAssertEqual(output.source.series[1].missingValues, .connect)
        let areas = paths(renderer.seriesLayer); XCTAssertFalse(areas.isEmpty)
        for path in areas {
            for x in [1.25, 1.75, 2.25, 2.75] {
                for y in stride(from: -70.0, through: 90.0, by: 10) {
                    XCTAssertFalse(path.contains(renderer.screenPoint(x: x, y: y)))
                }
            }
        }
    }

    func testPercentUsesOneAbsoluteDenominatorForPositiveAndNegative() throws {
        for stacking in [ChartStackingPolicy.percentOfAbsoluteTotal, .percentOfFixedTotal(200)] {
            var input = source(); input.stacking = stacking
            input.series[0].samples[0].value = 60; input.series[1].samples[0].value = -40
            let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: input)
            let factor = stacking == .percentOfAbsoluteTotal ? 1.0 : 0.5
            XCTAssertEqual(output.model.stackedDrawValues[0][0], 60 * factor, accuracy: 0.0001)
            XCTAssertEqual(output.model.stackedDrawValues[1][0], -40 * factor, accuracy: 0.0001)
            XCTAssertEqual(try chart(input).rendererForTesting.divergingBoundarySeries, [0, 1])
            XCTAssertEqual(output.sourceSample(seriesID: "source-1", categoryIndex: 0)?.value, -40)
        }
    }

    func testCombinedBarGapDoesNotCutLineFamilyGeometry() throws {
        var input = source(kind: .combined)
        input.series[1].samples[2].value = 10
        let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: input)
        XCTAssertEqual(output.kind, .combined)
        let view = HYMChartView<CombinedChartRenderer>(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
        view.configure(model: output.model, theme: output.theme); view.layoutIfNeeded()
        let before = paths(view.rendererForTesting.rootLayer); XCTAssertFalse(before.isEmpty)
        input.series[0].samples[2].value = nil
        let missingBar = try HYMChartsSpecificationAdapter().makeConfiguration(from: input)
        view.update(model: missingBar.model, theme: missingBar.theme); view.layoutIfNeeded()
        XCTAssertEqual(paths(view.rendererForTesting.rootLayer), before)
        XCTAssertEqual(missingBar.source.series.count, 3)
    }

    func testObjectiveCV2UpdatePreservesOrResetsViewportAndRejectsUnsupportedUpdate() throws {
        let input = source()
        let document = try HYMChartSpecificationDocument(jsonData: input.jsonData())
        let bridge = try document.makeNativeBridge(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
        bridge.chartView.layoutIfNeeded()
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        let renderer = view.rendererForTesting
        renderer.minimumXAxisCategories = 2
        renderer.zoomXAxis(factor: 2, anchorScreenX: renderer.currentPlotFrame.midX)
        let viewport = renderer.xAxisViewport
        XCTAssertEqual(renderer.divergingBoundarySeries, [0, 1])
        var updated = input; updated.stackedAreaBoundary = .followBaseline
        try bridge.update(specification: HYMChartSpecificationDocument(specification: updated), preserveViewport: true)
        view.layoutIfNeeded()
        XCTAssertEqual(renderer.xAxisViewport.lowerBound, viewport.lowerBound, accuracy: 0.0001)
        XCTAssertEqual(renderer.xAxisViewport.upperBound, viewport.upperBound, accuracy: 0.0001)
        XCTAssertTrue(renderer.divergingBoundarySeries.isEmpty)
        var rejected = input; rejected.valueAxes[0].isReversed = true
        XCTAssertThrowsError(try bridge.update(specification: HYMChartSpecificationDocument(specification: rejected), preserveViewport: false))
        XCTAssertEqual(renderer.currentTheme?.stackedAreaBoundaryMode, .followBaseline)
        XCTAssertEqual(renderer.xAxisViewport, viewport)
        try bridge.update(specification: document, preserveViewport: false); view.layoutIfNeeded()
        XCTAssertEqual(renderer.divergingBoundarySeries, [0, 1])
        XCTAssertEqual(renderer.xAxisViewport, renderer.fullXAxisDomain)
        XCTAssertEqual(try ChartSpecification.decodeJSON(document.jsonData()), input)
    }

    func testDemoBoundarySwitchAndResetRemainValidForEveryKind() throws {
        for kind in [CartesianDemoKind.line, .combined] {
            var settings = ChartSpecificationDemoSettings()
            for boundary in ChartStackedAreaBoundary.allCases {
                settings.boundary = boundary
                for area in [true, false] {
                    settings.area = area
                    let input = settings.specification(kind: kind)
                    XCTAssertEqual(input.schemaVersion, boundary == .independent ? 1 : 2)
                    XCTAssertEqual(try HYMChartsSpecificationAdapter().makeConfiguration(from: input).source.stackedAreaBoundary, boundary)
                }
            }
            settings = .init()
            XCTAssertEqual(settings.specification(kind: kind).schemaVersion, 1)
        }
        for kind in [CartesianDemoKind.column, .bar] {
            XCTAssertNoThrow(try HYMChartsSpecificationAdapter().makeConfiguration(from: ChartSpecificationDemoSettings().specification(kind: kind)))
        }
    }
}
