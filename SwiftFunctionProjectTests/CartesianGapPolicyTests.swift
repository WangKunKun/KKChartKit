import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class CartesianGapPolicyTests: XCTestCase {
    private var values: [Double] {
        DemoSeriesSettings.autoGapSample.split(separator: ",").map { Double($0) ?? .nan }
    }
    private let expected = [[0, 12], [25], [39]]
    private func segments(_ data: [Double], _ policy: CartesianGapPolicy,
                          interval: TimeInterval? = nil) -> [[Int]] {
        CartesianGapSegmenter.segments(values: data, policy: policy, sampleInterval: interval)
    }
    private func model(policy: CartesianGapPolicy? = .autoGap(maximumMissingPoints: 11)) -> CartesianChartModel {
        .init(series: [.init(name: "Power", data: values, id: "power", gapPolicy: policy)])
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
                _ model: CartesianChartModel, theme: CartesianChartTheme = .init()) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: .init(x: 0, y: 0, width: 600, height: 360))
        view.configure(model: model, theme: theme); view.layoutIfNeeded()
        return view
    }

    func testElevenTwelveThirteenMissingPointsHaveInclusiveBoundary() {
        XCTAssertEqual(values.count, 40)
        XCTAssertEqual(segments(values, .autoGap(maximumMissingPoints: 11)), expected)
        XCTAssertEqual(segments(values, .autoGap(maximumMissingPoints: 12)), [[0, 12, 25], [39]])
        XCTAssertEqual(segments(values, .autoGap(maximumMissingPoints: 13)), [[0, 12, 25, 39]])
    }

    func testLegacyConnectNullsAndExplicitPolicyPrecedence() {
        XCTAssertEqual(LineMinMaxSampler.segments(values: values, connectNulls: false), [[0], [12], [25], [39]])
        XCTAssertEqual(LineMinMaxSampler.segments(values: values, connectNulls: true), [[0, 12, 25, 39]])
        XCTAssertEqual(LineMinMaxSampler.segments(values: values, connectNulls: true, gapPolicy: .breakAll), [[0], [12], [25], [39]])
        XCTAssertEqual(LineMinMaxSampler.segments(values: values, connectNulls: false, gapPolicy: .connectAll), [[0, 12, 25, 39]])
    }

    func testEmptyLeadingTrailingNonFiniteAndZeroSamples() {
        for policy in [CartesianGapPolicy.breakAll, .connectAll, .autoGap(maximumMissingPoints: 1)] {
            XCTAssertTrue(segments([], policy).isEmpty)
            XCTAssertTrue(segments([.nan, .infinity, -.infinity], policy).isEmpty)
            XCTAssertEqual(segments([.nan, 0, .infinity], policy), [[1]])
        }
        let samples: [Double] = [.nan, 0, .infinity, 2, -.infinity, .nan, 3, .nan]
        XCTAssertEqual(segments(samples, .autoGap(maximumMissingPoints: 1)), [[1, 3], [6]])
        XCTAssertEqual(segments([0, 1, .nan, 2], .autoGap(maximumMissingPoints: -1)), [[0, 1], [3]])
        XCTAssertEqual(segments(values, .autoGap(maximumMissingPoints: Int.max)), [[0, 12, 25, 39]])
    }

    func testDurationCountsOnlyMissingSlotsAndIncludesEquality() {
        XCTAssertEqual(segments(values, .autoGapDuration(maximumMissingDuration: 3300), interval: 300), expected)
        XCTAssertEqual(segments(values, .autoGapDuration(maximumMissingDuration: 3600), interval: 300), [[0, 12, 25], [39]])
        XCTAssertEqual(segments(values, .autoGapDuration(maximumMissingDuration: 3299), interval: 300), [[0], [12], [25], [39]])
    }

    func testInvalidDurationOrTimeAxisBreaksOnlyAtMissingSlots() {
        let samples: [Double] = [1, 2, .nan, 3]
        for limit in [-1, Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(segments(samples, .autoGapDuration(maximumMissingDuration: limit), interval: 300), [[0, 1], [3]])
        }
        for interval: Double? in [nil, 0, -1, .nan, .infinity, Double.greatestFiniteMagnitude] {
            XCTAssertEqual(segments(samples, .autoGapDuration(maximumMissingDuration: 300), interval: interval), [[0, 1], [3]])
        }
        XCTAssertEqual(segments([1, .nan, .nan, 2], .autoGapDuration(maximumMissingDuration: .greatestFiniteMagnitude),
                                interval: .greatestFiniteMagnitude), [[0], [3]])
    }

    func testSegmentationNeverCreatesRemovesOrReordersFiniteSamples() {
        for limit in 0...13 {
            let input = (0..<500).map { i in i % 17 <= limit ? Double.nan : Double(i - 250) }
            let result = segments(input, .autoGap(maximumMissingPoints: limit))
            XCTAssertEqual(result.flatMap { $0 }, input.indices.filter { input[$0].isFinite })
            for run in result {
                XCTAssertFalse(run.isEmpty)
                for (left, right) in zip(run, run.dropFirst()) { XCTAssertLessThanOrEqual(right - left - 1, limit) }
            }
        }
    }

    func testSamplingKeepsLongGapsAndRealBoundaryNeighbors() {
        var samples = (0..<3000).map { sin(Double($0)) }
        for range in [100...110, 1000...1011, 2000...2012] { for index in range { samples[index] = .nan } }
        var configuration = LineChartSampling(); configuration.minimumVisiblePoints = 2; configuration.bucketWidth = 4
        func select(_ range: ClosedRange<Double>) -> LineRenderSelection {
            LineMinMaxSampler.select(values: samples, connectNulls: true, visibleRange: range,
                plotWidth: 140, configuration: configuration, gapPolicy: .autoGap(maximumMissingPoints: 11))
        }
        let selection = select(0...2999)
        XCTAssertTrue(selection.isDense); XCTAssertEqual(selection.segments.count, 3)
        let kept = selection.segments.flatMap { $0 }
        XCTAssertLessThan(kept.count, 1000); XCTAssertTrue(kept.allSatisfy { samples[$0].isFinite })
        for edge in [0, 999, 1012, 1999, 2013, 2999] { XCTAssertTrue(kept.contains(edge)) }
        XCTAssertEqual(select(104...105).segments, [[99, 111]])
        XCTAssertTrue(select(1003...1008).segments.isEmpty)
    }

    func testAllConnectionStylesAndAreaMasksUseSameSegments() throws {
        for connection in LineConnectionStyle.allCases {
            for reuse in [false, true] {
                var theme = CartesianChartTheme(); theme.lineConnectionStyle = connection
                theme.showsArea = true; theme.reusesRenderingObjects = reuse
                theme.areaGradientColors = [.systemBlue, .clear]
                let view = chart(LineChartRenderer.self, model(), theme: theme)
                let renderer = view.rendererForTesting
                XCTAssertEqual(renderer.renderedIndices[0], expected)
                let gradient = try XCTUnwrap(renderer.seriesLayerSublayersForTesting().compactMap { $0 as? CAGradientLayer }.first)
                let mask = try XCTUnwrap((gradient.mask as? CAShapeLayer)?.path)
                var moves = 0, closes = 0
                mask.applyWithBlock { element in
                    if element.pointee.type == .moveToPoint { moves += 1 }
                    if element.pointee.type == .closeSubpath { closes += 1 }
                }
                XCTAssertEqual(moves, 3); XCTAssertEqual(closes, 3)
                XCTAssertEqual(gradient.colors?.count, 2)
            }
        }
    }

    func testRendererDoesNotInventHitsOrChangeValuesAndDomains() {
        let source = model()
        let view = chart(LineChartRenderer.self, source)
        let renderer = view.rendererForTesting
        let legacy = chart(LineChartRenderer.self, model(policy: .connectAll))
        XCTAssertEqual(renderer.currentViewport.yDomain, legacy.rendererForTesting.currentViewport.yDomain)
        for index in values.indices {
            if values[index].isFinite { XCTAssertEqual(renderer.datum(series: 0, category: index)?.rawValue, values[index]) }
            else { XCTAssertNil(renderer.datum(series: 0, category: index)) }
        }
        let point = renderer.screenPoint(x: 6, y: 35)
        XCTAssertNil(renderer.seriesHitTest(point)); XCTAssertNil(renderer.sharedHit(at: point))
        XCTAssertNil(renderer.snapHit(at: point))
        XCTAssertEqual(renderer.currentModel?.series[0].data.count, 40)
        XCTAssertTrue(renderer.currentModel!.series[0].data[6].isNaN)
    }

    func testDurationRendererUsesValidTimeAxisAndUpdatesOnIntervalChange() {
        var source = model(policy: .autoGapDuration(maximumMissingDuration: 3300))
        source.timeAxis = .init(start: Date(timeIntervalSince1970: 0), interval: 300)
        let view = chart(LineChartRenderer.self, source)
        XCTAssertEqual(view.rendererForTesting.renderedIndices[0], expected)
        source.timeAxis?.interval = 600; view.update(model: source); view.layoutIfNeeded()
        XCTAssertEqual(view.rendererForTesting.renderedIndices[0], [[0], [12], [25], [39]])
        source.timeAxis?.interval = .nan; view.update(model: source); view.layoutIfNeeded()
        XCTAssertEqual(view.rendererForTesting.renderedIndices[0], [[0], [12], [25], [39]])
        source.timeAxis = nil; view.update(model: source); view.layoutIfNeeded()
        XCTAssertEqual(view.rendererForTesting.renderedIndices[0], [[0], [12], [25], [39]])
    }

    func testStackedAndPercentAreasKeepGapsAndMathematicalValues() {
        for stacking in [StackConfig.normal, .percent, .percentFixed(max: 100)] {
            var source = model(); source.stacking = stacking
            source.series.insert(.init(name: "Base", data: Array(repeating: 5, count: 40), id: "base"), at: 0)
            var theme = CartesianChartTheme(); theme.showsArea = true; theme.lineConnectionStyle = .smooth
            let view = chart(LineChartRenderer.self, source, theme: theme)
            XCTAssertEqual(view.rendererForTesting.renderedIndices[1], expected)
            XCTAssertEqual(view.rendererForTesting.datum(series: 1, category: 0)?.rawValue, 20)
            XCTAssertNil(view.rendererForTesting.datum(series: 1, category: 6))
        }
    }

    func testCombinedIndependentSeriesAndVisibilityRestorePolicy() {
        var source = model(); source.series[0].kind = .areaspline; source.series[0].yAxisIndex = 1
        source.secondaryYAxis = .init(kind: .value)
        source.series.append(.init(name: "Column", data: Array(repeating: 10, count: 40), id: "column", kind: .column))
        source.series.append(.init(name: "Ragged line", data: [1, .nan, 2], id: "ragged", kind: .line, gapPolicy: .connectAll))
        let view = chart(CombinedChartRenderer.self, source)
        XCTAssertEqual(view.rendererForTesting.lines.renderedIndices[0], expected)
        XCTAssertNil(view.rendererForTesting.lines.renderedIndices[1])
        XCTAssertEqual(view.rendererForTesting.lines.renderedIndices[2], [[0, 2]])
        view.setSeriesVisible(false, for: "power"); view.layoutIfNeeded()
        XCTAssertNil(view.rendererForTesting.lines.renderedIndices[0])
        view.setSeriesVisible(true, for: "power"); view.layoutIfNeeded()
        XCTAssertEqual(view.rendererForTesting.lines.renderedIndices[0], expected)
    }

    func testPolicyUpdateAndResetRemoveOldSegmentsWithAndWithoutReuse() {
        for reuse in [false, true] {
            var source = model(); let theme = CartesianChartTheme(reusesRenderingObjects: reuse)
            let view = chart(LineChartRenderer.self, source, theme: theme)
            source.series[0].gapPolicy = .connectAll; view.update(model: source); view.layoutIfNeeded()
            XCTAssertEqual(view.rendererForTesting.renderedIndices[0], [[0, 12, 25, 39]])
            source.series[0].gapPolicy = nil; view.update(model: source); view.layoutIfNeeded()
            XCTAssertEqual(view.rendererForTesting.renderedIndices[0], [[0], [12], [25], [39]])
            source.series[0].data = []; view.update(model: source); view.layoutIfNeeded()
            XCTAssertTrue(view.rendererForTesting.renderedIndices.isEmpty)
            XCTAssertTrue(view.rendererForTesting.seriesLayerSublayersForTesting().isEmpty)
            view.update(model: model()); view.layoutIfNeeded()
            XCTAssertEqual(view.rendererForTesting.renderedIndices[0], expected)
        }
    }

    func testObjectiveCPolicyAndTimeAxisAreSnapshotsAndKeepNSNullSlots() throws {
        let series = HYMCartesianSeries(); series.identifier = "oc"
        series.data = values.map { $0.isFinite ? NSNumber(value: $0) as Any : NSNull() }
        series.gapPolicy = HYMCartesianGapPolicy()
        let source = HYMCartesianModel(); source.series = [series]
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: .init(x: 0, y: 0, width: 600, height: 360))
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        XCTAssertEqual(view.rendererForTesting.renderedIndices[0], expected)
        series.gapPolicy?.mode = .connectAll
        XCTAssertEqual(view.rendererForTesting.currentModel?.series[0].gapPolicy, .autoGap(maximumMissingPoints: 11))
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        XCTAssertEqual(view.rendererForTesting.renderedIndices[0], [[0, 12, 25, 39]])
        series.gapPolicy?.mode = .autoGapDuration; source.samplingStart = Date(timeIntervalSince1970: 0)
        source.samplingInterval = 300
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        XCTAssertEqual(view.rendererForTesting.renderedIndices[0], expected)
        XCTAssertEqual(view.rendererForTesting.currentModel?.timeAxis?.interval, 300)
        XCTAssertTrue(view.rendererForTesting.currentModel!.series[0].data[1].isNaN)
        series.gapPolicy = nil; series.connectNulls = true
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        XCTAssertEqual(view.rendererForTesting.renderedIndices[0], [[0, 12, 25, 39]])
    }

    func testDemoControlsWriteActualPolicyAndLegacyReset() {
        var settings = DemoSeriesSettings(name: "Gap test")
        let binding = Binding(get: { settings }, set: { settings = $0 })
        for kind in [CartesianDemoKind.line, .combined] {
            let items = DemoSeriesSettings.items(binding, kind: kind)
            guard case .picker(_, let selection, _) = items.first(where: { $0.label == "缺测策略 autoGap" }) else { return XCTFail() }
            selection.wrappedValue = "按空点数量"
            let updated = DemoSeriesSettings.items(binding, kind: kind)
            guard case .slider(_, let limit, _, _) = updated.first(where: { $0.label == "缺测点数上限（含等号）" }) else { return XCTFail() }
            limit.wrappedValue = 12
            XCTAssertEqual(settings.gapPolicy, .autoGap(maximumMissingPoints: 12))
            selection.wrappedValue = "按缺测时长"
            XCTAssertEqual(settings.gapPolicy, .autoGapDuration(maximumMissingDuration: 3300))
            selection.wrappedValue = "跟随跨空值连线"
            XCTAssertNil(settings.gapPolicy)
        }
        XCTAssertFalse(DemoSeriesSettings.items(binding, kind: .column).contains { $0.label == "缺测策略 autoGap" })
    }
}
