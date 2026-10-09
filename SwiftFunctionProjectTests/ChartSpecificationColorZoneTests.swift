import XCTest
@testable import SwiftFunctionProject

final class ChartSpecificationColorZoneTests: XCTestCase {
    private func fixture() -> ChartSpecification {
        var source = ChartSpecificationDemoSettings().specification(kind: .column)
        source.schemaVersion = 3
        source.series[0].appearance.valueColorZones = .init(zones: [.init(upperBound: 0),
            .init(upperBound: 50, color: .init(red: 1, green: 0, blue: 0)), .init()])
        return source
    }

    func testV3RoundTripRetainsBoundaryColorsAndNilSamplesWithoutChangingDefaults() throws {
        for boundary in ChartStackedAreaBoundary.allCases {
            var source = fixture(); source.series[0].mark = .area
            source.stackedAreaBoundary = boundary
            XCTAssertEqual(try ChartSpecification.decodeJSON(source.jsonData()), source)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: source.jsonData()) as? [String: Any])
            XCTAssertEqual(json["stackedAreaBoundary"] as? String, boundary.rawValue)
        }
        XCTAssertGreaterThanOrEqual(ChartSpecification.latestSchemaVersion, 3)
        for version in [1, 2] {
            var source = fixture(); source.schemaVersion = version
            source.series[0].appearance.valueColorZones = nil
            let decoded = try ChartSpecification.decodeJSON(source.jsonData())
            XCTAssertEqual(decoded, source)
            XCTAssertFalse(String(decoding: try source.jsonData(), as: UTF8.self).contains("valueColorZones"))
        }
        XCTAssertEqual(ChartSpecificationDemoSettings().specification(kind: .line).schemaVersion, 1)
    }

    func testV1AndV2RejectReservedZoneKeyIncludingNullAndDirectEncoderDowngrade() throws {
        for version in [1, 2] {
            var source = fixture(); source.schemaVersion = version
            XCTAssertThrowsError(try source.jsonData())
            XCTAssertThrowsError(try JSONEncoder().encode(source))
            source.series[0].appearance.valueColorZones = nil
            for value in [NSNull(), [:], ["valueSource": "drawValue", "zones": []]] as [Any] {
                var json = try XCTUnwrap(JSONSerialization.jsonObject(with: source.jsonData()) as? [String: Any])
                var rows = try XCTUnwrap(json["series"] as? [[String: Any]])
                var appearance = try XCTUnwrap(rows[1]["appearance"] as? [String: Any])
                appearance["valueColorZones"] = value; rows[1]["appearance"] = appearance; json["series"] = rows
                let data = try JSONSerialization.data(withJSONObject: json)
                for decode in [ChartSpecification.decodeJSON, { try JSONDecoder().decode(ChartSpecification.self, from: $0) }] {
                    XCTAssertThrowsError(try decode(data)) { error in
                        XCTAssertEqual((error as? ChartSpecificationError)?.issues.first?.path,
                                       "series[1].appearance.valueColorZones")
                    }
                }
            }
        }
    }

    func testInvalidZonesHavePrecisePathsAndDoNotSilentlyFallback() throws {
        let cases: [([ChartValueColorZone], String)] = [
            ([], ".zones"), ([.init(upperBound: .nan)], ".zones[0].upperBound"),
            ([.init(upperBound: .infinity)], ".zones[0].upperBound"),
            ([.init(upperBound: -.infinity)], ".zones[0].upperBound"),
            ([.init(upperBound: 1), .init(upperBound: 1)], ".zones[1].upperBound"),
            ([.init(upperBound: 1), .init(upperBound: -1)], ".zones[1].upperBound"),
            ([.init(), .init(upperBound: 1)], ".zones[0].upperBound"),
            ([.init(color: .init(red: 2, green: 0, blue: 0))], ".zones[0].color"),
            ([.init(color: .init(red: 0, green: 0, blue: 0, alpha: .nan))], ".zones[0].color")
        ]
        for (zones, suffix) in cases {
            var source = fixture(); source.series[0].appearance.valueColorZones?.zones = zones
            XCTAssertTrue(source.validationIssues().contains { $0.path == "series[0].appearance.valueColorZones" + suffix })
            XCTAssertThrowsError(try source.jsonData())
        }
        for zones: [ChartValueColorZone] in [[.init()], [.init(upperBound: -10), .init(upperBound: 0)],
                                            [.init(color: .init(red: 0, green: 1, blue: 0, alpha: 0))]] {
            var source = fixture(); source.series[0].appearance.valueColorZones?.zones = zones
            XCTAssertNoThrow(try source.validate())
        }
    }

    func testV3RequiresBoundaryAndKnownZoneSourceAndFutureVersionFailsFirst() throws {
        let data = try fixture().jsonData()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "stackedAreaBoundary")
        XCTAssertThrowsError(try ChartSpecification.decodeJSON(JSONSerialization.data(withJSONObject: json)))
        let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "drawValue", with: "cumulativeRaw")
        XCTAssertThrowsError(try ChartSpecification.decodeJSON(Data(text.utf8)))
        XCTAssertThrowsError(try ChartSpecification.decodeJSON(Data("{\"schemaVersion\":\(ChartSpecification.latestSchemaVersion + 1)}".utf8))) { error in
            XCTAssertEqual((error as? ChartSpecificationError)?.issues.first?.code, .unsupportedVersion)
        }
    }
}

