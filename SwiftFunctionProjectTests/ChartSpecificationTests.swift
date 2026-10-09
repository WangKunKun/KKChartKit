import XCTest
@testable import SwiftFunctionProject

final class ChartSpecificationTests: XCTestCase {
    private func fixture() -> ChartSpecification {
        .init(id: "chart", domain: .categories([.init(id: "am", label: "相同文字"), .init(id: "pm", label: "相同文字")]),
              valueAxes: [.init(id: "power")],
              series: [.init(id: "solar", name: "光伏", mark: .area, valueAxisID: "power", samples: [
                .init(id: "sample-1", coordinate: .category("am"), value: -40, metadata: ["meterID": "M1"]),
                .init(id: "sample-2", coordinate: .category("pm"), value: nil)
              ], groupID: "energy", stackID: "supply", unit: "W")],
              groups: [.init(id: "energy", name: "能源")], stacking: .sum)
    }

    func testRoundTripKeepsIdentityMissingSignAndPresentationWithoutUIKit() throws {
        var source = fixture()
        source.series[0].appearance.areaFill = .verticalGradient(top: .init(red: 1, green: 0, blue: 0, alpha: 0.4),
                                                               bottom: .init(red: 1, green: 0, blue: 0, alpha: 0))
        source.series[0].valuePresentation.showsAbsoluteValue = true
        source.series[0].valuePresentation.scale = .engineering
        source.series[0].valuePresentation.localeIdentifier = "en_US"
        let data = try source.jsonData()
        XCTAssertEqual(try ChartSpecification.decodeJSON(data), source)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rows = try XCTUnwrap(object["series"] as? [[String: Any]])
        let samples = try XCTUnwrap(rows[0]["samples"] as? [[String: Any]])
        XCTAssertTrue(samples[1]["value"] is NSNull)
        XCTAssertEqual(samples[0]["value"] as? Double, -40)
    }

