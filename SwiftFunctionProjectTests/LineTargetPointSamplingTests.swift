import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class LineTargetPointSamplingTests: XCTestCase {
    private func configuration(_ target: Int?) -> LineChartSampling {
        var c = LineChartSampling(); c.targetPointCount = target; return c
    }
    private func select(_ values: [Double], target: Int, range: ClosedRange<Double>? = nil,
                        width: CGFloat = 300, connect: Bool = false,
                        gap: CartesianGapPolicy? = nil) -> LineRenderSelection {
        LineMinMaxSampler.select(values: values, connectNulls: connect,
            visibleRange: range ?? (0...Double(max(1, values.count - 1))), plotWidth: width,
            configuration: configuration(target), gapPolicy: gap, sampleInterval: 60)
    }
    private func chart(_ values: [Double], target: Int = 200) -> HYMChartView<LineChartRenderer> {
        let view = HYMChartView<LineChartRenderer>(frame: CGRect(x: 0, y: 0, width: 390, height: 320))
        view.maximumZoomScale = 3000; view.minimumVisibleCategories = 2
        view.configure(model: .init(series: [.init(name: "Power", data: values, id: "power")]),
                       theme: .init(lineSampling: configuration(target)))
        view.layoutIfNeeded()
        return view
    }

    func testExactBudgetsForFlatMonotoneOscillatingAndExtremeValues() {
        var cases = 0
        for count in [0, 1, 2, 3, 4, 5, 8, 23, 100, 3000] {
            for pattern in 0..<5 {
                let values = (0..<count).map { i -> Double in
                    switch pattern {
                    case 0: return 7
                    case 1: return Double(i)
                    case 2: return -Double(i)
                    case 3: return sin(Double(i) * 0.7) * Double(i % 17 + 1)
                    default: return i.isMultiple(of: 2) ? .greatestFiniteMagnitude : -.greatestFiniteMagnitude
                    }
                }
                for target in [Int.min, -1, 0, 1, 2, 3, 4, 5, 7, 20, 51, 100, 200, 999, 3000, Int.max] {
                    let result = select(values, target: target)
                    let kept = result.segments.flatMap { $0 }
                    let expected = min(count, max(max(2, target), result.minimumRequiredPointCount))
                    XCTAssertEqual(kept.count, expected, "count=\(count) pattern=\(pattern) target=\(target)")
                    XCTAssertEqual(kept, Array(Set(kept)).sorted())
                    XCTAssertTrue(kept.allSatisfy { values.indices.contains($0) })
                    XCTAssertEqual(result.isDense, kept.count < count)
                    if let first = values.first, let last = values.last {
                        XCTAssertEqual(values[kept.first!], first); XCTAssertEqual(values[kept.last!], last)
                        XCTAssertEqual(kept.map { values[$0] }.min(), values.min())
                        XCTAssertEqual(kept.map { values[$0] }.max(), values.max())
                    }
                    cases += 1
                }
            }
        }
        XCTAssertEqual(cases, 800)
    }

    func testBudgetIsPerSeriesAndIndependentOfWidthAndActivationThreshold() {
        let values = (0..<3000).map { sin(Double($0)) }
        var c = configuration(123); c.minimumVisiblePoints = Int.max; c.bucketWidth = .nan
        let narrow = LineMinMaxSampler.select(values: values, connectNulls: false,
            visibleRange: 0...2999, plotWidth: 1, configuration: c)
        c.minimumVisiblePoints = 2; c.bucketWidth = 12
        let wide = LineMinMaxSampler.select(values: values, connectNulls: false,
            visibleRange: 0...2999, plotWidth: 10000, configuration: c)
        XCTAssertEqual(narrow.renderedPointCount, 123)
        XCTAssertEqual(narrow.segments, wide.segments)
        XCTAssertEqual(select(Array(values.prefix(24)), target: 8).renderedPointCount, 8)
    }

    func testProtectedEndpointsAndExtremaMayExceedTinyTargetWithoutJoiningGaps() {
        let values: [Double] = [0, 20, -10, 1, .nan, 2, 30, -5, 3, .nan, 9]
        let result = select(values, target: 2)
        XCTAssertEqual(result.segments, [[0, 1, 2, 3], [5, 6, 7, 8], [10]])
        XCTAssertEqual(result.minimumRequiredPointCount, 9)
        XCTAssertFalse(result.isDense) // 不能仅因启用模式就隐藏所有原始标记。
        XCTAssertEqual(select(values, target: 4, connect: true).renderedPointCount, 4)
        XCTAssertEqual(select(values, target: 4, gap: .autoGap(maximumMissingPoints: 1)).segments.count, 1)
        XCTAssertEqual(select(values, target: 4, gap: .autoGapDuration(maximumMissingDuration: 59)).segments.count, 3)
    }

    func testFragmentedBudgetAllocationIsExactAndPreservesEverySegmentExtremum() {
        var checks = 0
        for phase in 0..<9 {
            let values = (0..<240).map { i -> Double in
                (i + phase).isMultiple(of: phase + 5) ? .nan : sin(Double(i) * 1.7) * Double(i % 13)
            }
            let original = LineMinMaxSampler.segments(values: values, connectNulls: false)
            for target in 2...250 {
                let result = select(values, target: target)
                XCTAssertEqual(result.segments.count, original.count)
                XCTAssertEqual(result.renderedPointCount,
                    min(result.sourcePointCount, max(target, result.minimumRequiredPointCount)))
                for (before, after) in zip(original, result.segments) {
                    XCTAssertEqual(after.first, before.first); XCTAssertEqual(after.last, before.last)
                    XCTAssertEqual(after.map { values[$0] }.min(), before.map { values[$0] }.min())
                    XCTAssertEqual(after.map { values[$0] }.max(), before.map { values[$0] }.max())
                    XCTAssertEqual(after, Array(Set(after)).sorted())
                }
                checks += 1
            }
        }
        XCTAssertEqual(checks, 2241)
    }

    func testClippingCountsNeighboursInBudgetAndDoesNotInventValues() {
        let values = (0..<1000).map(Double.init)
        let sampled = select(values, target: 20, range: 400.2...600.8)
        XCTAssertEqual(sampled.visiblePointCount, 200)
        XCTAssertEqual(sampled.sourcePointCount, 202)
        XCTAssertEqual(sampled.renderedPointCount, 20)
        XCTAssertEqual(sampled.segments.first?.first, 400)
        XCTAssertEqual(sampled.segments.last?.last, 601)
        XCTAssertEqual(select(values, target: 200, range: 400...410).segments, [Array(399...411)])
        XCTAssertTrue(select(values, target: 200, range: 2000...2100).segments.isEmpty)
        XCTAssertTrue(select([.nan, .infinity, -.infinity], target: 2).segments.isEmpty)
        var gap = Array(repeating: Double.nan, count: 1000); gap[0] = 0; gap[999] = 9
        XCTAssertEqual(select(gap, target: 2, range: 400...600, connect: true).segments, [[0, 999]])
    }

    func testLiveTargetUpdatesPreserveViewportAndZoomRestoresSparseMarkers() throws {
        let view = chart((0..<3000).map { Double($0 % 31) })
        let renderer = view.rendererForTesting
        XCTAssertEqual(renderer.samplingStatistics.first?.renderedPointCount, 200)
        view.showCategoryRange(400..<900)
        let viewport = renderer.currentViewport.xDomain
        var theme = try XCTUnwrap(renderer.currentTheme)
        for target in [50, 123, 200] {
            theme.lineSampling?.targetPointCount = target
            view.update(theme: theme, viewportPolicy: .preserve); view.layoutIfNeeded()
            XCTAssertEqual(renderer.currentViewport.xDomain, viewport)
            XCTAssertEqual(renderer.samplingStatistics.first?.renderedPointCount, target)
        }
        view.showCategoryRange(400..<412)
        XCTAssertTrue(renderer.denseSeries.isEmpty)
        XCTAssertEqual(renderer.renderedIndices[0]?.flatMap { $0 }, Array(399...412))
        XCTAssertGreaterThan(renderer.seriesLayerSublayersForTesting().count, 1)
        view.resetViewport(); view.layoutIfNeeded()
        XCTAssertEqual(renderer.samplingStatistics.first?.renderedPointCount, 200)
        theme.lineSampling = nil
        view.update(theme: theme); view.layoutIfNeeded()
        XCTAssertEqual(renderer.renderedIndices[0]?.flatMap { $0 }.count, 3000)
        XCTAssertTrue(renderer.samplingStatistics.isEmpty)
    }

    func testOmittedPointsStillHitOriginalValuesAndDomains() throws {
        let values = (0..<3000).map(Double.init)
        let view = chart(values, target: 20), renderer = view.rendererForTesting
        let kept = Set(renderer.renderedIndices[0]!.flatMap { $0 })
        let omitted = try XCTUnwrap((1000..<1500).first { !kept.contains($0) })
        let point = renderer.testScreenPoint(series: 0, index: omitted)
        XCTAssertEqual((renderer.seriesHitTest(point) as? LineHitTarget)?.index, omitted)
        XCTAssertEqual((renderer.snapHit(at: point) as? LineHitTarget)?.value, Double(omitted))
        XCTAssertEqual((renderer.sharedHit(at: point)?.target as? CartesianSharedHitTarget)?.categoryIndex, omitted)
        XCTAssertEqual(renderer.currentModel?.series[0].data, values)
        let domain = renderer.currentViewport.yDomain
        view.update(theme: .init()); view.layoutIfNeeded()
        XCTAssertEqual(renderer.currentViewport.yDomain, domain)
    }

    func testMultiSeriesRaggedSecondaryAxisVisibilityAndUnsupportedModes() {
        var model = CartesianChartModel(series: [
            .init(name: "Long", data: (0..<1000).map(Double.init), id: "long"),
            .init(name: "Short", data: (0..<50).map { -Double($0) }, yAxisIndex: 1, id: "short")])
        model.secondaryYAxis = .init(kind: .value)
        let view = chart([], target: 100), renderer = view.rendererForTesting
        var theme = CartesianChartTheme(lineSampling: configuration(100))
        view.update(model: model, theme: theme); view.layoutIfNeeded()
        XCTAssertEqual(renderer.samplingStatistics.map(\.renderedPointCount), [100, 50])
        view.setSeriesVisible(false, for: "short"); view.layoutIfNeeded()
        XCTAssertEqual(renderer.samplingStatistics.map(\.seriesName), ["Long"])
        for style in [LineConnectionStyle.smooth, .stepBefore, .stepAfter, .stepCenter] {
            theme.lineConnectionStyle = style; view.update(theme: theme); view.layoutIfNeeded()
            XCTAssertFalse(renderer.usesSampling); XCTAssertTrue(renderer.samplingStatistics.isEmpty)
            XCTAssertEqual(renderer.renderedIndices[0]?.flatMap { $0 }.count, 1000)
        }
        theme.lineConnectionStyle = .straight; model.stacking = .normal
        view.update(model: model, theme: theme); view.layoutIfNeeded()
        XCTAssertFalse(renderer.usesSampling)
        XCTAssertEqual(renderer.renderedIndices[0]?.flatMap { $0 }.count, 1000)
    }

    func testDiagnosticsTrackDirectPanHideAndEmptySeries() {
        let view = chart((0..<1000).map(Double.init), target: 50)
        var snapshots: [[LineSamplingStatistics]] = []
        view.observeLineSampling { snapshots.append($0) }
        view.showCategoryRange(400..<600)
        XCTAssertEqual(snapshots.last?.first?.renderedPointCount, 50)
        let count = snapshots.count
        view.rendererForTesting.panXAxis(screenDeltaX: 20)
        XCTAssertGreaterThan(snapshots.count, count)
        view.setSeriesVisible(false, for: "power"); view.layoutIfNeeded()
        XCTAssertEqual(snapshots.last, [])
        view.update(model: .init(series: [.init(name: "Empty", data: [], id: "empty")])); view.layoutIfNeeded()
        XCTAssertEqual(snapshots.last, [])
    }

    func testReadoutShowsActualCountsOverflowAndSparseRecovery() {
        let overflow = LineSamplingStatistics(seriesName: "A", visiblePointCount: 30,
            sourcePointCount: 32, renderedPointCount: 12, targetPointCount: 5, minimumRequiredPointCount: 12)
        let text = DemoLineSamplingReadout.text([overflow])
        XCTAssertTrue(text.contains("可见 30 → 绘制 12"))
        XCTAssertTrue(text.contains("2 个边缘邻点"))
        XCTAssertTrue(text.contains("已超目标"))
        let sparse = LineSamplingStatistics(seriesName: "B", visiblePointCount: 10,
            sourcePointCount: 12, renderedPointCount: 12, targetPointCount: 200, minimumRequiredPointCount: 2)
        XCTAssertTrue(DemoLineSamplingReadout.text([sparse]).contains("不足目标，不补点"))
        XCTAssertEqual(DemoLineSamplingReadout.text([]), "")
    }

    func testExactIntegerInputValidationAndTargetPreset() {
        for (text, expected) in [("123", 123), (" 50 ", 50), ("0", 2), ("5000", 3000),
                                 ("", 200), ("3.5", 200), ("nan", 200), (String(repeating: "9", count: 50), 200)] {
            XCTAssertEqual(DemoIntegerInput.resolved(text, previous: 200, range: 2...3000), expected)
        }
        var state = CartesianDemoState(kind: .line)
        state.series[0].dataText = "1,nan,2"; state.stacking = "普通"
        state.query = "目标点数"; state.targetSamplingPreset()
        XCTAssertEqual(state.pointCount, 3000); XCTAssertEqual(state.seriesCount, 3)
        XCTAssertFalse(state.missing); XCTAssertTrue(state.samplingEligible)
        XCTAssertEqual(state.theme.lineSampling?.targetPointCount, 200)
        XCTAssertEqual(state.query, "目标点数")
        XCTAssertTrue(state.model.series.allSatisfy { $0.data.count == 3000 && $0.data.allSatisfy(\.isFinite) })
        XCTAssertFalse(state.theme.lineSampling!.hidesDenseMarkers)
    }

    func testReportCoalescesLayoutUpdatesAndCanReleaseWithoutRetainCycle() async {
        let report = DemoChartReport()
        let sample = LineSamplingStatistics(seriesName: "A", visiblePointCount: 1000,
            sourcePointCount: 1000, renderedPointCount: 200, targetPointCount: 200, minimumRequiredPointCount: 4)
        report.receiveSamplingStatistics([sample]); report.receiveSamplingStatistics([])
        await Task.yield()
        XCTAssertEqual(report.samplingText, "")
        report.receiveSamplingStatistics([sample])
        let updated = expectation(description: "Deferred report")
        DispatchQueue.main.async { updated.fulfill() }
        await fulfillment(of: [updated], timeout: 2)
        XCTAssertTrue(report.samplingText.contains("绘制 200"))
        weak var weakReport: DemoChartReport?
        do {
            let transient = DemoChartReport(); weakReport = transient
            transient.receiveSamplingStatistics([sample])
        }
        XCTAssertNil(weakReport)
    }
}