@MainActor final class HYMChartsSpecificationColorZoneTests: XCTestCase {
    private let adapter = HYMChartsSpecificationAdapter()
    private func zones(_ source: ChartZoneValueSource = .drawValue) -> ChartValueColorZones {
        .init(valueSource: source, zones: [.init(upperBound: 0, color: .init(red: 1, green: 0, blue: 0)),
            .init(upperBound: 50, color: .init(red: 0, green: 0, blue: 1)),
            .init(color: .init(red: 0, green: 1, blue: 0))])
    }
    private func source(_ kind: CartesianDemoKind = .column, _ valueSource: ChartZoneValueSource = .drawValue) -> ChartSpecification {
        var input = ChartSpecificationDemoSettings().specification(kind: kind)
        input.schemaVersion = 3
        for i in input.series.indices { input.series[i].appearance.valueColorZones = zones(valueSource) }
        input.series[0].samples[0].value = 50; input.series[1].samples[0].value = 20
        return input
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ input: ChartSpecification) throws -> HYMChartView<R> {
        let config = try adapter.makeConfiguration(from: input)
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
        view.configure(model: config.model, theme: config.theme); view.layoutIfNeeded()
        return view
    }
    private func color(_ renderer: CartesianRendererBase<CartesianChartTheme>, _ series: Int, _ category: Int) throws -> UIColor {
        let hit = try XCTUnwrap(renderer.makeHitTarget(seriesIndex: series, categoryIndex: category,
                                                     value: renderer.currentDrawValues[series][category]))
        let frame = try XCTUnwrap(renderer.hitFrame(for: hit))
        let layer = (renderer as? CombinedChartRenderer)?.columns.seriesLayer ?? renderer.seriesLayer
        let shape = try XCTUnwrap(layer.sublayers?.compactMap { $0 as? CAShapeLayer }.reversed().first {
            $0.fillColor != nil && $0.path?.contains(CGPoint(x: frame.midX, y: frame.midY)) == true
        })
        return UIColor(cgColor: try XCTUnwrap(shape.fillColor))
    }

    func testRawLineAndAreaAreExplicitlyRejectedIncludingHiddenSeries() throws {
        for mark in [ChartMark.line, .area] {
            var input = source(.line, .rawValue); input.series[1].mark = mark; input.series[1].isVisible = false
            XCTAssertNoThrow(try input.validate()) // Semantically valid; backend-specific limitation.
            XCTAssertTrue(adapter.diagnostics(for: input).contains {
                $0.code == .unsupportedCapability && $0.path == "series[1].appearance.valueColorZones.valueSource"
            })
            XCTAssertThrowsError(try adapter.makeConfiguration(from: input))
        }
    }

    func testHalfOpenBoundsInheritanceAndPrecedenceAfterAdaptation() throws {
        var input = source(.column, .rawValue)
        input.series[0].appearance.color = .init(red: 0.5, green: 0, blue: 0.5)
        input.series[0].appearance.negativeColor = .init(red: 0, green: 0, blue: 0)
        var row = try adapter.makeConfiguration(from: input).model.series[0]
        row.barColors = [.yellow]
        let colors = CartesianColumnColors(series: row, defaultColor: .cyan)
        for (v, expected): (Double, UIColor) in [(-1, .red), (0, .blue), (49, .blue), (50, .green), (51, .green)] {
            XCTAssertEqual(colors.color(categoryIndex: 0, sourceIndex: 0, rawValue: v, drawValue: 100), expected)
        }
        input.series[0].appearance.valueColorZones = .init(zones: [.init(upperBound: 0), .init(upperBound: 50, color: .init(red: 0, green: 1, blue: 0))])
        row = try adapter.makeConfiguration(from: input).model.series[0]
        let inherited = CartesianColumnColors(series: row, defaultColor: .cyan)
        for value in [-1.0, 50] {
            XCTAssertEqual(inherited.color(categoryIndex: 0, sourceIndex: 0, rawValue: value, drawValue: value), row.color)
        }
        input.series[0].appearance.valueColorZones = nil
        row = try adapter.makeConfiguration(from: input).model.series[0]
        XCTAssertEqual(CartesianColumnColors(series: row, defaultColor: .cyan)
            .color(categoryIndex: 0, sourceIndex: 0, rawValue: -1, drawValue: -1), row.negativeColor)
    }