    func testJSONContractUsesNamedDiscriminatorsAndRejectsUnknownEnumValues() throws {
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        let stacking: [ChartStackingPolicy] = [.none, .sum, .percentOfAbsoluteTotal, .percentOfFixedTotal(1000)]
        XCTAssertEqual(try decoder.decode([ChartStackingPolicy].self, from: encoder.encode(stacking)), stacking)
        let gaps: [ChartMissingValuePolicy] = [.breakPath, .connect, .connectUpTo(missingCategoryCount: 11)]
        XCTAssertEqual(try decoder.decode([ChartMissingValuePolicy].self, from: encoder.encode(gaps)), gaps)
        let fills: [ChartAreaFill] = [.solid(.init(red: 1, green: 0, blue: 0)),
                                     .verticalGradient(top: .init(red: 1, green: 0, blue: 0), bottom: .init(red: 1, green: 0, blue: 0, alpha: 0))]
        XCTAssertEqual(try decoder.decode([ChartAreaFill].self, from: encoder.encode(fills)), fills)
        let data = try fixture().jsonData()
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("\"_0\""))
        let domain = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(fixture().domain)) as? [String: Any])
        XCTAssertEqual(domain["kind"] as? String, "category")
        XCTAssertEqual((domain["categories"] as? [[String: String]])?.first?["id"], "am")
        XCTAssertThrowsError(try decoder.decode(ChartStackingPolicy.self, from: Data(#"{"mode":"vendor-specific"}"#.utf8)))
        XCTAssertThrowsError(try decoder.decode(ChartCoordinate.self, from: Data(#"{"kind":"time","value":1000}"#.utf8)))
    }

    func testDuplicateLabelsAreValidButDuplicateIDsAndBlankIDsAreRejected() throws {
        let valid = fixture()
        try valid.validate()
        var invalid = valid
        invalid.series.append(invalid.series[0]); invalid.groups[0].id = "  "
        invalid.valueAxes.append(invalid.valueAxes[0])
        invalid.series[0].samples.append(invalid.series[0].samples[0])
        let paths = Set(invalid.validationIssues().map(\.path))
        XCTAssertTrue(paths.contains("series[1].id"))
        XCTAssertTrue(paths.contains("groups[0].id"))
        XCTAssertTrue(paths.contains("valueAxes[1].id"))
        XCTAssertTrue(paths.contains("series[0].samples[2].id"))
        XCTAssertThrowsError(try invalid.jsonData())
    }

    func testUnknownReferencesReportFieldPaths() {
        var source = fixture()
        source.series[0].valueAxisID = "missing-axis"
        source.series[0].groupID = "missing-group"
        source.series[0].samples[0].coordinate = .category("missing-category")
        let paths = Set(source.validationIssues().map(\.path))
        XCTAssertTrue(paths.contains("series[0].valueAxisID"))
        XCTAssertTrue(paths.contains("series[0].groupID"))
        XCTAssertTrue(paths.contains("series[0].samples[0].coordinate"))
    }

    func testNonFiniteDataIsAnErrorAndZeroIsNotMissing() throws {
        for value in [Double.nan, .infinity, -.infinity] {
            var source = fixture(); source.series[0].samples[0].value = value
            XCTAssertTrue(source.validationIssues().contains { $0.path == "series[0].samples[0].value" })
            XCTAssertThrowsError(try source.jsonData())
        }
        var source = fixture(); source.series[0].samples[0].value = 0
        XCTAssertEqual(try ChartSpecification.decodeJSON(source.jsonData()).series[0].samples[0].value, 0)
    }

    func testInputStyleRangeAndLegacyPrecisionAreNotSilentlyClamped() {
        var source = fixture()
        source.valueAxes[0].minimum = 5; source.valueAxes[0].maximum = 5
        source.domainAppearance.labelFontSize = 0
        source.series[0].appearance.color = .init(red: 2, green: 0, blue: 0)
        source.series[0].appearance.lineWidth = -.infinity
        source.series[0].valuePresentation.maximumFractionDigits = 100
        source.series[0].missingValues = .connectUpTo(missingCategoryCount: -1)
        source.stacking = .percentOfFixedTotal(0)
        XCTAssertEqual(source.validationIssues().count, 7)
    }

    func testNumericAndTimeCoordinatesKeepUnitsAndRequireMatchingIncreasingDomain() throws {
        for domain in [ChartDomain.numeric, .time] {
            var source = fixture(); source.domain = domain
            source.series[0].samples = [1.0, 9.5, 101.25].enumerated().map { index, value in
                .init(id: "p-\(index)", coordinate: domain == .numeric ? .number(value) : .unixSeconds(value), value: Double(index))
            }
            XCTAssertEqual(try ChartSpecification.decodeJSON(source.jsonData()), source)
            source.series[0].samples.swapAt(0, 2)
            XCTAssertFalse(source.validationIssues().isEmpty)
            source.series[0].samples[0].coordinate = .category("am")
            XCTAssertTrue(source.validationIssues().contains { $0.message.contains("类型") })
        }
    }

    func testStackingDoesNotConfuseBusinessGroupsUnitsOrIndependentSeries() throws {
        var source = fixture()
        var other = source.series[0]; other.id = "battery"; other.unit = "Wh"
        source.series.append(other)
        XCTAssertTrue(source.validationIssues().contains { $0.path == "series[1].unit" })
        source.series[1].stackID = nil
        try source.validate()
        source.series[1].stackID = "other-stack"
        try source.validate()
        source.series[1].stackID = "supply"; source.stacking = .none
        try source.validate()
    }

    func testUnsupportedSchemaIsRejectedOnDecodeAndNSErrorCarriesDiagnostics() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture().jsonData()) as? [String: Any])
        object["schemaVersion"] = ChartSpecification.latestSchemaVersion + 1
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try ChartSpecification.decodeJSON(data)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, ChartSpecificationError.errorDomain)
            XCTAssertTrue((nsError.userInfo["issues"] as? [[String: String]])?.contains { $0["path"] == "schemaVersion" } == true)
        }
    }

    func testSnapshotsDoNotShareMutableSourceData() throws {
        var original = fixture()
        let document = try HYMChartSpecificationDocument(specification: original)
        original.series[0].samples[0].value = 999
        original.series[0].name = "已修改"
        XCTAssertEqual(document.specification.series[0].samples[0].value, -40)
        XCTAssertEqual(document.specification.series[0].name, "光伏")
    }

    func testAdapterContractAllowsAnotherBackendWithoutChangingModel() throws {
        struct RecordingAdapter: ChartAdapter {
            let backendIdentifier = "test-recording-backend"
            func diagnostics(for specification: ChartSpecification) -> [ChartSpecificationIssue] { specification.validationIssues() }
            func makeConfiguration(from specification: ChartSpecification) throws -> [ChartSample] {
                try specification.validate(); return specification.series.flatMap(\.samples)
            }
        }
        let source = fixture()
        XCTAssertEqual(try RecordingAdapter().makeConfiguration(from: source), source.series[0].samples)
    }
}

