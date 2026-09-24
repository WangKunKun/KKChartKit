import XCTest
import SwiftUI
@testable import SwiftFunctionProject

final class TimeGroupingTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_179_200)
    private func model(_ data: [[Double]], reducers: [CartesianAggregation] = [.sum]) -> CartesianChartModel {
        CartesianChartModel(series: data.enumerated().map { i, values in
            .init(name: "Series \(i)", data: values, color: [.systemBlue, .systemOrange, .systemGreen][i % 3],
                  id: "s\(i)", aggregation: reducers[i % reducers.count], unit: i == 0 ? "kWh" : "kW")
        }, timeAxis: .init(start: start, interval: 300, timeZone: TimeZone(secondsFromGMT: 0)!),
           timeGrouping: .init())
    }
    private func grouped(_ model: CartesianChartModel, width: CGFloat = 1,
                         range: ClosedRange<Double>? = nil) -> CartesianTimeGroupingResult {
        CartesianTimeGrouper.group(model: model, theme: CartesianChartTheme(), plotWidth: width,
            visibleRange: range ?? (-0.5...Double(model.maxPointCount) - 0.5))
    }
    private func chart(_ model: CartesianChartModel, width: CGFloat = 390) -> HYMChartView<ColumnChartRenderer> {
        let view = HYMChartView<ColumnChartRenderer>(frame: CGRect(x: 0, y: 0, width: width, height: 340))
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = true
        view.configure(model: model, theme: theme)
        view.layoutIfNeeded()
        return view
    }

    func testTimeAxisUsesDatesForMultiDayDataAndHonorsFormatter() {
        var time = CartesianTimeAxis(start: start, interval: 300, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(time.labels(count: 288)[0].count, 5)
        XCTAssertGreaterThan(time.labels(count: 3000)[0].count, 5)
        time.labelFormatter = { _ in "custom" }
        XCTAssertEqual(time.labels(count: 3), ["custom", "custom", "custom"])
        let view = chart(model([Array(repeating: 1, count: 3000)]))
        let labels = view.subviews.compactMap { $0 as? UILabel }.filter { $0.text?.contains(":") == true }
        XCTAssertFalse(labels.isEmpty)
        for label in labels {
            XCTAssertGreaterThanOrEqual(label.frame.minX, view.bounds.minX)
            XCTAssertLessThanOrEqual(label.frame.maxX, view.bounds.maxX)
        }
    }

    func testDenseTimeLabelsKeepGapWhenZoomedToFractionalCategoryWindow() {
        var m = model([Array(repeating: 10, count: 3000)])
        m.timeAxis?.interval = 86400 / 3000
        let v = chart(m)
        v.rendererForTesting.setXAxisViewport(2975.5...2999.5)
        let labels = v.subviews.compactMap { $0 as? UILabel }.filter { $0.text?.contains(":") == true }.sorted { $0.frame.minX < $1.frame.minX }
        XCTAssertGreaterThan(labels.count, 2)
        for (left, right) in zip(labels, labels.dropFirst()) {
            XCTAssertGreaterThanOrEqual(right.frame.minX - left.frame.maxX, 3.99)
        }
    }

    func testIndependentReducersShareExactIntervalsAndSourceRanges() {
        let data = model(Array(repeating: [2, 4, 6], count: 5), reducers: [.sum, .average, .min, .max, .last])
        let result = grouped(data)
        XCTAssertEqual(result.samplesPerBucket, 3)
        XCTAssertEqual(result.buckets.map { $0[0].value! }, [12, 4, 2, 6, 6])
        for series in result.buckets {
            XCTAssertEqual(series[0].sourceRange, 0..<3)
            XCTAssertEqual(series[0].interval, DateInterval(start: start, duration: 900))
            XCTAssertEqual(series[0].validSampleCount, 3)
        }
        XCTAssertEqual(data.series[0].data, [2, 4, 6], "source is immutable")
    }

    func testMissingAndRaggedDataRetainCoverageWithoutInventingZero() {
        let result = grouped(model([[1, .nan, .infinity, 3], [4], [.nan, .nan]], reducers: [.average]))
        XCTAssertEqual(result.buckets[0][0].value, 2)
        XCTAssertEqual(result.buckets[0][0].coverage, 0.5)
        XCTAssertEqual(result.buckets[1][0].value, 4)
        XCTAssertEqual(result.buckets[1][0].coverage, 0.25)
        XCTAssertNil(result.buckets[2][0].value)
        XCTAssertEqual(result.buckets[2][0].validSampleCount, 0)
        XCTAssertTrue(result.model.series[2].data[0].isNaN)
    }

    func testCustomReceivesOriginalIndicesAndOnlyFiniteValues() {
        var calls = 0
        let custom = CartesianAggregation.custom(name: "范围") { samples in
            calls += 1
            XCTAssertEqual(samples.map(\.sourceIndex), [0, 2])
            XCTAssertEqual(samples[1].date, self.start.addingTimeInterval(600))
            return samples.last!.value - samples.first!.value
        }
        let result = grouped(model([[2, .nan, 8]], reducers: [custom]))
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(result.buckets[0][0].value, 6)
        XCTAssertEqual(result.buckets[0][0].aggregationName, "范围")
        _ = grouped(model([[.nan, .nan]], reducers: [custom]))
        XCTAssertEqual(calls, 1, "all missing skips reducer")
    }

    func testInvalidAndMissingConfigurationFallsBackToOriginalData() {
        var data = model([[1, 2, 3]])
        data.series[0].aggregation = nil
        XCTAssertEqual(grouped(data).status, .missingAggregation)
        data.series[0].aggregation = .sum
        data.timeAxis?.interval = 0
        XCTAssertEqual(grouped(data).status, .invalidTimeAxis)
        data.timeAxis?.interval = .infinity
        XCTAssertEqual(grouped(data).status, .invalidTimeAxis)
        data.timeAxis?.interval = 300
        data.stacking = .percentFixed(max: 100)
        XCTAssertEqual(grouped(data).status, .unsupportedStacking)
        data.stacking = nil
        data.timeGrouping = nil
        XCTAssertEqual(grouped(data).status, .disabled)
        XCTAssertEqual(grouped(data).model.series[0].data, [1, 2, 3])
    }

    func testBucketSumsConserveTotalsAndTailHasTrueDuration() {
        let data = model([Array(1...25).map(Double.init)])
        let result = grouped(data, width: 45)
        XCTAssertGreaterThan(result.samplesPerBucket, 1)
        XCTAssertEqual(result.buckets[0].compactMap(\.value).reduce(0, +), 325)
        let tail = result.buckets[0].last!
        XCTAssertEqual(tail.sourceRange.upperBound, 25)
        XCTAssertEqual(tail.interval.duration, Double(tail.sourceRange.count) * 300)
        XCTAssertEqual(result.model.maxPointCount, 25)
    }

    func testWidthSeriesCountAndZoomChooseDensityWithoutMovingBucketAnchor() {
        let data = model(Array(repeating: Array(repeating: 1, count: 1440), count: 3))
        let wide = grouped(data, width: 600)
        let narrow = grouped(data, width: 150)
        XCTAssertGreaterThan(narrow.samplesPerBucket, wide.samplesPerBucket)
        let zoom = grouped(data, width: 300, range: 100...110)
        XCTAssertEqual(zoom.samplesPerBucket, 1)
        let panned = grouped(data, width: 600, range: 100...1539)
        XCTAssertEqual(panned.buckets[0][1].sourceRange, wide.buckets[0][1].sourceRange)
        var one = data
        one.series[1].isVisible = false
        one.series[2].isVisible = false
        XCTAssertLessThanOrEqual(grouped(one, width: 600).samplesPerBucket, wide.samplesPerBucket)
    }

    func testHiddenUnconfiguredSeriesDoesNotBlockGrouping() {
        var data = model([[1, 2, 3], [10, 20, 30]])
        data.series[1].aggregation = nil
        data.series[1].isVisible = false
        let result = grouped(data)
        XCTAssertEqual(result.status, .active(samplesPerBucket: 3))
        XCTAssertEqual(result.buckets.count, 2)
        XCTAssertTrue(result.buckets[1].isEmpty)
        data.series[0].isVisible = false
        XCTAssertEqual(grouped(data).status, .noVisibleSeries)
    }

    func testPercentageIsComputedAfterAggregationAndVisibility() {
        var data = model([[10, 90], [90, 10]])
        data.stacking = .percent
        let result = grouped(data)
        XCTAssertEqual(result.model.rawBaseValues(forSeries: 0)[0], 50)
        XCTAssertEqual(result.model.stackedDrawValues[1][0], 100)
        data.series[1].isVisible = false
        XCTAssertEqual(grouped(data).model.rawBaseValues(forSeries: 0)[0], 100)
        data.stacking = .normal
        data.series[0].data = [-10, 5]
        XCTAssertEqual(grouped(data).model.stackedDrawValues[0][0], -5, "explicit sum is net amount")
    }

    func testCustomInvalidResultAndSumOverflowBecomeMissing() {
        let invalid = grouped(model([[1, 2]], reducers: [.custom(name: "invalid", reduce: { _ in .infinity })]))
        XCTAssertNil(invalid.buckets[0][0].value)
        let overflow = grouped(model([[Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude]]))
        XCTAssertNil(overflow.buckets[0][0].value)
    }

    func testRawResolutionDoesNotInvokeCustomReducer() {
        let data = model([[1, 2]], reducers: [.custom(name: "unexpected", reduce: { _ in XCTFail(); return 9 })])
        let result = grouped(data, width: 500)
        XCTAssertEqual(result.samplesPerBucket, 1)
        XCTAssertEqual(result.buckets[0].map(\.value), [1, 2])
        XCTAssertFalse(result.buckets[0][0].isAggregated)
    }

    func testColumnGeometryDirectSharedAndSnapHitsAgreeOnSourceInterval() throws {
        let view = chart(model(Array(repeating: Array(repeating: 2, count: 1440), count: 3)))
        let r = view.rendererForTesting
        let m = try XCTUnwrap(r.currentModel)
        let step = m.timeBucketStride
        XCTAssertGreaterThan(step, 1)
        let target = try XCTUnwrap(r.makeHitTarget(seriesIndex: 1, categoryIndex: step, value: r.currentDrawValues[1][step]) as? ColumnHitTarget)
        let rect = try XCTUnwrap(r.hitFrame(for: target))
        XCTAssertGreaterThanOrEqual(rect.width, 3.9)
        let point = CGPoint(x: rect.midX, y: rect.midY)
        let direct = try XCTUnwrap(r.hitTest(point) as? ColumnHitTarget)
        XCTAssertEqual(direct.timeBucket?.sourceRange, step..<(step * 2))
        let shared = try XCTUnwrap(r.sharedHit(at: point)?.target as? CartesianSharedHitTarget)
        XCTAssertEqual(shared.entries.count, 3)
        XCTAssertTrue(shared.entries.allSatisfy { $0.timeBucket?.sourceRange == direct.timeBucket?.sourceRange })
        let snap = try XCTUnwrap(r.snapHit(at: point) as? ColumnHitTarget)
        XCTAssertEqual(snap.timeBucket?.sourceRange, direct.timeBucket?.sourceRange)
        XCTAssertTrue(direct.tooltipText!.contains("有效"))
        XCTAssertTrue(direct.tooltipText!.contains("kW"))
        XCTAssertEqual(r.xAxisViewport, -0.5...1439.5)
    }

    func testDrillInsideHitCallbackDoesNotRestoreStaleInteraction() {
        for shared in [false, true] {
            let view = chart(model(Array(repeating: Array(repeating: 1, count: 1440), count: 3)))
            view.isSharedTooltipOnTapEnabled = shared
            var oldContexts = 0
            var didHit = false
            view.onHitLocated = { context, _ in if context != nil { oldContexts += 1 } }
            view.onHit = { [weak view] _, _ in
                didHit = true
                view?.showCategoryRange(100..<112)
            }
            let plot = view.rendererForTesting.currentPlotFrame
            view.performTap(at: CGPoint(x: plot.midX, y: plot.midY))
            XCTAssertTrue(didHit)
            XCTAssertEqual(oldContexts, 0)
            XCTAssertFalse(view.isCrosshairVisibleForTesting)
            XCTAssertEqual(view.rendererForTesting.xAxisViewport, 99.5...111.5)
        }
    }

    func testDrillDownAndResetRestoreRawCoordinateDomainAndValues() throws {
        let values = (0..<1440).map { Double($0 % 20 + 1) }
        let view = chart(model([values]))
        let r = view.rendererForTesting
        XCTAssertGreaterThan(r.currentModel!.timeBucketStride, 1)
        view.showCategoryRange(100..<112)
        XCTAssertEqual(r.currentModel!.timeBucketStride, 1)
        XCTAssertEqual(r.xAxisViewport, 99.5...111.5)
        XCTAssertEqual(r.currentModel!.series[0].data[105], values[105])
        view.resetViewport()
        view.layoutIfNeeded()
        XCTAssertEqual(r.xAxisViewport, -0.5...1439.5)
        XCTAssertGreaterThan(r.currentModel!.timeBucketStride, 1)
    }

    func testPartialBucketRemainsVisibleWhenAnchorIsOutsideWindow() throws {
        let view = chart(model([Array(repeating: 1, count: 3000)]), width: 200)
        let r = view.rendererForTesting
        r.setXAxisViewport(14.5...414.5)
        let step = r.currentModel!.timeBucketStride
        XCTAssertGreaterThan(step, 1)
        let anchor = r.currentModel!.bucketAnchor(for: 15)
        XCTAssertTrue(r.visibleCategoryRange.contains(anchor))
        let target = try XCTUnwrap(r.makeHitTarget(seriesIndex: 0, categoryIndex: anchor, value: r.currentDrawValues[0][anchor]))
        XCTAssertNotNil(r.hitFrame(for: target))
        let edge = CGPoint(x: r.currentPlotFrame.minX + 1, y: r.currentPlotFrame.midY)
        let shared = try XCTUnwrap(r.sharedHit(at: edge))
        XCTAssertGreaterThanOrEqual(shared.crosshair.midX, r.currentPlotFrame.minX)
        XCTAssertLessThanOrEqual(shared.crosshair.midX, r.currentPlotFrame.maxX)
    }

    func testNewDataAndLegendVisibilityInvalidateDerivedValues() {
        let view = chart(model(Array(repeating: Array(repeating: 1, count: 1440), count: 3)))
        view.setSeriesVisible(false, for: "s1")
        XCTAssertTrue(view.rendererForTesting.currentDrawValues[1].allSatisfy { $0.isNaN })
        view.update(model: model(Array(repeating: Array(repeating: 2, count: 1440), count: 3)))
        view.layoutIfNeeded()
        let r = view.rendererForTesting
        let step = r.currentModel!.timeBucketStride
        XCTAssertEqual(r.currentDrawValues[0][0], Double(step * 2))
        XCTAssertTrue(r.currentDrawValues[1].allSatisfy { $0.isNaN })
    }

    func testSwiftUIRangeCommandsDoNotOverwriteLaterGestureWindow() throws {
        let data = model([Array(repeating: 2, count: 1440)])
        func root(_ range: Range<Int>?, policy: HYMChartViewportUpdatePolicy = .preserve) -> some View {
            ColumnChart(model: data, playsAnimationOnAppear: false, viewportUpdatePolicy: policy, visibleCategoryRange: range).frame(height: 340)
        }
        let host = UIHostingController(rootView: root(100..<124))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        window.rootViewController = host; window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        func find(_ view: UIView) -> HYMChartView<ColumnChartRenderer>? {
            if let chart = view as? HYMChartView<ColumnChartRenderer> { return chart }
            return view.subviews.lazy.compactMap { find($0) }.first
        }
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let view = try XCTUnwrap(find(host.view))
        let r = view.rendererForTesting
        XCTAssertEqual(r.xAxisViewport, 99.5...123.5)
        r.setXAxisViewport(200...224)
        host.rootView = root(100..<124)
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(r.xAxisViewport, 200...224)
        host.rootView = root(100..<124, policy: .reset)
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(r.xAxisViewport, 99.5...123.5)
        host.rootView = root(nil)
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(r.xAxisViewport, -0.5...1439.5)
    }

    func testGroupedOverviewAndDetailSnapshots() {
        let data = model((0..<3).map { s in
            (0..<3000).map { i in 10 + Double(s * 5) + 5 * sin(Double(i) / 60) }
        }, reducers: [.average])
        let view = chart(data)
        for detail in [false, true] {
            if detail { view.showCategoryRange(100..<112) }
            view.backgroundColor = .white
            view.rendererForTesting.legendView.layoutIfNeeded()
            view.rendererForTesting.legendView.buttons.forEach { $0.layoutIfNeeded() }
            let image = UIGraphicsImageRenderer(bounds: view.bounds).image { view.layer.render(in: $0.cgContext) }
            let attachment = XCTAttachment(image: image)
            attachment.name = detail ? "density-detail" : "density-overview"
            attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    func testWorkloadMatrixAndSnapshot() {
        var rows = ["points,series,mode,layout_ms,bucket_size"]
        for count in [288, 1440, 2000, 3000] {
            for seriesCount in [1, 3, 6] {
                var data = model(Array(repeating: (0..<count).map { Double($0 % 20 + 1) }, count: seriesCount))
                data.stacking = .normal
                for enabled in [false, true] {
                    data.timeGrouping = enabled ? .init() : nil
                    let begin = CFAbsoluteTimeGetCurrent()
                    let view = chart(data)
                    let elapsed = (CFAbsoluteTimeGetCurrent() - begin) * 1000
                    let r = view.rendererForTesting
                    rows.append("\(count),\(seriesCount),\(enabled ? "grouped" : "raw"),\(elapsed),\(r.currentModel!.timeBucketStride)")
                    XCTAssertEqual(r.currentModel?.maxPointCount, count)
                    XCTAssertFalse(r.currentDrawValues.isEmpty)
                    if count == 3000 && seriesCount == 3 && enabled {
                        view.backgroundColor = .white
                        view.rendererForTesting.legendView.layoutIfNeeded()
                        view.rendererForTesting.legendView.buttons.forEach { $0.layoutIfNeeded() }
                        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { view.layer.render(in: $0.cgContext) }
                        let attachment = XCTAttachment(image: image)
                        attachment.name = "density-3000-stacked"; attachment.lifetime = .keepAlways; add(attachment)
                    }
                }
            }
        }
        let attachment = XCTAttachment(string: rows.joined(separator: "\n"))
        attachment.name = "density-simulator-layout-matrix.csv"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