    func testRaw20Draw70PercentVisibilityAndIdentityInVerticalAndHorizontalBars() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ kind: CartesianDemoKind) throws {
            for policy in [ChartStackingPolicy.none, .sum, .percentOfAbsoluteTotal, .percentOfFixedTotal(200)] {
                var input = source(kind, .rawValue); input.stacking = policy
                let view = try chart(type, input), renderer = view.rendererForTesting
                XCTAssertEqual(try color(renderer, 1, 0), .blue)
                let before = try XCTUnwrap(renderer.datum(series: 1, category: 0))
                XCTAssertEqual(before.rawValue, 20)
                let expectedDraw: Double
                switch policy {
                case .none: expectedDraw = 20
                case .sum: expectedDraw = 70
                case .percentOfAbsoluteTotal: expectedDraw = 100
                case .percentOfFixedTotal: expectedDraw = 35
                }
                XCTAssertEqual(before.drawValue, expectedDraw, accuracy: 0.0001)
                for i in input.series.indices { input.series[i].appearance.valueColorZones?.valueSource = .drawValue }
                let output = try adapter.makeConfiguration(from: input)
                view.update(model: output.model, theme: output.theme); view.layoutIfNeeded()
                XCTAssertEqual(try color(renderer, 1, 0), policy == .none || policy == .percentOfFixedTotal(200) ? .blue : .green)
                let after = try XCTUnwrap(renderer.datum(series: 1, category: 0))
                XCTAssertEqual(after.drawValue, before.drawValue); XCTAssertEqual(after.stackBase, before.stackBase)
                XCTAssertEqual(after.rawValue, before.rawValue); XCTAssertEqual(after.seriesID, "source-1")
                XCTAssertEqual(output.sourceSample(seriesID: after.seriesID, categoryIndex: 0)?.id, "sample-1-0")
                XCTAssertNil(renderer.datum(series: 0, category: 2))
                view.setSeriesVisible(false, for: "source-0"); view.layoutIfNeeded()
                XCTAssertEqual(try color(renderer, 1, 0), policy == .percentOfAbsoluteTotal ? .green : .blue)
                // Raw colors stay stable even when the predecessor is hidden.
                input.series[0].isVisible = false
                input.series[1].appearance.valueColorZones?.valueSource = .rawValue
                let raw = try adapter.makeConfiguration(from: input)
                view.update(model: raw.model, theme: raw.theme); view.layoutIfNeeded()
                XCTAssertEqual(try color(renderer, 1, 0), .blue)
            }
        }
        try verify(ColumnChartRenderer.self, .column); try verify(BarChartRenderer.self, .bar)
    }

    func testLineZonesRetainAreaFillAndG1GeometryAcrossPolicies() throws {
        for boundary in ChartStackedAreaBoundary.allCases {
            for policy in [ChartStackingPolicy.none, .sum, .percentOfAbsoluteTotal, .percentOfFixedTotal(200)] {
                if boundary != .independent && policy == .none { continue }
                var input = source(.line); input.stacking = policy; input.stackedAreaBoundary = boundary
                input.series[0].appearance.areaFill = .solid(.init(red: 0.5, green: 0, blue: 0.5))
                let output = try adapter.makeConfiguration(from: input)
                let view = try chart(LineChartRenderer.self, input)
                XCTAssertEqual(view.rendererForTesting.divergingBoundarySeries, boundary == .diverging ? [0, 1] : [])
                XCTAssertEqual(output.source, input)
                XCTAssertEqual(output.model.series[0].style.areaGradientColors?.count, 2)
                let zones = try XCTUnwrap(output.model.series[0].colorZones)
                XCTAssertTrue(zones.zones.allSatisfy { $0.areaGradientColors == nil })
                XCTAssertEqual(zones.axis, .y)
                let resolver = try XCTUnwrap(CartesianResolvedColorZones(configuration: zones, negativeColor: nil, baseColor: .black))
                XCTAssertFalse(resolver.overridesArea)
                XCTAssertEqual(resolver.color(x: 999, y: 50), .green)
                XCTAssertNil(view.rendererForTesting.datum(series: 0, category: 2))
                XCTAssertEqual(output.sourceSample(seriesID: "source-0", categoryIndex: 2)?.id, "sample-0-2")
            }
        }
    }

    func testCombinedFamiliesAndSecondaryAxisDoNotShareThresholdUnits() throws {
        var input = source(.combined); input.stackedAreaBoundary = .diverging
        input.valueAxes.append(.init(id: "temperature"))
        input.series[2].valueAxisID = "temperature"; input.series[2].unit = "°C"
        input.series[2].appearance.valueColorZones = .init(zones: [.init(upperBound: 5, color: .init(red: 1, green: 0, blue: 0)), .init()])
        let output = try adapter.makeConfiguration(from: input)
        XCTAssertEqual(output.model.series.map(\.yAxisIndex), [0, 0, 1])
        XCTAssertEqual(output.model.stackedDrawValues[1][0], 20) // bar 50 must not join line stack.
        XCTAssertEqual(output.model.stackedDrawValues[2][0], 5)
        let view = try chart(CombinedChartRenderer.self, input)
        XCTAssertEqual(try color(view.rendererForTesting, 0, 0), .green)
        XCTAssertEqual(output.source.series.map(\.unit), ["W", "W", "°C"])
    }

    func testDemoZonesArePerStableSeriesIDAndResetRestoresOldSchema() throws {
        for kind in [CartesianDemoKind.line, .column, .bar, .combined] {
            var settings = ChartSpecificationDemoSettings()
            settings.valueColorZones["source-1"] = ChartSpecificationDemoSettings.thresholdPreset()
            let input = settings.specification(kind: kind)
            XCTAssertEqual(input.schemaVersion, 3)
            XCTAssertNil(input.series[0].appearance.valueColorZones)
            XCTAssertEqual(input.series[1].appearance.valueColorZones, settings.valueColorZones["source-1"])
            XCTAssertNoThrow(try adapter.makeConfiguration(from: input))
            if kind == .line || kind == .combined {
                settings.boundary = .diverging
                XCTAssertNoThrow(try adapter.makeConfiguration(from: settings.specification(kind: kind)))
                settings.valueColorZones = [:]
                XCTAssertEqual(settings.specification(kind: kind).schemaVersion, 2)
            }
            settings = .init()
            XCTAssertEqual(settings.specification(kind: kind).schemaVersion, 1)
            XCTAssertTrue(settings.specification(kind: kind).series.allSatisfy { $0.appearance.valueColorZones == nil })
        }
    }

    func testObjectiveCV3UpdateReorderFailureViewportAndResetKeepIdentity() throws {
        var input = source(.column)
        let document = try HYMChartSpecificationDocument(jsonData: input.jsonData())
        let bridge = try document.makeNativeBridge(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<ColumnChartRenderer>)
        view.layoutIfNeeded(); let renderer = view.rendererForTesting
        renderer.minimumXAxisCategories = 2
        renderer.zoomXAxis(factor: 2, anchorScreenX: renderer.currentPlotFrame.midX)
        let viewport = renderer.xAxisViewport
        input.series.reverse()
        try bridge.update(specification: HYMChartSpecificationDocument(specification: input), preserveViewport: true)
        view.layoutIfNeeded(); XCTAssertEqual(renderer.xAxisViewport, viewport)
        XCTAssertEqual(renderer.datum(series: 0, category: 0)?.seriesID, "source-1")
        XCTAssertEqual(renderer.datum(series: 0, category: 0)?.rawValue, 20)
        var bad = input; bad.valueAxes[0].isReversed = true
        XCTAssertThrowsError(try bridge.update(specification: HYMChartSpecificationDocument(specification: bad), preserveViewport: false))
        XCTAssertEqual(renderer.xAxisViewport, viewport)
        XCTAssertEqual(renderer.datum(series: 0, category: 0)?.seriesID, "source-1")
        bad = input; bad.series[0].appearance.valueColorZones?.zones = []
        XCTAssertThrowsError(try HYMChartSpecificationDocument(specification: bad))
        XCTAssertEqual(renderer.xAxisViewport, viewport)
        input.schemaVersion = 1
        for i in input.series.indices { input.series[i].appearance.valueColorZones = nil }
        try bridge.update(specification: HYMChartSpecificationDocument(specification: input), preserveViewport: false)
        view.layoutIfNeeded(); XCTAssertEqual(renderer.xAxisViewport, renderer.fullXAxisDomain)
        XCTAssertEqual(try ChartSpecification.decodeJSON(document.jsonData()).schemaVersion, 3)
    }
}