@MainActor final class HYMChartsSpecificationAdapterTests: XCTestCase {
    private func fixture() -> ChartSpecification { ChartSpecificationDemoSettings().specification(kind: .line) }

    func testSparseUnorderedSamplesAlignByCategoryIDWithoutInventingIdentities() throws {
        var source = fixture()
        source.series[0].samples.remove(at: 1)
        source.series[0].samples.reverse()
        let configuration = try HYMChartsSpecificationAdapter().makeConfiguration(from: source)
        XCTAssertEqual(configuration.model.series[0].data[0], 40)
        XCTAssertTrue(configuration.model.series[0].data[1].isNaN)
        XCTAssertNil(configuration.sourceSample(seriesID: "source-0", categoryIndex: 1))
        XCTAssertEqual(configuration.sourceSample(seriesID: "source-0", categoryIndex: 2)?.id, "sample-0-2")
        XCTAssertNil(configuration.sourceSample(seriesID: "source-0", categoryIndex: 2)?.value)
        XCTAssertEqual(configuration.sourceSample(seriesID: "source-0", categoryIndex: 0)?.metadata["device"], "demo-0")
        XCTAssertNil(configuration.sourceSample(seriesID: "source-0", categoryIndex: -1))
        XCTAssertEqual(configuration.source, source)
    }

