import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class AnnotationStyleTests: XCTestCase {
    private func model() -> CartesianChartModel {
        .init(series: [.init(name: "A", data: [20, 21, 20, 23], id: "a", kind: .column),
                       .init(name: "B", data: [5, 4, 5, 2], id: "b", kind: .line)],
              xAxis: .init(kind: .category(labels: ["A", "B", "C", "D"])),
              yAxis: .init(kind: .value, min: 0, max: 30), stacking: .normal,
              plotLines: [.init(value: 25, color: .red, label: "LIMIT")],
              plotBands: [.init(from: 12, to: 23, label: "TARGET")])
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
        _ m: CartesianChartModel, theme: CartesianChartTheme = .init(), width: CGFloat = 500) -> HYMChartView<R> {
        let v = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: width, height: 320))
        v.configure(model: m, theme: theme); v.layoutIfNeeded(); return v
    }
    private func labels(_ layer: CALayer, prefix: String = "chart.") -> [CATextLayer] {
        (layer.sublayers ?? []).flatMap { child -> [CATextLayer] in
            if let t = child as? CATextLayer, t.name?.hasPrefix(prefix) == true { return [t] }
            return labels(child, prefix: prefix)
        }
    }
    func testGeometryAlignmentOffsetsClampingAndNonFiniteInputs() throws {
        let plot = CGRect(x: 10, y: 20, width: 200, height: 100)
        let reference = CGRect(x: 40, y: 40, width: 100, height: 50)
        var style = CartesianAnnotationLabelStyle(alignment: .leading, verticalAlignment: .bottom,
                                                   offset: CGSize(width: 5, height: -2))
        let frame = try XCTUnwrap(CartesianAnnotationLabelGeometry.frame(size: CGSize(width: 40, height: 10),
            defaultCenter: .zero, reference: reference, plot: plot, style: style))
        XCTAssertEqual(frame.minX, 49); XCTAssertEqual(frame.maxY, 85)
        style.offset = CGSize(width: CGFloat.infinity, height: CGFloat.nan)
        let finite = try XCTUnwrap(CartesianAnnotationLabelGeometry.frame(size: CGSize(width: 40, height: 10),
            defaultCenter: .zero, reference: reference, plot: plot, style: style))
        XCTAssertEqual(finite.minX, 44); XCTAssertEqual(finite.maxY, 87)
        style.offset = CGSize(width: 1e200, height: -1e200)
        let clamped = try XCTUnwrap(CartesianAnnotationLabelGeometry.frame(size: CGSize(width: 400, height: 10),
            defaultCenter: .zero, reference: reference, plot: plot, style: style))
        XCTAssertEqual(clamped.width, 196); XCTAssertTrue(plot.contains(clamped))
        style.bounds = .hide
        XCTAssertNil(CartesianAnnotationLabelGeometry.frame(size: CGSize(width: 400, height: 10),
            defaultCenter: .zero, reference: reference, plot: plot, style: style))
        style.bounds = .clamp
        XCTAssertNil(CartesianAnnotationLabelGeometry.frame(size: CGSize(width: 20, height: 200),
            defaultCenter: .zero, reference: reference, plot: plot, style: style))
    }
    func testIndependentStylesAndBoundedLabelsAcrossFourRenderers() throws {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            var m = model()
            m.plotLines[0].labelStyle = .init(color: .purple, font: .boldSystemFont(ofSize: 19),
                backgroundColor: .yellow, alignment: .leading, verticalAlignment: .top)
            m.plotBands[0].labelStyle = .init(color: .blue, font: .systemFont(ofSize: 13),
                backgroundColor: .white, alignment: .trailing, verticalAlignment: .bottom)
            let v = chart(type, m), r = v.rendererForTesting
            let texts = labels(r.rootLayer, prefix: "chart.annotation.")
            XCTAssertEqual(texts.count, 2)
            let line = try XCTUnwrap(texts.first { $0.name == "chart.annotation.line" })
            let band = try XCTUnwrap(texts.first { $0.name == "chart.annotation.band" })
            XCTAssertEqual(line.fontSize, 19); XCTAssertEqual(line.foregroundColor, UIColor.purple.cgColor)
            XCTAssertEqual(line.backgroundColor, UIColor.yellow.cgColor); XCTAssertEqual(line.alignmentMode, .left)
            XCTAssertEqual(band.fontSize, 13); XCTAssertEqual(band.foregroundColor, UIColor.blue.cgColor)
            XCTAssertTrue(texts.allSatisfy { r.currentPlotFrame.contains($0.frame) })
            let layers = r.rootLayer.sublayers ?? []
            XCTAssertGreaterThan(try XCTUnwrap(layers.firstIndex(of: band)), try XCTUnwrap(layers.firstIndex(of: r.seriesLayer)))
        }
        try check(LineChartRenderer.self); try check(ColumnChartRenderer.self)
        try check(BarChartRenderer.self); try check(CombinedChartRenderer.self)
    }
    func testAxisBindingClippedBandAndUpdatesNeverChangeDataOrHits() throws {
        var m = model(); m.secondaryYAxis = .init(kind: .value, min: 0, max: 1000)
        m.plotLines[0].value = 500; m.plotLines[0].yAxisIndex = 1
        m.plotLines[0].labelStyle.verticalAlignment = .center
        m.plotBands[0].from = -500; m.plotBands[0].to = 15
        let v = chart(ColumnChartRenderer.self, m), r = v.rendererForTesting
        let line = try XCTUnwrap(labels(r.rootLayer).first { $0.name == "chart.annotation.line" })
        XCTAssertEqual(line.frame.midY, r.currentPlotFrame.midY, accuracy: 0.001)
        let band = try XCTUnwrap(labels(r.rootLayer).first { $0.name == "chart.annotation.band" })
        XCTAssertEqual(band.frame.midY, r.currentPlotFrame.maxY - r.currentPlotFrame.height / 4, accuracy: 0.001)
        let target = try XCTUnwrap(r.makeHitTarget(seriesIndex: 0, categoryIndex: 1, value: 21))
        let before = r.hitFrame(for: target), datum = r.datum(series: 0, category: 1)
        m.plotLines[0].labelStyle.offset = CGSize(width: 900, height: 900); m.plotLines[0].labelStyle.bounds = .hide
        m.plotBands[0].from = .nan
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertTrue(labels(r.rootLayer, prefix: "chart.annotation.").isEmpty)
        XCTAssertEqual(r.hitFrame(for: target), before)
        XCTAssertEqual(r.datum(series: 0, category: 1)?.rawValue, datum?.rawValue)
        XCTAssertEqual(r.currentViewport.yDomain, 0...30)
        m.secondaryYAxis = nil
        let bar = chart(BarChartRenderer.self, m)
        XCTAssertTrue(labels(bar.rendererForTesting.rootLayer, prefix: "chart.annotation.").isEmpty)
    }
    func testLongLabelsTruncateHideAndReflowAfterResizeAndPan() throws {
        var m = model(); m.plotLines[0].label = String(repeating: "long ", count: 50)
        let v = chart(LineChartRenderer.self, m, width: 220), r = v.rendererForTesting
        let line = try XCTUnwrap(labels(r.rootLayer).first { $0.name == "chart.annotation.line" })
        XCTAssertEqual(line.frame.width, r.currentPlotFrame.width - 4, accuracy: 0.001)
        XCTAssertEqual(line.truncationMode, .end)
        v.bounds.size.width = 680; v.setNeedsLayout(); v.layoutIfNeeded()
        XCTAssertGreaterThan(try XCTUnwrap(labels(r.rootLayer).first { $0.name == "chart.annotation.line" }).frame.width, 400)
        v.showCategoryRange(1..<3); v.layoutIfNeeded()
        XCTAssertTrue(labels(r.rootLayer, prefix: "chart.annotation.").allSatisfy { r.currentPlotFrame.contains($0.frame) })
        m.plotLines[0].labelStyle.bounds = .hide; v.update(model: m); v.layoutIfNeeded()
        XCTAssertFalse(labels(r.rootLayer).contains { $0.name == "chart.annotation.line" })
        m.plotLines[0].label = ""; m.plotBands[0].to = -1000; m.plotBands[0].from = -2000
        v.update(model: m); v.layoutIfNeeded(); XCTAssertTrue(labels(r.rootLayer, prefix: "chart.annotation.").isEmpty)
    }
    func testDataLabelAvoidanceKeepsTotalsFirstAndDoesNotTouchGeometry() throws {
        var m = model(); m.plotLines = []; m.plotBands = []
        var t = CartesianChartTheme(); t.showsDataLabels = true; t.showsStackTotalLabels = true
        t.dataLabelPosition = .outsideEnd; t.dataLabelColor = .black; t.dataLabelBackgroundColor = .white
        let v = chart(ColumnChartRenderer.self, m, theme: t), r = v.rendererForTesting
        let original = labels(r.rootLayer, prefix: "chart.label.")
        let totalCount = original.filter { $0.name == "chart.label.total" }.count
        let target = try XCTUnwrap(r.makeHitTarget(seriesIndex: 1, categoryIndex: 1, value: 25))
        let frame = r.hitFrame(for: target)
        t.dataLabelAvoidsOverlap = true; v.update(model: m, theme: t); v.layoutIfNeeded()
        let remaining = labels(r.rootLayer, prefix: "chart.label.")
        XCTAssertEqual(remaining.filter { $0.name == "chart.label.total" }.count, totalCount)
        XCTAssertLessThan(remaining.count, original.count)
        XCTAssertTrue(remaining.allSatisfy { $0.backgroundColor == UIColor.white.cgColor })
        for (i, a) in remaining.enumerated() {
            let fa = a.convert(a.bounds, to: r.rootLayer)
            XCTAssertTrue(r.currentPlotFrame.contains(fa))
            for b in remaining.dropFirst(i + 1) { XCTAssertFalse(fa.insetBy(dx: -1, dy: -1).intersects(b.convert(b.bounds, to: r.rootLayer))) }
        }
        XCTAssertEqual(r.hitFrame(for: target), frame)
        t.dataLabelAvoidsOverlap = false; v.update(model: m, theme: t); v.layoutIfNeeded()
        XCTAssertEqual(labels(r.rootLayer, prefix: "chart.label.").count, original.count)
    }
    func testCombinedResolvesCrossFamilyCollisionsAndReuseMatchesFreshAtAllScales() {
        var m = model(); m.stacking = StackConfig.none; m.series[1].data = m.series[0].data
        var t = CartesianChartTheme(); t.showsDataLabels = true; t.dataLabelAvoidsOverlap = true
        t.dataLabelBackgroundColor = .white; t.dataLabelFontSize = 17
        let reused = chart(CombinedChartRenderer.self, m, theme: t)
        for step in 0..<3 {
            if step == 1 { t.dataLabelBackgroundColor = nil; m.plotLines[0].labelStyle = .init(color: .cyan, font: .boldSystemFont(ofSize: 20), backgroundColor: .yellow) }
            if step == 2 { m.plotLines[0].labelStyle = .init(); t.dataLabelAvoidsOverlap = false }
            reused.update(model: m, theme: t); reused.layoutIfNeeded()
            let fresh = chart(CombinedChartRenderer.self, m, theme: t)
            let r = reused.rendererForTesting, text = labels(r.rootLayer, prefix: "chart.label.")
            if t.dataLabelAvoidsOverlap {
                for (i, a) in text.enumerated() {
                    for b in text.dropFirst(i + 1) { XCTAssertFalse(a.convert(a.bounds, to: r.rootLayer).intersects(b.convert(b.bounds, to: r.rootLayer))) }
                }
            }
            for scale: CGFloat in [1, 2, 3] {
                let f = UIGraphicsImageRendererFormat(); f.scale = scale
                func png(_ v: UIView) -> Data? { UIGraphicsImageRenderer(bounds: v.bounds, format: f).image { v.layer.render(in: $0.cgContext) }.pngData() }
                XCTAssertEqual(png(reused), png(fresh), "step=\(step) scale=\(scale)")
            }
        }
    }
    func testDataLabelsAvoidPlacedAnnotationsWithoutMovingAnnotationsOrHitGeometry() throws {
        var m = model(); m.secondaryYAxis = nil; m.series[1].yAxisIndex = 0
        m.plotLines = [.init(value: 25, label: "ANNOTATION", labelStyle: .init(font: .boldSystemFont(ofSize: 24)))]
        m.plotBands = []
        var t = CartesianChartTheme(); t.showsDataLabels = true; t.showsStackTotalLabels = true
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            t.dataLabelAvoidsOverlap = false
            let v = chart(type, m, theme: t), r = v.rendererForTesting
            let original = labels(r.rootLayer, prefix: "chart.label.")
            let first = try XCTUnwrap(original.first)
            // 将标注移到一个已知数据标签的位置，以保证覆盖冲突而非依赖偶然坐标。
            let annotation = try XCTUnwrap(labels(r.rootLayer, prefix: "chart.annotation.").first)
            annotation.frame = first.convert(first.bounds, to: r.rootLayer)
            let originalAnnotation = annotation.frame
            let draw = r.currentDrawValues
            t.dataLabelAvoidsOverlap = true; r.resolveDataLabelCollisions(theme: t)
            let remaining = labels(r.rootLayer, prefix: "chart.label.")
            XCTAssertLessThan(remaining.count, original.count)
            for label in remaining {
                XCTAssertFalse(annotation.frame.insetBy(dx: -2, dy: -2).intersects(label.convert(label.bounds, to: r.rootLayer)))
            }
            XCTAssertEqual(annotation.frame, originalAnnotation)
            XCTAssertEqual(r.currentDrawValues, draw)
            // 完整 render 也应在标线生成后完成最后一次避让。
            v.update(model: m, theme: t); v.layoutIfNeeded()
            for placed in labels(r.rootLayer, prefix: "chart.annotation.") {
                for data in labels(r.rootLayer, prefix: "chart.label.") {
                    XCTAssertFalse(placed.frame.insetBy(dx: -2, dy: -2).intersects(data.convert(data.bounds, to: r.rootLayer)))
                }
            }
        }
        try check(LineChartRenderer.self); try check(ColumnChartRenderer.self)
        try check(BarChartRenderer.self); try check(CombinedChartRenderer.self)
    }
    func testObjectiveCSnapshotAndDemoBindingsUseSameAnnotationSettings() throws {
        let m = HYMCartesianModel(), s = HYMCartesianSeries(); s.identifier = "a"; s.data = [20, 25]
        m.series = [s]; m.categories = ["a", "b"]; m.minimum = 0; m.maximum = 30
        let line = HYMCartesianPlotLine(); line.value = 25; line.label = "OC"
        line.labelStyle.color = .purple; line.labelStyle.font = .boldSystemFont(ofSize: 16)
        line.labelStyle.alignment = .leading; line.labelStyle.verticalAlignment = .bottom
        line.labelStyle.bounds = .hide; line.dashStyle = "invalid"
        let band = HYMCartesianPlotBand(); band.from = 10; band.to = 22; band.label = "BAND"
        m.plotLines = [line]; m.plotBands = [band]
        let snapshot = m.build(); line.labelStyle.color = .red
        XCTAssertEqual(snapshot.plotLines[0].labelStyle.color, .purple)
        XCTAssertEqual(snapshot.plotLines[0].dashStyle, .solid)
        let bridge = HYMCartesianChartViewBridge(kind: .column, frame: CGRect(x: 0, y: 0, width: 500, height: 320))
        XCTAssertEqual(bridge.dataLabelFontSize, CartesianChartTheme().dataLabelFontSize)
        XCTAssertEqual(bridge.showsDataLabels, CartesianChartTheme().showsDataLabels)
        XCTAssertEqual(bridge.showsStackTotalLabels, CartesianChartTheme().showsStackTotalLabels)
        bridge.showsDataLabels = true; bridge.dataLabelBackgroundColor = .yellow; bridge.dataLabelAvoidsOverlap = true
        try bridge.configure(model: m); bridge.chartView.layoutIfNeeded()
        let v = try XCTUnwrap(bridge.chartView as? HYMChartView<ColumnChartRenderer>)
        XCTAssertEqual(v.rendererForTesting.currentTheme?.dataLabelBackgroundColor, .yellow)
        for kind in CartesianDemoKind.allCases {
            var state = CartesianDemoState(kind: kind); state.annotationPreset()
            XCTAssertTrue(state.builtTheme.dataLabelAvoidsOverlap)
            XCTAssertEqual(state.model.plotLines.first?.labelStyle.font?.pointSize, 15)
            let binding = Binding(get: { state }, set: { state = $0 })
            let items = CartesianDemoControls.sections(binding).flatMap(\.items).map(\.control)
            let control = try XCTUnwrap(items.first { $0.label == "参考线标签水平对齐" })
            guard case .picker(_, let value, _) = control else { return XCTFail("missing binding") }
            value.wrappedValue = CartesianAnnotationAlignment.center.rawValue
            XCTAssertEqual(state.model.plotLines.first?.labelStyle.alignment, .center)
        }
    }
}
