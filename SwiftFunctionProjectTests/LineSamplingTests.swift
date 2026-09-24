import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class LineSamplingTests: XCTestCase {
    private var configuration: LineChartSampling {
        var c = LineChartSampling(); c.minimumVisiblePoints = 20; c.bucketWidth = 4; return c
    }
    private func select(_ values: [Double], range: ClosedRange<Double>? = nil, width: CGFloat = 100,
                        connect: Bool = false, config: LineChartSampling? = nil) -> LineRenderSelection {
        LineMinMaxSampler.select(values: values, connectNulls: connect,
            visibleRange: range ?? (0...Double(max(1, values.count - 1))), plotWidth: width, configuration: config ?? configuration)
    }
    private func model(_ values: [Double]) -> CartesianChartModel {
        .init(series: [.init(name: "Power", data: values, color: .systemBlue, id: "power")])
    }
    private func chart(_ m: CartesianChartModel, config: LineChartSampling? = LineChartSampling(),
                       theme custom: CartesianChartTheme? = nil) -> HYMChartView<LineChartRenderer> {
        var theme = custom ?? CartesianChartTheme()
        theme.lineSampling = config
        let view = HYMChartView<LineChartRenderer>(frame: CGRect(x: 0, y: 0, width: 390, height: 320))
        view.maximumZoomScale = 3000; view.minimumVisibleCategories = 1
        view.configure(model: m, theme: theme); view.layoutIfNeeded()
        return view
    }
    private func indices(_ renderer: LineChartRenderer, series: Int = 0) -> [Int] {
        (renderer.renderedIndices[series] ?? []).flatMap { $0 }
    }

    func testPreservesPeaksTroughsEndpointsOrderAndOriginalValues() {
        var values = Array(repeating: 5.0, count: 3000)
        values[1051] = 999; values[1052] = -400
        let result = select(values)
        let kept = result.segments.flatMap { $0 }
        XCTAssertTrue(result.isDense)
        XCTAssertEqual(kept.first, 0); XCTAssertEqual(kept.last, 2999)
        XCTAssertTrue(kept.contains(1051)); XCTAssertTrue(kept.contains(1052))
        XCTAssertEqual(kept, Array(Set(kept)).sorted())
        XCTAssertLessThanOrEqual(kept.count, 104)
        XCTAssertEqual(values[1051], 999)
    }

    func testEveryBucketPreservesItsActualExtremaInTimeOrder() {
        let values = (0..<1000).map { i in sin(Double(i) * 0.3) * Double(i % 31 + 1) }
        let kept = select(values, width: 200).segments.flatMap { $0 }
        // span 999 / (200 / 4) -> stride 20
        for start in stride(from: 0, to: 1000, by: 20) {
            let source = Array(start..<min(start + 20, 1000))
            let samples = kept.filter { source.contains($0) }.map { values[$0] }
            XCTAssertEqual(samples.min(), source.map { values[$0] }.min())
            XCTAssertEqual(samples.max(), source.map { values[$0] }.max())
            XCTAssertTrue(kept.contains(source.first!)); XCTAssertTrue(kept.contains(source.last!))
        }
    }

    func testMissingRunsAndSinglePointsDoNotBecomeConnected() {
        let values: [Double] = [1, 2, .nan, 9, .infinity, 4, 3, -.infinity, .nan, 7]
        XCTAssertEqual(select(values, width: 1).segments, [[0, 1], [3], [5, 6], [9]])
        XCTAssertEqual(select(values, connect: true).segments, [[0, 1, 3, 5, 6, 9]])
        XCTAssertTrue(select([.nan, .infinity]).segments.isEmpty)
        XCTAssertEqual(select([4]).segments, [[0]])
        XCTAssertTrue(select([]).segments.isEmpty)
    }

    func testClippingPreservesNeighboursWithoutBridgingMissingGaps() {
        let values = (0..<100).map(Double.init)
        XCTAssertEqual(select(values, range: 40.2...44.8).segments, [[40, 41, 42, 43, 44, 45]])
        var gap = Array(repeating: Double.nan, count: 100); gap[0] = 10; gap[99] = 20
        XCTAssertTrue(select(gap, range: 40...60).segments.isEmpty)
        XCTAssertEqual(select(gap, range: 40...60, connect: true).segments, [[0, 99]])
        XCTAssertTrue(select(values, range: 200...210).segments.isEmpty)
    }

    func testPanKeepsInteriorBucketAnchorsStable() {
        let values = (0..<2000).map { sin(Double($0)) }
        let first = select(values, range: 200...1000).segments.flatMap { $0 }.filter { (400..<800).contains($0) }
        let second = select(values, range: 201...1001).segments.flatMap { $0 }.filter { (400..<800).contains($0) }
        XCTAssertEqual(first, second)
    }

    func testThresholdZoomAndInvalidOptionsAreSafe() {
        let values = (0..<1000).map(Double.init)
        var c = configuration; c.minimumVisiblePoints = 2000
        XCTAssertFalse(select(values, config: c).isDense)
        c.minimumVisiblePoints = 20
        XCTAssertFalse(select(values, range: 400...410, config: c).isDense)
        XCTAssertEqual(select(values, range: 400...410).segments, [Array(399...411)])
        c.bucketWidth = .nan; c.minimumVisiblePoints = Int.min
        XCTAssertFalse(select(values, width: 0, config: c).isDense)
        XCTAssertFalse(select(values, width: .infinity, config: c).isDense)
        XCTAssertFalse(select(values, range: 3...3, config: c).isDense)
        XCTAssertGreaterThan(select(values, config: c).renderedPointCount, 0)
    }

    func testRendererKeepsModelAndDomainsWhileReducingLayers() {
        var values = (0..<3000).map { sin(Double($0) / 100) * 30 }
        values[1501] = 900; values[1522] = -600
        let source = model(values)
        let reduced = chart(source), original = chart(source, config: nil)
        let r = reduced.rendererForTesting, full = original.rendererForTesting
        XCTAssertEqual(r.currentModel!.series[0].data, values)
        XCTAssertEqual(r.currentViewport.yDomain, full.currentViewport.yDomain)
        XCTAssertLessThan(indices(r).count, 1000)
        XCTAssertTrue(indices(r).contains(1501)); XCTAssertTrue(indices(r).contains(1522))
        XCTAssertLessThan(r.seriesLayerSublayersForTesting().count, 5)
        XCTAssertGreaterThan(full.seriesLayerSublayersForTesting().count, 3000)
    }

    func testOmittedOriginalPointStillSupportsDirectSnapSharedAndTooltipHits() {
        let source = model((0..<3000).map { Double($0) })
        let v = chart(source); let r = v.rendererForTesting
        let kept = Set(indices(r))
        let omitted = (1000..<1500).first { !kept.contains($0) }!
        let point = r.testScreenPoint(series: 0, index: omitted)
        let direct = r.seriesHitTest(point) as? LineHitTarget
        XCTAssertEqual(direct?.index, omitted); XCTAssertEqual(direct?.value, Double(omitted))
        XCTAssertEqual(direct?.seriesID, "power")
        let snap = r.snapHit(at: point) as? LineHitTarget
        XCTAssertEqual(snap?.index, omitted); XCTAssertEqual(snap?.value, Double(omitted))
        XCTAssertNotNil(r.tooltipAnchor(for: snap!)); XCTAssertNotNil(r.hitFrame(for: direct!))
        let shared = r.sharedHit(at: point)?.target as? CartesianSharedHitTarget
        XCTAssertEqual(shared?.categoryIndex, omitted)
        XCTAssertEqual(shared?.entries.first?.value, Double(omitted))
    }

    func testDualAxesHiddenSeriesAndRaggedDataKeepOriginalIdentities() {
        var m = model((0..<2000).map { Double($0 % 100) })
        m.series.append(.init(name: "Voltage", data: (0..<1400).map { 5000 + Double($0) }, yAxisIndex: 1, id: "v"))
        m.secondaryYAxis = .init(kind: .value)
        let v = chart(m); let r = v.rendererForTesting
        let point = r.testScreenPoint(series: 1, index: 801)
        let hit = r.seriesHitTest(point) as? LineHitTarget
        XCTAssertEqual(hit?.seriesID, "v"); XCTAssertEqual(hit?.yAxisIndex, 1); XCTAssertEqual(hit?.value, 5801)
        v.setSeriesVisible(false, for: "v"); v.layoutIfNeeded()
        XCTAssertNil(r.renderedIndices[1]); XCTAssertFalse(r.denseSeries.contains(1))
        XCTAssertFalse(r.currentModel!.series[1].isVisible)
        XCTAssertTrue(indices(r).allSatisfy { $0 < 2000 })
    }

    func testDenseMarkerAndLabelPoliciesRestoreWhenZoomed() {
        let values = (0..<1000).map { Double($0 % 50) }
        var theme = CartesianChartTheme(); theme.showsDataLabels = true; theme.dataLabelMaxMarkCount = 3000
        let v = chart(model(values), config: configuration, theme: theme); let r = v.rendererForTesting
        XCTAssertTrue(r.denseSeries.contains(0))
        XCTAssertEqual(r.seriesLayerSublayersForTesting().count, 1)
        XCTAssertTrue((r.rootLayer.sublayers ?? []).compactMap { $0 as? CATextLayer }.isEmpty)
        v.showCategoryRange(400..<412)
        XCTAssertTrue(r.denseSeries.isEmpty)
        XCTAssertEqual(indices(r), Array(399...412))
        XCTAssertGreaterThan(r.seriesLayerSublayersForTesting().count, 1)
        XCTAssertFalse((r.rootLayer.sublayers ?? []).compactMap { $0 as? CATextLayer }.isEmpty)
        var c = configuration; c.hidesDenseMarkers = false; c.hidesDenseDataLabels = false
        theme.lineSampling = c
        v.update(theme: theme, viewportPolicy: .reset); v.layoutIfNeeded()
        XCTAssertGreaterThan(r.seriesLayerSublayersForTesting().count, 1)
        XCTAssertFalse((r.rootLayer.sublayers ?? []).compactMap { $0 as? CATextLayer }.isEmpty)
    }

    func testDenseIsolatedSamplesKeepTheirOnlyVisibleMarks() {
        let values = (0..<1200).map { $0.isMultiple(of: 2) ? Double($0 % 50 + 1) : Double.nan }
        let v = chart(model(values)); let r = v.rendererForTesting
        XCTAssertTrue(r.denseSeries.contains(0))
        XCTAssertEqual(r.renderedIndices[0]?.count, 600)
        XCTAssertGreaterThanOrEqual(r.seriesLayerSublayersForTesting().count, 600)
        XCTAssertTrue(indices(r).allSatisfy { $0.isMultiple(of: 2) })
    }

    func testUnsupportedConnectionsAndStackingPreserveFullRendering() {
        let values = (0..<100).map { Double($0 % 13) }
        var c = configuration; c.minimumVisiblePoints = 2; c.bucketWidth = 12
        for style in [LineConnectionStyle.smooth, .stepBefore, .stepAfter, .stepCenter] {
            var t = CartesianChartTheme(); t.lineConnectionStyle = style
            let v = chart(model(values), config: c, theme: t)
            XCTAssertEqual(indices(v.rendererForTesting), Array(values.indices))
            XCTAssertTrue(v.rendererForTesting.denseSeries.isEmpty)
        }
        for stack in [StackConfig.normal, .percent, .percentFixed(max: 500), .grouped(groupCount: 2)] {
            var m = model(values); m.stacking = stack
            let v = chart(m, config: c)
            XCTAssertEqual(indices(v.rendererForTesting), Array(values.indices))
            XCTAssertTrue(v.rendererForTesting.denseSeries.isEmpty)
        }
    }

    func testUpdateRebuildsSelectionAndRespectsDisconnectedAreaSegments() {
        var values = Array(repeating: 10.0, count: 1000); values[500] = .nan
        var m = model(values)
        var t = CartesianChartTheme(); t.showsArea = true
        let v = chart(m, config: configuration, theme: t); let r = v.rendererForTesting
        XCTAssertEqual(r.renderedIndices[0]?.count, 2)
        XCTAssertEqual(r.seriesLayerSublayersForTesting().filter { $0 is CAGradientLayer }.count, 1)
        m.series[0].data[501] = 1000; m.series[0].connectNulls = true
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(r.renderedIndices[0]?.count, 1)
        XCTAssertTrue(indices(r).contains(501))
        XCTAssertEqual((r.seriesHitTest(r.testScreenPoint(series: 0, index: 501)) as? LineHitTarget)?.value, 1000)
    }

    func testDemoSamplingFieldsBindAndCanDisable() {
        var optional: LineChartSampling?
        let b = Binding(get: { optional }, set: { optional = $0 })
        guard case .toggle(_, let enabled) = DemoThemeFields.lineSamplingItems(b)[0] else { return XCTFail() }
        enabled.wrappedValue = true
        let items = DemoThemeFields.lineSamplingItems(b)
        guard case .slider(_, let width, _, _) = items.first(where: { $0.label.contains("bucketWidth") }) else { return XCTFail() }
        width.wrappedValue = 6; XCTAssertEqual(optional?.bucketWidth, 6)
        guard case .toggle(_, let markers) = items.first(where: { $0.label.contains("hidesDenseMarkers") }) else { return XCTFail() }
        markers.wrappedValue = false; XCTAssertFalse(optional!.hidesDenseMarkers)
        enabled.wrappedValue = false; XCTAssertNil(optional)
        XCTAssertNil(CartesianChartTheme().lineSampling)
    }

    func testSamplingWorkloadAndSnapshots() {
        var rows = ["mode,points,series,layout_ms,rendered_points,series_layers"]
        for mode in ["raw", "minmax-markers", "minmax-dense"] {
            var values = (0..<3000).map { 50 + 30 * sin(Double($0) / 80) }
            values[1001] = 180; values[2001] = -100
            var m = model(values)
            m.series += [CartesianSeriesElement(name: "Other", data: values.map { $0 * 0.6 }, color: .systemOrange, id: "b")]
            var c = LineChartSampling(); c.hidesDenseMarkers = mode != "minmax-markers"
            let start = CACurrentMediaTime()
            let v = chart(m, config: mode == "raw" ? nil : c)
            let elapsed = (CACurrentMediaTime() - start) * 1000
            let r = v.rendererForTesting
            rows.append("\(mode),3000,2,\(elapsed),\(r.renderedIndices.values.flatMap { $0 }.flatMap { $0 }.count),\(r.seriesLayerSublayersForTesting().count)")
            if mode == "minmax-dense" {
                for detail in [false, true] {
                    if detail { v.showCategoryRange(990..<1014) }
                    v.backgroundColor = .white
                    let screenshot = UIGraphicsImageRenderer(bounds: v.bounds).image { v.layer.render(in: $0.cgContext) }
                    let a = XCTAttachment(image: screenshot); a.name = detail ? "line-minmax-detail" : "line-minmax-overview"; a.lifetime = .keepAlways; add(a)
                }
            }
        }
        let a = XCTAttachment(string: rows.joined(separator: "\n")); a.name = "line-minmax-layout-simulator.csv"; a.lifetime = .keepAlways; add(a)
    }
}
