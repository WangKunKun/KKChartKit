import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class RenderingReuseTests: XCTestCase {
    private var model: CartesianChartModel {
        .init(title: "Reuse", series: [
            .init(name: "A", data: [20, -10, 40, 30, 50], color: .systemBlue, id: "a"),
            .init(name: "B", data: [10, 20, 30, 15, 25], color: .systemOrange, id: "b")])
    }

    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(
        _ type: R.Type, model: CartesianChartModel? = nil, theme: CartesianChartTheme = .init()
    ) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 390, height: 320))
        view.backgroundColor = .white
        view.configure(model: model ?? self.model, theme: theme)
        view.layoutIfNeeded()
        return view
    }

    private func verifyIdentity<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) {
        let view = chart(type)
        let renderer = view.rendererForTesting
        let grid = renderer.rootLayer.sublayers!.first!
        let series = renderer.seriesLayer.sublayers!.first!
        let label = view.subviews.compactMap { $0 as? UILabel }.first!
        view.update(theme: .init()); view.layoutIfNeeded()
        XCTAssertTrue(grid === renderer.rootLayer.sublayers!.first!)
        XCTAssertTrue(series === renderer.seriesLayer.sublayers!.first!)
        XCTAssertTrue(view.subviews.contains { $0 === label })
        XCTAssertEqual(renderer.decorationObjects.createdCount, 0)
        XCTAssertEqual(renderer.seriesObjects.createdCount, 0)
        XCTAssertGreaterThan(renderer.seriesObjects.reusedCount, 0)
        var disabled = CartesianChartTheme(); disabled.reusesRenderingObjects = false
        view.update(theme: disabled); view.layoutIfNeeded()
        XCTAssertFalse(grid === renderer.rootLayer.sublayers!.first!)
        XCTAssertFalse(series === renderer.seriesLayer.sublayers!.first!)
        XCTAssertEqual(renderer.seriesObjects.reusedCount, 0)
    }

    func testLineColumnAndBarReuseActualObjectsAndCanDisable() {
        verifyIdentity(LineChartRenderer.self)
        verifyIdentity(ColumnChartRenderer.self)
        verifyIdentity(BarChartRenderer.self)
    }

    func testRotatedAxisLabelsResetWhenRotationAndTitleChange() {
        var m = model; m.xAxis.tickLabelRotation = 60
        let view = chart(LineChartRenderer.self, model: m)
        XCTAssertTrue(view.subviews.contains { !$0.transform.isIdentity })
        m.xAxis.tickLabelRotation = 0; m.title = nil
        view.update(model: m); view.layoutIfNeeded()
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertTrue(labels.allSatisfy { $0.transform.isIdentity })
        XCTAssertFalse(labels.contains { $0.text == "Reuse" })
        XCTAssertTrue(labels.allSatisfy { $0.bounds.width > 0 && $0.bounds.height > 0 })
    }

    private func image(_ view: UIView) -> Data? {
        UIGraphicsImageRenderer(bounds: view.bounds).image { view.layer.render(in: $0.cgContext) }.pngData()
    }

    private func verifyVisualParity<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) {
        var m = model
        var t = CartesianChartTheme()
        t.showsArea = true; t.showsDataLabels = true; t.pointHoleRadius = 2
        t.seriesShadow = .init(); t.columnBorderColor = .red; t.lineDashStyle = .dash
        m.plotLines = [.init(value: 25, label: "limit")]
        m.plotBands = [.init(from: 10, to: 30, label: "range")]
        let reused = chart(type, model: m, theme: t)
        t.reusesRenderingObjects = false
        let fresh = chart(type, model: m, theme: t)
        for step in 0..<4 {
            if step == 1 {
                t.showsArea = false; t.showsDataLabels = false; t.pointHoleRadius = 0
                t.seriesShadow = nil; t.columnBorderColor = nil; t.lineDashStyle = .solid
                m.plotBands = []; m.plotLines = []; m.title = nil
                m.series.removeLast()
            } else if step == 2 {
                t.showsArea = true; t.showsDataLabels = true
                t.pointSymbol = .diamond; m.series[0].negativeColor = .purple
            } else if step == 3 {
                m.series[0].isVisible = false
            }
            t.reusesRenderingObjects = true
            reused.update(model: m, theme: t); reused.layoutIfNeeded()
            t.reusesRenderingObjects = false
            fresh.update(model: m, theme: t); fresh.layoutIfNeeded()
            XCTAssertEqual(image(reused), image(fresh), "\(type) transition \(step)")
        }
    }

    func testReuseMatchesFreshRenderingAcrossStyleAndVisibilityTransitions() {
        verifyVisualParity(LineChartRenderer.self)
        verifyVisualParity(ColumnChartRenderer.self)
        verifyVisualParity(BarChartRenderer.self)
    }

    private func verifyEmpty<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) {
        var theme = CartesianChartTheme(); theme.showsDataLabels = true
        let view = chart(type, theme: theme); let r = view.rendererForTesting
        XCTAssertGreaterThan(r.seriesObjects.retainedCount, 0)
        view.update(model: .init(series: [])); view.layoutIfNeeded()
        XCTAssertTrue(r.seriesLayer.sublayers?.isEmpty ?? true)
        XCTAssertEqual(r.seriesObjects.retainedCount, 0)
        XCTAssertNil(r.seriesHitTest(CGPoint(x: r.currentPlotFrame.midX, y: r.currentPlotFrame.midY)))
        view.update(model: model); view.layoutIfNeeded()
        XCTAssertGreaterThan(r.seriesObjects.retainedCount, 0)
    }

    func testEmptyDataClearsSeriesAndHitCachesAndCanRestore() {
        verifyEmpty(LineChartRenderer.self)
        verifyEmpty(ColumnChartRenderer.self)
        verifyEmpty(BarChartRenderer.self)
    }

    func testDenseToSparseAndUnmountReleaseUnusedObjects() {
        let m = CartesianChartModel(series: [.init(name: "dense", data: (0..<1000).map { Double($0 % 50) })])
        var sampling = LineChartSampling(); sampling.hidesDenseMarkers = false
        var theme = CartesianChartTheme(); theme.lineSampling = sampling
        var view: HYMChartView<LineChartRenderer>!
        weak var lastMarker: CALayer?
        autoreleasepool {
            view = chart(LineChartRenderer.self, model: m, theme: theme)
            let r = view.rendererForTesting
            let before = r.seriesObjects.retainedCount
            lastMarker = r.seriesLayer.sublayers?.last
            view.showCategoryRange(100..<110)
            XCTAssertLessThan(r.seriesObjects.retainedCount, before)
            // Core Animation 的事务和 sublayers 桥接数组可暂时持有已移除层。
            CATransaction.flush()
        }
        XCTAssertNil(lastMarker)
        let r = view.rendererForTesting
        r.unmount(from: view)
        XCTAssertEqual(r.seriesObjects.retainedCount, 0)
        XCTAssertEqual(r.decorationObjects.retainedCount, 0)
        XCTAssertTrue(r.seriesLayer.sublayers?.isEmpty ?? true)
        r.mount(into: view)
        view.update(model: model); view.layoutIfNeeded()
        XCTAssertGreaterThan(r.seriesObjects.retainedCount, 0)
    }

    private func verifyAnimation<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) {
        var m = model; m.stacking = .normal
        var t = CartesianChartTheme(); t.showsDataLabels = true; t.showsStackTotalLabels = true; t.seriesShadow = .init()
        let view = chart(type, model: m, theme: t); let r = view.rendererForTesting
        r.updateSeriesAnimation(progress: 0.3)
        let count = r.seriesObjects.retainedCount
        for _ in 0..<5 { r.updateSeriesAnimation(progress: 0.3) }
        XCTAssertEqual(r.seriesObjects.retainedCount, count)
        XCTAssertEqual(r.seriesObjects.createdCount, 0)
        r.updateSeriesAnimation(progress: 1)
        let fresh = chart(type, model: m, theme: t)
        XCTAssertEqual(image(view), image(fresh))
    }

    func testBarAndColumnAnimationReuseLabelsAndShadowsWithoutAccumulation() {
        verifyAnimation(ColumnChartRenderer.self)
        verifyAnimation(BarChartRenderer.self)
    }

    func testDemoReuseToggleBindsToActualConfiguration() {
        var theme = CartesianChartTheme()
        XCTAssertTrue(theme.reusesRenderingObjects)
        let fields = DemoThemeFields.items(Binding(get: { theme }, set: { theme = $0 }))
        guard case .toggle(_, let value) = fields.first(where: { $0.label.contains("reusesRenderingObjects") }) else { return XCTFail() }
        value.wrappedValue = false; XCTAssertFalse(theme.reusesRenderingObjects)
        value.wrappedValue = true; XCTAssertTrue(theme.reusesRenderingObjects)
    }

    func testRepeatedLayoutAllocationBenchmark() {
        let m = CartesianChartModel(series: (0..<2).map { series in
            .init(name: "\(series)", data: (0..<3000).map { 50 + 30 * sin(Double($0 + series) / 80) })
        })
        var rows = ["mode,points,series,frames,mean_layout_ms,created_objects,reused_objects"]
        for sampling in [false, true] {
            for reuse in [false, true] {
                var t = CartesianChartTheme(); t.reusesRenderingObjects = reuse; t.lineSampling = sampling ? .init() : nil
                let view = chart(LineChartRenderer.self, model: m, theme: t); let r = view.rendererForTesting
                var created = 0; var reused = 0
                let start = CACurrentMediaTime()
                for _ in 0..<12 {
                    view.setNeedsLayout(); view.layoutIfNeeded()
                    created += r.seriesObjects.createdCount + r.decorationObjects.createdCount
                    reused += r.seriesObjects.reusedCount + r.decorationObjects.reusedCount
                }
                let ms = (CACurrentMediaTime() - start) * 1000 / 12
                rows.append("\(sampling ? "minmax" : "raw")-\(reuse ? "reuse" : "fresh"),3000,2,12,\(ms),\(created),\(reused)")
                if reuse { XCTAssertEqual(created, 0); XCTAssertGreaterThan(reused, 0) }
                else { XCTAssertGreaterThan(created, 0); XCTAssertEqual(reused, 0) }
            }
        }
        let attachment = XCTAttachment(string: rows.joined(separator: "\n"))
        attachment.name = "render-object-reuse-simulator.csv"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
