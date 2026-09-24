import XCTest
@testable import SwiftFunctionProject

@MainActor final class TimeGroupingCacheTests: XCTestCase {
    private func model(count: Int = 1000, reducer: CartesianAggregation = .average,
                       labels: ((Date) -> String)? = nil, cache: Bool = true) -> CartesianChartModel {
        var grouping = CartesianTimeGrouping(minimumColumnWidth: 4)
        grouping.preferredIntervals = [1, 2, 4, 8, 16, 32, 64, 128]
        grouping.isCacheEnabled = cache
        return CartesianChartModel(series: [.init(name: "A", data: (0..<count).map { Double($0 % 50 + 1) }, id: "a", aggregation: reducer)],
            yAxis: .init(kind: .value, min: 0, max: 100),
            timeAxis: .init(start: Date(timeIntervalSince1970: 0), interval: 1, labelFormatter: labels), timeGrouping: grouping)
    }
    private func chart(_ m: CartesianChartModel) -> HYMChartView<ColumnChartRenderer> {
        let v = HYMChartView<ColumnChartRenderer>(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        v.maximumZoomScale = 3000; v.minimumVisibleCategories = 1
        v.configure(model: m, theme: CartesianChartTheme()); v.layoutIfNeeded()
        return v
    }

    func testPanningReusesReducerLabelsAndStackedValues() {
        var calls = 0, labels = 0
        var m = model(reducer: .custom(name: "sum") { samples in calls += 1; return samples.reduce(0) { $0 + $1.value } }, labels: { _ in labels += 1; return "T" })
        m.stacking = .normal
        let v = chart(m); let r = v.rendererForTesting
        r.setXAxisViewport(200...400)
        let before = calls; let labelBefore = labels; let values = r.currentDrawValues
        for _ in 0..<10 { r.panXAxis(screenDeltaX: -2) }
        XCTAssertEqual(calls, before)
        XCTAssertEqual(labels, labelBefore)
        XCTAssertGreaterThan(r.renderDataCache.hits, 0)
        XCTAssertEqual(r.currentDrawValues.map { $0.filter(\.isFinite) }, values.map { $0.filter(\.isFinite) })
    }

    func testDisablingCacheRecalculatesOnEachGesture() {
        var calls = 0, labels = 0
        let m = model(reducer: .custom(name: "sum") { samples in calls += 1; return samples.reduce(0) { $0 + $1.value } }, labels: { _ in labels += 1; return "T" }, cache: false)
        let v = chart(m); let r = v.rendererForTesting
        r.setXAxisViewport(200...400)
        let before = calls; let labelBefore = labels
        r.panXAxis(screenDeltaX: -2)
        XCTAssertGreaterThan(calls, before)
        XCTAssertGreaterThan(labels, labelBefore)
        XCTAssertEqual(r.renderDataCache.count, 0)
    }

    func testUpdateInvalidatesDataReducerUnitTimeAndVisibility() {
        var m = model(reducer: .sum)
        let v = chart(m); let r = v.rendererForTesting
        r.setXAxisViewport(200...400)
        m.series[0].data = Array(repeating: 7, count: 1000)
        m.series[0].aggregation = .max; m.series[0].unit = "V"
        m.timeAxis?.start = Date(timeIntervalSince1970: 86400)
        m.timeAxis?.labelFormatter = { _ in "New" }
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(r.currentModel?.timeBucket(series: 0, category: 0)?.value, 7)
        XCTAssertEqual(r.currentModel?.timeBucket(series: 0, category: 0)?.unit, "V")
        XCTAssertEqual(r.currentModel?.timeBucket(series: 0, category: 0)?.interval.start, Date(timeIntervalSince1970: 86400))
        XCTAssertEqual(r.currentCategoryLabels.first, "New")
        v.setSeriesVisible(false, for: "a"); v.layoutIfNeeded()
        XCTAssertEqual(r.timeGroupingStatus, .noVisibleSeries)
        XCTAssertTrue(r.currentDrawValues.flatMap { $0 }.allSatisfy(\.isNaN))
        v.setSeriesVisible(true, for: "a"); v.layoutIfNeeded()
        XCTAssertEqual(r.currentModel?.timeBucket(series: 0, category: 0)?.value, 7)
    }

    func testExternalRenderInvalidatesCapturedReducerState() {
        var factor = 1.0
        let m = model(reducer: .custom(name: "mutable") { _ in factor })
        let v = chart(m); let r = v.rendererForTesting
        XCTAssertEqual(r.currentModel?.timeBucket(series: 0, category: 0)?.value, 1)
        factor = 9
        r.render(model: m, theme: CartesianChartTheme(), context: .init(bounds: v.bounds, center: CGPoint(x: 195, y: 150)))
        XCTAssertEqual(r.currentModel?.timeBucket(series: 0, category: 0)?.value, 9)
    }

    func testCacheIsBoundedAndThemeUpdateInvalidatesWidthPlan() {
        let v = chart(model()); let r = v.rendererForTesting
        for span in [800.0, 400, 200, 100, 50, 20] {
            r.setXAxisViewport(0...span)
            XCTAssertLessThanOrEqual(r.renderDataCache.count, 3)
        }
        r.setXAxisViewport(0...400)
        let old = r.currentModel!.timeBucketStride
        var theme = CartesianChartTheme(); theme.columnWidthRatio = 0.1
        v.update(theme: theme); v.layoutIfNeeded()
        XCTAssertGreaterThan(r.currentModel!.timeBucketStride, old)
        XCTAssertLessThanOrEqual(r.renderDataCache.count, 3)
    }

    func testHysteresisDelaysRefinementButCoarsensImmediately() {
        let m = model(); let v = chart(m); let r = v.rendererForTesting
        let capacity = floor(r.currentPlotFrame.width / (4 / 0.8))
        r.setXAxisViewport(0...(capacity * 1.1))
        XCTAssertEqual(r.currentModel!.timeBucketStride, 2)
        r.setXAxisViewport(0...(capacity * 0.95))
        XCTAssertEqual(r.currentModel!.timeBucketStride, 2, "near threshold retains coarse buckets")
        r.setXAxisViewport(0...(capacity * 0.7))
        XCTAssertEqual(r.currentModel!.timeBucketStride, 1, "sufficient headroom restores raw points")
        r.setXAxisViewport(0...(capacity * 1.1))
        XCTAssertEqual(r.currentModel!.timeBucketStride, 2, "width shortage coarsens immediately")
        var disabled = m; disabled.timeGrouping?.granularityHysteresis = 0
        v.update(model: disabled); v.layoutIfNeeded()
        r.setXAxisViewport(0...(capacity * 0.95))
        XCTAssertEqual(r.currentModel!.timeBucketStride, 1)
    }

    func testCachedAndUncachedPanningHaveIdenticalValuesAndHitMetadata() {
        let cached = chart(model()), uncached = chart(model(cache: false))
        for range in [100.0...300.0, 105...305, 200...240, 202...242] {
            cached.rendererForTesting.setXAxisViewport(range)
            uncached.rendererForTesting.setXAxisViewport(range)
            let a = cached.rendererForTesting, b = uncached.rendererForTesting
            XCTAssertEqual(a.currentModel!.timeBucketStride, b.currentModel!.timeBucketStride)
            XCTAssertEqual(a.currentDrawValues.map { $0.filter(\.isFinite) }, b.currentDrawValues.map { $0.filter(\.isFinite) })
            let point = CGPoint(x: a.currentPlotFrame.midX, y: a.currentPlotFrame.midY)
            let hitA = a.sharedHit(at: point)?.target as? CartesianSharedHitTarget
            let hitB = b.sharedHit(at: point)?.target as? CartesianSharedHitTarget
            XCTAssertEqual(hitA?.entries.first?.timeBucket?.sourceRange, hitB?.entries.first?.timeBucket?.sourceRange)
            XCTAssertEqual(hitA?.entries.first?.timeBucket?.value, hitB?.entries.first?.timeBucket?.value)
        }
    }

    func testGestureTimingComparison() {
        var rows = ["cache,points,series,pan_steps,total_ms,cache_hits,cache_misses"]
        for enabled in [false, true] {
            var m = model(count: 3000, cache: enabled)
            let source = m.series[0]
            m.series = (0..<6).map { i in var s = source; s.id = "s\(i)"; return s }
            let v = chart(m); let r = v.rendererForTesting
            r.setXAxisViewport(100...800)
            let start = CACurrentMediaTime()
            for _ in 0..<30 { r.panXAxis(screenDeltaX: -1) }
            rows.append("\(enabled),3000,6,30,\((CACurrentMediaTime() - start) * 1000),\(r.renderDataCache.hits),\(r.renderDataCache.misses)")
        }
        let attachment = XCTAttachment(string: rows.joined(separator: "\n"))
        attachment.name = "density-pan-cache-simulator.csv"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