    func testSeriesAndAxisReorderingRetainStableBindings() throws {
        var source = fixture()
        source.valueAxes.append(.init(id: "temperature"))
        source.series[1].valueAxisID = "temperature"; source.series[1].name = "改名"
        source.series.swapAt(0, 1); source.valueAxes.swapAt(0, 1)
        let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: source)
        XCTAssertEqual(output.model.series[0].id, "source-1")
        XCTAssertEqual(output.model.series[0].yAxisIndex, 0)
        XCTAssertEqual(output.model.series[1].yAxisIndex, 1)
        XCTAssertEqual(output.sourceSample(seriesID: "source-1", categoryIndex: 0)?.id, "sample-1-0")
    }

    func testSignedPercentUsesAbsoluteDenominatorAndLeavesRawValuesUnchanged() throws {
        var source = fixture(); source.stacking = .percentOfAbsoluteTotal
        source.series[0].samples[0].value = 60; source.series[1].samples[0].value = -40
        source.series[0].valuePresentation.showsAbsoluteValue = true
        let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: source)
        XCTAssertEqual(output.model.stackedDrawValues[0][0], 60, accuracy: 1e-10)
        XCTAssertEqual(output.model.stackedDrawValues[1][0], -40, accuracy: 1e-10)
        XCTAssertEqual(output.model.series[1].data[0], -40)
        source.series[1].stackID = nil
        let independent = try HYMChartsSpecificationAdapter().makeConfiguration(from: source)
        XCTAssertFalse(independent.model.series[1].participatesInStack)
        XCTAssertEqual(independent.model.stackedDrawValues[1][0], -40)
    }

    func testStyleAndGapConversionPreserveExplicitChoices() throws {
        var source = fixture()
        source.series[0].interpolation = .stepBefore
        source.series[0].missingValues = .connectUpTo(missingCategoryCount: 1)
        source.series[0].appearance.marker = ChartMarkerShape.none
        source.series[0].appearance.strokePattern = .dotted
        let color = ChartRGBA(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        source.series[0].appearance.areaFill = .solid(color)
        source.showsLegend = false
        let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: source)
        let series = output.model.series[0]
        XCTAssertEqual(series.style.lineConnectionStyle, .stepBefore)
        XCTAssertEqual(series.gapPolicy, .autoGap(maximumMissingPoints: 1))
        XCTAssertEqual(series.style.showsPoints, false)
        XCTAssertEqual(series.lineDashStyle, .dot)
        XCTAssertEqual(try XCTUnwrap(series.style.areaGradientColors?.first).cgColor.alpha, 0.4, accuracy: 1e-6)
        XCTAssertFalse(output.theme.legend.isEnabled)
    }

    func testUnsupportedCoordinatesAxesAndIgnoredBarStylesAreRejected() throws {
        var settings = ChartSpecificationDemoSettings(); settings.numericDomain = true
        let numeric = settings.specification(kind: .line)
        try numeric.validate()
        XCTAssertThrowsError(try HYMChartsSpecificationAdapter().makeConfiguration(from: numeric))
        settings.numericDomain = false; settings.reversedAxis = true
        XCTAssertTrue(HYMChartsSpecificationAdapter().diagnostics(for: settings.specification(kind: .line)).contains { $0.path == "valueAxes[0].isReversed" })
        var bar = fixture(); bar.orientation = .horizontal
        XCTAssertThrowsError(try HYMChartsSpecificationAdapter().makeConfiguration(from: bar))
        bar = ChartSpecificationDemoSettings().specification(kind: .bar)
        bar.valueAxes.append(.init(id: "unused-secondary"))
        bar.series[0].appearance.marker = .circle
        let paths = Set(HYMChartsSpecificationAdapter().diagnostics(for: bar).map(\.path))
        XCTAssertTrue(paths.contains("valueAxes")); XCTAssertTrue(paths.contains("series[0].appearance.marker"))
    }

    func testAxisGridIntentControlsActualScreenDirectionsAndRejectsSecondaryOnlyGrid() throws {
        for kind in [CartesianDemoKind.line, .bar] {
            for valueGrid in [false, true] {
                for domainGrid in [false, true] {
                    var source = ChartSpecificationDemoSettings().specification(kind: kind)
                    source.valueAxes[0].appearance.showsGridlines = valueGrid
                    source.domainAppearance.showsGridlines = domainGrid
                    let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: source)
                    let layer = GridRenderer.makeGridLayer(valueTicks: [1], categoryCount: 1,
                        viewport: .init(xMin: -0.5, xMax: 2, yMin: -0.5, yMax: 2),
                        plotFrame: CGRect(x: 0, y: 0, width: 100, height: 100), theme: output.theme,
                        isHorizontalValueAxis: kind == .bar)
                    let path = try XCTUnwrap(layer.path)
                    XCTAssertEqual(path.isEmpty, !valueGrid && !domainGrid)
                    if valueGrid != domainGrid {
                        let horizontal = kind == .bar ? domainGrid : valueGrid
                        XCTAssertEqual(path.boundingBox.width, horizontal ? 100 : 0, accuracy: 0.01)
                        XCTAssertEqual(path.boundingBox.height, horizontal ? 0 : 100, accuracy: 0.01)
                    }
                }
            }
        }
        var source = fixture()
        var secondaryStyle = ChartAxisAppearance(); secondaryStyle.showsGridlines = true
        source.valueAxes.append(.init(id: "secondary", appearance: secondaryStyle))
        XCTAssertThrowsError(try HYMChartsSpecificationAdapter().makeConfiguration(from: source))
        source.valueAxes[0].appearance.showsGridlines = true
        XCTAssertNoThrow(try HYMChartsSpecificationAdapter().makeConfiguration(from: source))
    }

    func testAllExistingDemoKindsCompileRenderAndPreserveRawHitData() throws {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ renderer: R.Type, _ output: HYMChartsSpecificationConfiguration) throws {
            let chart = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
            chart.configure(model: output.model, theme: output.theme); chart.layoutIfNeeded()
            let hit = try XCTUnwrap(chart.rendererForTesting.datum(series: 0, category: 0))
            XCTAssertEqual(hit.rawValue, 40)
            XCTAssertEqual(output.sourceSample(seriesID: hit.seriesID, categoryIndex: hit.categoryIndex)?.id, "sample-0-0")
        }
        for kind in [CartesianDemoKind.line, .column, .bar, .combined] {
            let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: ChartSpecificationDemoSettings().specification(kind: kind))
            switch kind {
            case .line: XCTAssertEqual(output.kind, .line); try check(LineChartRenderer.self, output)
            case .column: XCTAssertEqual(output.kind, .column); try check(ColumnChartRenderer.self, output)
            case .bar: XCTAssertEqual(output.kind, .bar); try check(BarChartRenderer.self, output)
            case .combined: XCTAssertEqual(output.kind, .combined); try check(CombinedChartRenderer.self, output)
            }
        }
    }

    func testObjectiveCDocumentAndBridgeKeepLastChartWhenUpdateFails() throws {
        let source = fixture()
        let document = try HYMChartSpecificationDocument(jsonData: source.jsonData())
        XCTAssertEqual(document.specification, source)
        XCTAssertEqual(document.sampleIdentifier(seriesID: "source-0", categoryIndex: 3), "sample-0-3")
        XCTAssertTrue(try document.makeNativeBridge(frame: .zero).chartView is HYMChartView<LineChartRenderer>)
        let bridge = HYMCartesianChartViewBridge(kind: try document.nativeChartKind(), frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        try bridge.configure(specification: document); bridge.chartView.layoutIfNeeded()
        let chart = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        var invalid = source; invalid.valueAxes[0].isReversed = true
        XCTAssertThrowsError(try bridge.update(specification: HYMChartSpecificationDocument(specification: invalid), preserveViewport: true))
        XCTAssertEqual(chart.rendererForTesting.datum(series: 0, category: 0)?.rawValue, 40)
        var updated = source; updated.series[0].samples[0].value = 99
        try bridge.update(specification: HYMChartSpecificationDocument(specification: updated), preserveViewport: true)
        bridge.chartView.layoutIfNeeded()
        XCTAssertEqual(chart.rendererForTesting.datum(series: 0, category: 0)?.rawValue, 99)
        XCTAssertEqual(try ChartSpecification.decodeJSON(document.jsonData()), source)
    }

    func testBridgeRejectsWrongRendererAndEmptyDataIsSafe() throws {
        let document = try HYMChartSpecificationDocument(specification: fixture())
        let bridge = HYMCartesianChartViewBridge(kind: .column, frame: .zero)
        XCTAssertThrowsError(try bridge.configure(specification: document))
        var empty = fixture(); empty.domain = .categories([]); empty.series = []
        let configuration = try HYMChartsSpecificationAdapter().makeConfiguration(from: empty)
        XCTAssertEqual(configuration.model.maxPointCount, 0)
        empty.valueAxes = []
        XCTAssertThrowsError(try HYMChartsSpecificationAdapter().makeConfiguration(from: empty))
    }
}
