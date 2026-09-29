import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class ColumnFixedLayoutTests: XCTestCase {
    private var fixed: CartesianChartTheme {
        CartesianChartTheme(columnSpacing: .init(columnWidth: 12, inner: 4, group: 16))
    }
    private func model(count: Int = 60) -> CartesianChartModel {
        .init(series: (0..<3).map { .init(name: "s\($0)", data: Array(repeating: Double(20 + $0 * 10), count: count), id: "\($0)") })
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
        model: CartesianChartModel? = nil, theme: CartesianChartTheme? = nil) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 390, height: 320))
        view.configure(model: model ?? self.model(), theme: theme ?? fixed)
        view.layoutIfNeeded()
        return view
    }
    private func rect<R: CartesianRendererBase<CartesianChartTheme>>(_ r: R, series: Int, index: Int) -> CGRect {
        let target = r.makeHitTarget(seriesIndex: series, categoryIndex: index, value: 20)!
        return r.hitFrame(for: target)!
    }

    func testSpacingOnlyKeepsExactPointsWhenZooming() {
        var t = fixed; t.columnSpacing?.columnWidth = nil
        let view = chart(ColumnChartRenderer.self, model: model(count: 3), theme: t)
        let r = view.rendererForTesting
        let a = rect(r, series: 0, index: 0), b = rect(r, series: 1, index: 0)
        XCTAssertEqual(b.minX - a.maxX, 4, accuracy: 0.001)
        XCTAssertEqual(rect(r, series: 0, index: 1).minX - rect(r, series: 2, index: 0).maxX, 16, accuracy: 0.001)
        view.showCategoryRange(0..<2)
        XCTAssertGreaterThan(rect(r, series: 0, index: 0).width, a.width)
        XCTAssertEqual(rect(r, series: 1, index: 0).minX - rect(r, series: 0, index: 0).maxX, 4, accuracy: 0.001)
    }

    func testFixedWidthStartsAtEarliestAndPansWithoutEnablingZoom() {
        let view = chart(ColumnChartRenderer.self); let r = view.rendererForTesting
        XCTAssertFalse(view.isZoomEnabled)
        XCTAssertTrue(view.gestureRecognizers!.compactMap { $0 as? UIPanGestureRecognizer }.first!.isEnabled)
        XCTAssertEqual(r.xAxisViewport.lowerBound, -0.5, accuracy: 0.001)
        XCTAssertLessThan(r.currentViewport.xSpan, 10)
        XCTAssertEqual(rect(r, series: 0, index: 0).width, 12, accuracy: 0.001)
        XCTAssertEqual(rect(r, series: 1, index: 0).minX - rect(r, series: 0, index: 0).maxX, 4, accuracy: 0.001)
        XCTAssertEqual(rect(r, series: 0, index: 1).minX - rect(r, series: 2, index: 0).maxX, 16, accuracy: 0.001)
        view.simulateViewportPan(deltaX: -120)
        XCTAssertGreaterThan(r.xAxisViewport.lowerBound, 0)
        XCTAssertEqual(rect(r, series: 0, index: 3).width, 12, accuracy: 0.001)
        r.zoomXAxis(factor: 2, anchorScreenX: r.currentPlotFrame.midX)
        XCTAssertEqual(rect(r, series: 0, index: 3).width, 12, accuracy: 0.001)
    }

    func testManualRangeUpdateResizeAndResetPreserveDimensions() {
        let view = chart(ColumnChartRenderer.self); let r = view.rendererForTesting
        view.showCategoryRange(20..<40)
        XCTAssertEqual(r.xAxisViewport.lowerBound, 19.5, accuracy: 0.001)
        var t = fixed; t.seriesColor = .red
        view.update(theme: t); view.layoutIfNeeded()
        XCTAssertEqual(r.xAxisViewport.lowerBound, 19.5, accuracy: 0.001)
        view.frame.size.width = 520; view.setNeedsLayout(); view.layoutIfNeeded()
        XCTAssertEqual(rect(r, series: 0, index: 20).width, 12, accuracy: 0.001)
        XCTAssertEqual(r.xAxisViewport.lowerBound, 19.5, accuracy: 0.001)
        view.resetViewport(); view.layoutIfNeeded()
        XCTAssertEqual(r.xAxisViewport.lowerBound, -0.5, accuracy: 0.001)
    }

    func testBarUsesVerticalScrollingAndFixedThickness() {
        let view = chart(BarChartRenderer.self); let r = view.rendererForTesting
        XCTAssertEqual(r.automaticCategoryScrollAxis, .y)
        XCTAssertEqual(r.yAxisViewport.lowerBound, -0.5, accuracy: 0.001)
        let a = rect(r, series: 0, index: 0), b = rect(r, series: 1, index: 0)
        XCTAssertEqual(a.height, 12, accuracy: 0.001)
        XCTAssertEqual(b.minY - a.maxY, 4, accuracy: 0.001)
        XCTAssertEqual(rect(r, series: 0, index: 1).minY - rect(r, series: 2, index: 0).maxY, 16, accuracy: 0.001)
        r.panYAxis(screenDeltaY: -120, allowsRubberBand: false)
        XCTAssertGreaterThan(r.yAxisViewport.lowerBound, 0)
        view.showCategoryRange(20..<30)
        XCTAssertEqual(r.yAxisViewport.lowerBound, 19.5, accuracy: 0.001)
        XCTAssertEqual(rect(r, series: 0, index: 20).height, 12, accuracy: 0.001)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertLessThan(labels.count, 20)
    }

    func testBarCategoryLabelsAndGridStayInsidePlotWhenScrolled() {
        var m = model()
        m.timeAxis = .init(start: Date(timeIntervalSince1970: 0), interval: 300)
        let view = chart(BarChartRenderer.self, model: m); let r = view.rendererForTesting
        for lower in [0, 10, 36] {
            view.showCategoryRange(lower..<(lower + 10))
            r.panYAxis(screenDeltaY: -17, allowsRubberBand: false)
            let labels = view.subviews.compactMap { $0 as? UILabel }.filter { $0.text?.contains(":") == true }
            XCTAssertFalse(labels.isEmpty)
            for label in labels {
                XCTAssertGreaterThanOrEqual(label.center.y, r.currentPlotFrame.minY)
                XCTAssertLessThanOrEqual(label.center.y, r.currentPlotFrame.maxY)
            }
            let grid = r.rootLayer.sublayers!.first as! CAShapeLayer
            XCTAssertGreaterThanOrEqual(grid.path!.boundingBoxOfPath.minY, r.currentPlotFrame.minY - 0.001)
            XCTAssertLessThanOrEqual(grid.path!.boundingBoxOfPath.maxY, r.currentPlotFrame.maxY + 0.001)
        }
    }

    func testSmallDatasetAndHiddenSeriesDoNotStretchFixedWidths() {
        var m = model(count: 2)
        let view = chart(ColumnChartRenderer.self, model: m); let r = view.rendererForTesting
        XCTAssertEqual(r.currentPlotFrame.width, 120, accuracy: 0.001)
        m.series[1].isVisible = false
        view.update(model: m); view.layoutIfNeeded()
        XCTAssertEqual(r.currentPlotFrame.width, 88, accuracy: 0.001)
        XCTAssertEqual(rect(r, series: 2, index: 0).minX - rect(r, series: 0, index: 0).maxX, 4, accuracy: 0.001)
        m.stacking = .normal
        view.update(model: m); view.layoutIfNeeded()
        XCTAssertEqual(r.currentPlotFrame.width, 56, accuracy: 0.001)
        XCTAssertEqual(rect(r, series: 0, index: 0).width, 12, accuracy: 0.001)
    }

    func testGapDoesNotHitAnyColumnAndBodyStillHitsOriginalValue() {
        let view = chart(ColumnChartRenderer.self); let r = view.rendererForTesting
        let a = rect(r, series: 0, index: 0)
        XCTAssertNil(r.seriesHitTest(CGPoint(x: a.maxX + 2, y: a.midY)))
        let hit = r.seriesHitTest(CGPoint(x: a.midX, y: a.midY)) as? ColumnHitTarget
        XCTAssertEqual(hit?.categoryIndex, 0); XCTAssertEqual(hit?.value, 20)
    }

    func testAggregationBudgetsFixedWidthAndSpacingAndPadsOnlyGeometry() {
        var m = model(count: 997)
        m.timeAxis = .init(start: Date(timeIntervalSince1970: 0), interval: 300)
        m.timeGrouping = .init(); m.timeGrouping?.preferredIntervals = []
        for i in m.series.indices { m.series[i].aggregation = .average }
        let plan = CartesianTimeGrouper.plan(model: m, theme: fixed, plotWidth: 300, visibleRange: -0.5...996.5)
        XCTAssertEqual(plan.samplesPerBucket, 200) // 5 组 × 60 pt
        let view = chart(ColumnChartRenderer.self, model: m); let r = view.rendererForTesting
        let prepared = r.currentModel!
        XCTAssertGreaterThan(prepared.timeBucketStride, 1)
        let last = prepared.bucketAnchor(for: 996)
        XCTAssertEqual(prepared.series[0].data.count, 997)
        let lastRect = rect(r, series: 0, index: last)
        XCTAssertEqual(lastRect.width, 12, accuracy: 0.001)
        let first = rect(r, series: 0, index: 0)
        XCTAssertEqual(first.width, 12, accuracy: 0.001)
        let lastHit = r.seriesHitTest(CGPoint(x: lastRect.midX, y: lastRect.midY)) as? ColumnHitTarget
        XCTAssertEqual(lastHit?.timeBucket?.sourceRange.upperBound, 997)
        view.showCategoryRange(400..<402)
        XCTAssertEqual(r.currentModel?.timeBucketStride, 1)
        XCTAssertEqual(rect(r, series: 0, index: 400).width, 12, accuracy: 0.001)
    }

    func testShortLastTimeBucketKeepsFixedWidthAndOriginalHitMetadata() {
        var m = model(count: 101)
        m.timeAxis = .init(start: Date(timeIntervalSince1970: 0), interval: 300)
        m.timeGrouping = .init(); m.timeGrouping?.preferredIntervals = [15000]
        for i in m.series.indices { m.series[i].aggregation = .average }
        let view = chart(ColumnChartRenderer.self, model: m); let r = view.rendererForTesting
        XCTAssertEqual(r.currentModel?.timeBucketStride, 50)
        XCTAssertEqual(r.currentModel?.categoryLayoutCount, 150)
        let last = rect(r, series: 2, index: 100)
        XCTAssertEqual(last.width, 12, accuracy: 0.001)
        let hit = r.seriesHitTest(CGPoint(x: last.midX, y: last.midY)) as? ColumnHitTarget
        XCTAssertEqual(hit?.categoryIndex, 100)
        XCTAssertEqual(hit?.timeBucket?.sourceRange, 100..<101)
        XCTAssertEqual(hit?.timeBucket?.expectedSampleCount, 1)
    }

    func testInvalidAndImpossibleSpacingIsSafeAndCanRecover() {
        var spacing = CartesianColumnSpacing(inner: -.infinity, group: .nan)
        XCTAssertEqual(spacing.inner, 0); XCTAssertEqual(spacing.group, 0)
        spacing.inner = -8; spacing.group = .infinity; spacing.columnWidth = .nan
        XCTAssertEqual(spacing.placement(slotWidth: 60, seriesCount: 3, seriesIndex: 0)?.width, 20)
        var t = fixed; t.columnSpacing?.columnWidth = nil; t.columnSpacing?.group = 500
        let view = chart(ColumnChartRenderer.self, theme: t); let r = view.rendererForTesting
        XCTAssertTrue(r.seriesLayer.sublayers?.isEmpty ?? true)
        XCTAssertNil(r.hitFrame(for: r.makeHitTarget(seriesIndex: 0, categoryIndex: 0, value: 20)!))
        view.update(theme: fixed); view.layoutIfNeeded()
        XCTAssertEqual(rect(r, series: 0, index: 0).width, 12, accuracy: 0.001)
    }

    func testTurningOffFixedModeRestoresLegacyLayoutAndGesturePolicy() {
        let view = chart(ColumnChartRenderer.self); let r = view.rendererForTesting
        var t = CartesianChartTheme(); t.columnWidthRatio = 0.5
        view.update(theme: t, viewportPolicy: .reset); view.layoutIfNeeded()
        XCTAssertNil(r.automaticCategoryScrollAxis)
        XCTAssertFalse(view.gestureRecognizers!.compactMap { $0 as? UIPanGestureRecognizer }.first!.isEnabled)
        XCTAssertEqual(r.currentViewport.xSpan, 60, accuracy: 0.001)
        XCTAssertEqual(rect(r, series: 0, index: 0).width, r.currentPlotFrame.width / 60 / 3 * 0.5, accuracy: 0.001)
    }

    func testDemoBindsFixedDimensionsAndHidesInactiveRatios() {
        var t = CartesianChartTheme()
        let binding = Binding(get: { t }, set: { t = $0 })
        guard case .toggle(_, let enabled) = DemoThemeFields.items(binding).first(where: { $0.label == "固定间距 columnSpacing（pt）" }) else { return XCTFail() }
        enabled.wrappedValue = true
        var fields = DemoThemeFields.items(binding)
        XCTAssertFalse(fields.contains { $0.label == "columnWidthRatio" })
        guard case .toggle(_, let widthEnabled) = fields.first(where: { $0.label == "固定柱宽 columnSpacing.columnWidth（pt）" }) else { return XCTFail() }
        widthEnabled.wrappedValue = true
        fields = DemoThemeFields.items(binding)
        for (label, value) in [("柱宽 columnSpacing.columnWidth（pt）", 18.0), ("同组柱间距 columnSpacing.inner（pt）", 6), ("两组间距 columnSpacing.group（pt）", 20)] {
            guard case .slider(_, let number, _, _) = fields.first(where: { $0.label == label }) else { return XCTFail() }
            number.wrappedValue = value
        }
        XCTAssertEqual(t.columnSpacing?.columnWidth, 18); XCTAssertEqual(t.columnSpacing?.inner, 6); XCTAssertEqual(t.columnSpacing?.group, 20)
        enabled.wrappedValue = false; XCTAssertNil(t.columnSpacing)
    }
}
