import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class DivergingStackRendererTests: XCTestCase {
    private func view(_ model: CartesianChartModel, width: CGFloat = 640) -> HYMChartView<LineChartRenderer> {
        let v = HYMChartView<LineChartRenderer>(frame: CGRect(x: 0, y: 0, width: width, height: 360))
        var t = CartesianChartTheme(); t.stackedAreaBoundaryMode = .diverging
        t.showsArea = true; t.showsPoints = false
        v.configure(model: model, theme: t); v.layoutIfNeeded(); return v
    }
    private func areas(_ root: CALayer) -> [CGPath] {
        if let g = root as? CAGradientLayer, let p = (g.mask as? CAShapeLayer)?.path { return [p] }
        return (root.sublayers ?? []).flatMap(areas)
    }
    private func image(_ view: UIView, _ name: String) {
        let format = UIGraphicsImageRendererFormat(); format.scale = 3
        let raster = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { context in
            UIColor.white.setFill(); context.fill(view.bounds); view.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: raster); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }

    func testUnifiedGapsKeepValidRawHitsAndDoNotAddZeroCrossingSamples() throws {
        let m = CartesianChartModel(series: [
            .init(name: "base", data: [20,40,.nan,-20,-40], connectNulls: true, id: "base"),
            .init(name: "top", data: [5,-5,8,5,-5], connectNulls: true, id: "top")], stacking: .normal)
        let v = view(m), r = v.rendererForTesting
        XCTAssertEqual(r.divergingBoundarySeries, [0,1]); XCTAssertTrue(r.divergingLinearFallbackSeries.isEmpty)
        XCTAssertEqual(r.renderedIndices[1], [[0,1,2,3,4]]) // raw marker/interaction selection remains intact
        let hit = try XCTUnwrap(r.seriesHitTest(r.testScreenPoint(series: 1, index: 2)) as? LineHitTarget)
        XCTAssertEqual(hit.index, 2); XCTAssertEqual(hit.rawValue, 8); XCTAssertEqual(hit.seriesID, "top")
        XCTAssertEqual(r.datum(series: 1, category: 2)?.stackBase, 0)
        XCTAssertNil(r.datum(series: 0, category: 2))
        let paths = areas(r.seriesLayer); XCTAssertEqual(paths.count, 2)
        for path in paths {
            // No area may pass through the entire unified missing interval.
            for x in [1.2,1.7,2.2,2.7] {
                for y in stride(from: -40.0, through: 40.0, by: 4) {
                    XCTAssertFalse(path.contains(r.screenPoint(x: x, y: y)))
                }
            }
        }
        image(v, "G1-diverging-unified-gap")
    }

    func testAllGapEmptyAndSingleSampleChartsStayFiniteAndResetDiagnostics() {
        for mode: StackConfig in [.none, .normal, .percent, .percentFixed(max: 100), .grouped(groupCount: 2)] {
            for data: [[Double]] in [[[.nan,.nan],[1,2]], [[1],[2]], [[],[]], [[1,2],[]], [[1,2,3],[1,2]], [[.infinity,1],[1,2]]] {
                let m = CartesianChartModel(series: data.enumerated().map { .init(name: "S\($0)", data: $1) }, stacking: mode)
                let v = view(m), r = v.rendererForTesting
                for path in areas(r.seriesLayer) {
                    path.applyWithBlock { ptr in
                        let e = ptr.pointee
                        let count = e.type == .addCurveToPoint ? 3 : (e.type == .closeSubpath ? 0 : 1)
                        for i in 0..<count { XCTAssertTrue(e.points[i].x.isFinite && e.points[i].y.isFinite) }
                    }
                }
                var t = r.currentTheme!; t.stackedAreaBoundaryMode = .independent
                v.update(theme: t); v.layoutIfNeeded()
                XCTAssertTrue(r.divergingBoundarySeries.isEmpty); XCTAssertTrue(r.divergingLinearFallbackSeries.isEmpty)
            }
        }
    }

    func testLineCombinedDemoOCAndReuseOffUseSameGeometry() throws {
        var state = CartesianDemoState(kind: .line); state.divergingStackedAreaPreset()
        let v = view(state.model); v.update(theme: state.builtTheme); v.layoutIfNeeded()
        let initial = areas(v.rendererForTesting.seriesLayer)
        var combinedState = CartesianDemoState(kind: .combined); combinedState.divergingStackedAreaPreset()
        let combined = HYMChartView<CombinedChartRenderer>(frame: v.frame)
        combined.configure(model: combinedState.model, theme: combinedState.builtTheme); combined.layoutIfNeeded()
        XCTAssertEqual(initial, areas(combined.rendererForTesting.rootLayer))
        var theme = state.builtTheme; theme.reusesRenderingObjects = false
        v.update(theme: theme); v.layoutIfNeeded(); XCTAssertEqual(initial, areas(v.rendererForTesting.seriesLayer))
        image(v, "G1-diverging-mixed-styles")
        let source = HYMCartesianModel(); source.stacking = .percent
        source.series = [[10.0,90,-10], [2,2,2]].enumerated().map { i, data in
            let s = HYMCartesianSeries(); s.identifier = "oc\(i)"; s.data = data.map { NSNumber(value: $0) }
            s.kind = .areaspline; return s
        }
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: v.frame)
        bridge.stackedAreaFollowsBaseline = true; bridge.stackedAreaUsesDivergingChains = true
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        let oc = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        XCTAssertEqual(oc.rendererForTesting.divergingBoundarySeries, [0,1])
        XCTAssertEqual(oc.rendererForTesting.currentTheme?.stackedAreaBoundaryMode, .diverging)
        XCTAssertEqual(oc.rendererForTesting.datum(series: 0, category: 1)?.rawValue, 90)
        image(oc, "G1-diverging-percent-OC")
        bridge.stackedAreaUsesDivergingChains = false
        try bridge.update(model: source, preserveViewport: true); oc.layoutIfNeeded()
        XCTAssertEqual(oc.rendererForTesting.currentTheme?.stackedAreaBoundaryMode, .followBaseline)
        XCTAssertTrue(oc.rendererForTesting.divergingBoundarySeries.isEmpty)
    }

    func testCombinedColumnGapsDoNotBreakLineStackFamily() {
        var s = CartesianDemoState(kind: .combined); s.divergingStackedAreaPreset()
        var m = s.model
        m.series[1].kind = .column // only this series has a gap
        let v = HYMChartView<CombinedChartRenderer>(frame: CGRect(x: 0,y: 0,width: 640,height: 360))
        v.configure(model: m, theme: s.builtTheme); v.layoutIfNeeded()
        let r = v.rendererForTesting.lines
        XCTAssertEqual(r.divergingBoundarySeries, [0,2])
        XCTAssertTrue(areas(r.seriesLayer).contains { $0.contains(r.screenPoint(x: 4.2, y: -10)) })
    }

    func testPresetAndDisabledGapControlsRestoreWithoutDiscardingValues() throws {
        final class Box { var state = CartesianDemoState(kind: .line) }
        let box = Box(); box.state.divergingStackedAreaPreset()
        box.state.series[2].connectNulls = true
        let binding = Binding(get: { box.state }, set: { box.state = $0 })
        func item(_ label: String) throws -> ChartDemoPanel.Item {
            try XCTUnwrap(CartesianDemoControls.sections(binding).flatMap(\.items).first { $0.label == label })
        }
        XCTAssertEqual(box.state.theme.stackedAreaBoundaryMode, .diverging)
        XCTAssertTrue(box.state.model.series[1].data[4].isNaN)
        XCTAssertFalse(try item("跨空值连线").isEnabled)
        box.state.theme.stackedAreaBoundaryMode = .independent
        XCTAssertTrue(try item("跨空值连线").isEnabled)
        XCTAssertTrue(box.state.series[2].connectNulls)
    }

    func testVisibilityResizeViewportAndModeUpdatesRebuildWithoutStaleSurfaces() {
        var state = CartesianDemoState(kind: .line); state.divergingStackedAreaPreset()
        let v = view(state.model), r = v.rendererForTesting
        for width: CGFloat in [320,834,480] {
            for percent in [false,true] {
                var m = state.model; m.stacking = percent ? .percent : .normal
                m.series[1].isVisible = false
                v.frame.size.width = width; v.update(model: m); v.layoutIfNeeded()
                XCTAssertEqual(r.divergingBoundarySeries, [0,2])
                let reference = view(m, width: width)
                XCTAssertEqual(areas(r.seriesLayer), areas(reference.rendererForTesting.seriesLayer))
                v.showCategoryRange(2..<6); reference.showCategoryRange(2..<6)
                v.layoutIfNeeded(); reference.layoutIfNeeded()
                XCTAssertEqual(v.xAxisViewportForTesting, reference.xAxisViewportForTesting)
                XCTAssertEqual(areas(r.seriesLayer), areas(reference.rendererForTesting.seriesLayer))
                v.resetViewport()
                for target in r.renderedIndices.keys { XCTAssertNotEqual(target, 1) }
            }
        }
        var m = state.model; m.series = []
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertTrue(r.divergingBoundarySeries.isEmpty)
        XCTAssertTrue(r.divergingLinearFallbackSeries.isEmpty)
    }
    func testAutomaticAxesIncludeInterSampleStackPeaksButRespectExplicitBounds() {
        var a = CartesianSeriesStyle(); a.lineConnectionStyle = .stepAfter
        var b = CartesianSeriesStyle(); b.lineConnectionStyle = .stepBefore
        for mode: StackConfig in [.normal, .percent, .percentFixed(max: 20)] {
            var m = CartesianChartModel(series: [
                .init(name: "A", data: [10,0], kind: .area, style: a),
                .init(name: "B", data: [0,10], kind: .area, style: b),
                .init(name: "C", data: [-10,0], yAxisIndex: 1, kind: .area, style: a),
                .init(name: "D", data: [0,-10], yAxisIndex: 1, kind: .area, style: b)
            ], secondaryYAxis: .init(kind: .value), stacking: mode)
            let line = view(m), r = line.rendererForTesting
            let expected = mode == .normal ? 20.0 : 100.0
            XCTAssertGreaterThanOrEqual(r.currentViewport.yDomain.upperBound, expected)
            XCTAssertLessThanOrEqual(r.currentSecondaryYDomain!.lowerBound, -expected)
            let combined = HYMChartView<CombinedChartRenderer>(frame: line.frame)
            combined.configure(model: m, theme: r.currentTheme!); combined.layoutIfNeeded()
            XCTAssertEqual(combined.rendererForTesting.currentViewport.yDomain, r.currentViewport.yDomain)
            XCTAssertEqual(combined.rendererForTesting.currentSecondaryYDomain, r.currentSecondaryYDomain)
            m.yAxis.min = 2; m.yAxis.max = 8
            m.secondaryYAxis?.min = -8; m.secondaryYAxis?.max = -2
            line.update(model: m); line.layoutIfNeeded()
            XCTAssertEqual(r.currentViewport.yDomain, 2...8)
            XCTAssertEqual(r.currentSecondaryYDomain, -8 ... -2)
            var t = r.currentTheme!; t.stackedAreaBoundaryMode = .independent
            m.yAxis.min = nil; m.yAxis.max = nil
            line.update(model: m, theme: t); line.layoutIfNeeded()
            XCTAssertLessThanOrEqual(r.currentViewport.yDomain.upperBound, mode == .normal ? 10 : 100)
        }
    }

    func testLineAndCombinedDiagnosticsActuallyPublishAfterRenderAndClear() {
        let report = DemoChartReport()
        var s = CartesianDemoState(kind: .combined); s.divergingStackedAreaPreset()
        let v = HYMChartView<CombinedChartRenderer>(frame: CGRect(x: 0,y: 0,width: 640,height: 360))
        var observed: Set<Int> = []
        v.observeLineDiagnostics { _, indices, fallback in
            observed = indices; XCTAssertTrue(fallback.isEmpty)
            report.receiveSamplingStatistics([], boundaryText: indices.isEmpty ? "" : "active")
        }
        v.configure(model: s.model, theme: s.builtTheme); v.layoutIfNeeded()
        XCTAssertEqual(observed, [0,1,2])
        let first = expectation(description: "published")
        DispatchQueue.main.async { XCTAssertEqual(report.stackBoundaryText, "active"); first.fulfill() }
        wait(for: [first], timeout: 2)
        var t = s.builtTheme; t.stackedAreaBoundaryMode = .independent
        v.update(theme: t); v.layoutIfNeeded(); XCTAssertTrue(observed.isEmpty)
        let cleared = expectation(description: "cleared")
        DispatchQueue.main.async { XCTAssertEqual(report.stackBoundaryText, ""); cleared.fulfill() }
        wait(for: [cleared], timeout: 2)
    }

}
