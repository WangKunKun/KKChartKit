import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class AxisStyleTests: XCTestCase {
    private func model(horizontal: Bool = false) -> CartesianChartModel {
        var result = CartesianChartModel(series: [
            .init(name: "Power", data: [10, 40, 20, 80, 50, 70, 30, 60], id: "power", kind: .column),
            .init(name: "Percent", data: [1, 2, 3, 4, 5, 6, 7, 8], yAxisIndex: 1, id: "percent", kind: .line)
        ], xAxis: .init(kind: .category(labels: (0..<8).map { "C\($0)" })),
           yAxis: .init(kind: .value, min: 0, max: 100, tickPositions: [0, 50, 100]),
           secondaryYAxis: .init(kind: .value, min: 0, max: 10, tickPositions: [0, 5, 10]))
        if horizontal {
            result.secondaryYAxis = nil
            result.series[1].yAxisIndex = 0
        }
        return result
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
        _ m: CartesianChartModel, theme: CartesianChartTheme = .init(), width: CGFloat = 600) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: width, height: 360))
        view.configure(model: m, theme: theme); view.layoutIfNeeded(); return view
    }
    private func labels(_ view: UIView, _ edge: String) -> [UILabel] {
        view.subviews.compactMap { $0 as? UILabel }.filter { $0.accessibilityIdentifier == "chart.axis." + edge }
    }
    private func lines(_ renderer: CartesianRendererBase<CartesianChartTheme>) -> [String: CAShapeLayer] {
        Dictionary(uniqueKeysWithValues: (renderer.rootLayer.sublayers ?? []).compactMap {
            guard let layer = $0 as? CAShapeLayer, let name = layer.name, name.hasPrefix("axis.") else { return nil }
            return (name, layer)
        })
    }
    private func image(_ view: UIView, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = scale
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { view.layer.render(in: $0.cgContext) }
    }

    func testIndependentAxisColorsFontsAndLinesAcrossFourRenderers() {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) {
            var m = model(horizontal: ObjectIdentifier(type) == ObjectIdentifier(BarChartRenderer.self))
            m.xAxis.style = .init(labelColor: .purple, labelFont: .boldSystemFont(ofSize: 18), lineColor: .red, lineWidth: 2)
            m.yAxis.style = .init(labelColor: .blue, labelFont: .systemFont(ofSize: 13), lineColor: .green, lineWidth: 3)
            m.secondaryYAxis?.style = .init(labelColor: .orange, labelFont: .systemFont(ofSize: 21), lineColor: .cyan, lineWidth: 4)
            let v = chart(type, m), horizontal = v.rendererForTesting.isHorizontalValueAxis
            for (edge, color, font): (String, UIColor, CGFloat) in [
                (horizontal ? "left" : "bottom", .purple, 18),
                (horizontal ? "bottom" : "left", .blue, 13)] {
                let found = labels(v, edge)
                XCTAssertFalse(found.isEmpty, edge)
                XCTAssertTrue(found.allSatisfy { $0.textColor == color && $0.font.pointSize == font })
            }
            let axisLines = lines(v.rendererForTesting)
            XCTAssertEqual(axisLines[horizontal ? "axis.left" : "axis.bottom"]?.strokeColor, UIColor.red.cgColor)
            XCTAssertEqual(axisLines[horizontal ? "axis.bottom" : "axis.left"]?.lineWidth, 3)
            if horizontal { XCTAssertNil(axisLines["axis.right"]); XCTAssertTrue(labels(v, "right").isEmpty) }
            else {
                XCTAssertEqual(axisLines["axis.right"]?.strokeColor, UIColor.cyan.cgColor)
                XCTAssertTrue(labels(v, "right").allSatisfy { $0.textColor == .orange && $0.font.pointSize == 21 })
            }
        }
        check(LineChartRenderer.self); check(ColumnChartRenderer.self)
        check(BarChartRenderer.self); check(CombinedChartRenderer.self)
    }

    func testHiddenLabelsReleaseLayoutWithoutChangingDomainsDataOrGridSettings() throws {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            var m = model(horizontal: ObjectIdentifier(type) == ObjectIdentifier(BarChartRenderer.self)); m.yAxis.showsGridlines = true; m.xAxis.showsGridlines = true
            let v = chart(type, m), r = v.rendererForTesting
            let before = r.currentPlotFrame, domain = r.currentViewport, ticks = r.currentValueTicks
            let datum = try XCTUnwrap(r.datum(series: 0, category: 2))
            m.xAxis.style.showsLabels = false; m.yAxis.style.showsLabels = false
            m.secondaryYAxis?.style.showsLabels = false
            v.update(model: m); v.layoutIfNeeded()
            XCTAssertGreaterThan(r.currentPlotFrame.width, before.width)
            XCTAssertGreaterThan(r.currentPlotFrame.height, before.height)
            XCTAssertEqual(r.currentViewport.xMin, domain.xMin); XCTAssertEqual(r.currentViewport.yMax, domain.yMax)
            XCTAssertEqual(r.currentValueTicks, ticks); XCTAssertEqual(r.datum(series: 0, category: 2)?.rawValue, datum.rawValue)
            XCTAssertTrue(["left", "bottom", "right"].allSatisfy { labels(v, $0).isEmpty })
            XCTAssertEqual(lines(r).count, r.isHorizontalValueAxis ? 2 : 3)
            let hidden = r.currentPlotFrame
            m.xAxis.style.showsLine = false; m.yAxis.style.showsLine = false; m.secondaryYAxis?.style.showsLine = false
            v.update(model: m); v.layoutIfNeeded()
            XCTAssertTrue(lines(r).isEmpty); XCTAssertEqual(r.currentPlotFrame, hidden)
            XCTAssertEqual(r.currentModel?.yAxis.showsGridlines, true)
            let grid = r.rootLayer.sublayers?.first as? CAShapeLayer
            XCTAssertNotNil(grid?.path); XCTAssertFalse(grid?.path?.isEmpty ?? true)
            m.xAxis.style = .init(); m.yAxis.style = .init(); m.secondaryYAxis?.style = .init()
            v.update(model: m); v.layoutIfNeeded(); XCTAssertEqual(r.currentPlotFrame, before)
        }
        try check(LineChartRenderer.self); try check(ColumnChartRenderer.self)
        try check(BarChartRenderer.self); try check(CombinedChartRenderer.self)
    }

    func testExplicitCategoryCadenceIsAbsoluteAndDensityUsesMultiples() {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) {
            var m = model(horizontal: ObjectIdentifier(type) == ObjectIdentifier(BarChartRenderer.self)); m.xAxis.categoryLabelInterval = 3
            let v = chart(type, m), r = v.rendererForTesting
            let edge = r.isHorizontalValueAxis ? "left" : "bottom"
            XCTAssertEqual(labels(v, edge).compactMap(\.text), ["C0", "C3", "C6"])
            v.showCategoryRange(2..<8); v.layoutIfNeeded()
            XCTAssertEqual(labels(v, edge).compactMap(\.text), ["C3", "C6"])
            m.xAxis.categoryLabelInterval = 0; v.update(model: m); v.layoutIfNeeded()
            XCTAssertTrue(labels(v, edge).contains { $0.text == "C2" })
        }
        check(ColumnChartRenderer.self); check(BarChartRenderer.self)
        XCTAssertEqual(AxisRenderer.labelStride(automatic: 5, interval: 3), 6)
        XCTAssertEqual(AxisRenderer.labelStride(automatic: 3, interval: -1), 3)
        XCTAssertEqual(AxisRenderer.labelStride(automatic: Int.max, interval: Int.max - 1), Int.max)
        XCTAssertEqual(CartesianGeometry.categoryLabelStride(labelWidth: .greatestFiniteMagnitude, slotWidth: 0.01), Int.max)
    }

    func testLargeFontsRotationNarrowBoundsAndLegendDoNotOverflow() {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) {
            for rotation: CGFloat in [-90, -45, 0, 45, 90, .nan] {
                var m = model(horizontal: ObjectIdentifier(type) == ObjectIdentifier(BarChartRenderer.self)), t = CartesianChartTheme()
                m.xAxis.kind = .category(labels: (0..<8).map { "非常长的类目名称-\($0)" })
                m.xAxis.style.labelFont = .boldSystemFont(ofSize: 38); m.xAxis.tickLabelRotation = rotation
                m.yAxis.style.labelFont = .systemFont(ofSize: 32)
                m.secondaryYAxis?.style.labelFont = .systemFont(ofSize: 36)
                m.yAxis.labelFormatter = { "Long value \($0)" }
                t.legend.isEnabled = true; t.legend.position = .bottom
                let v = chart(type, m, theme: t, width: 180), r = v.rendererForTesting
                XCTAssertGreaterThan(r.currentPlotFrame.width, 0); XCTAssertGreaterThan(r.currentPlotFrame.height, 0)
                for edge in ["left", "bottom", "right"] {
                    let found = labels(v, edge)
                    for label in found {
                        XCTAssertTrue(v.bounds.insetBy(dx: -0.01, dy: -0.01).contains(label.frame), "\(edge): \(label.frame)")
                    }
                    for i in found.indices { for j in found.indices where i < j {
                        XCTAssertFalse(found[i].frame.intersects(found[j].frame))
                    }}
                }
            }
        }
        check(LineChartRenderer.self); check(ColumnChartRenderer.self)
        check(BarChartRenderer.self); check(CombinedChartRenderer.self)
    }

    func testReuseAndThemeInheritanceRestoreAtThreeRasterScales() {
        var m = model(), t = CartesianChartTheme()
        let reused = chart(CombinedChartRenderer.self, m)
        for step in 0..<7 {
            switch step {
            case 0: m.xAxis.style = .init(labelColor: .purple, labelFont: .systemFont(ofSize: 21)); m.xAxis.tickLabelRotation = 40
            case 1: m.xAxis.style.showsLabels = false; m.yAxis.style.showsLine = false
            case 2: m.secondaryYAxis?.style = .init(labelColor: .cyan, lineWidth: 6)
            case 3: m = model(); t.tickLabelColor = .red; t.tickLabelFont = .boldSystemFont(ofSize: 15)
            case 4: m.series = []
            default: m = model()
            }
            t.reusesRenderingObjects = true; reused.update(model: m, theme: t); reused.layoutIfNeeded()
            t.reusesRenderingObjects = false; let fresh = chart(CombinedChartRenderer.self, m, theme: t)
            for scale: CGFloat in [1, 2, 3] {
                XCTAssertEqual(image(reused, scale: scale).pngData(), image(fresh, scale: scale).pngData(), "step=\(step)")
            }
        }
        let attachment = XCTAttachment(image: image(reused, scale: 2)); attachment.name = "g3-axis-inheritance"
        attachment.lifetime = .keepAlways; add(attachment)
        let invalid = CartesianAxisStyle(lineWidth: .nan).resolving(t)
        XCTAssertEqual(invalid.axisLineWidth, t.axisLineWidth)
    }

    func testOCSnapshotAndThreeViewKindsRestore() throws {
        let source = HYMCartesianModel(); source.categories = ["A", "B", "C"]; source.usesSecondaryAxis = true
        let series = HYMCartesianSeries(); series.data = [10, 20, 30]; source.series = [series]
        source.categoryLabelInterval = 2; source.xAxisStyle.labelColor = .purple
        source.yAxisStyle.showsLabels = false; source.secondaryYAxisStyle.lineWidth = 4
        source.valueGridlines = true; source.categoryLabelRotation = -30
        let snapshot = source.build(); source.xAxisStyle.labelColor = .green
        XCTAssertEqual(snapshot.xAxis.style.labelColor, .purple)
        XCTAssertEqual(snapshot.xAxis.categoryLabelInterval, 2); XCTAssertEqual(snapshot.xAxis.tickLabelRotation, -30)
        for kind in [HYMCartesianChartKind.column, .bar, .combined] {
            source.usesSecondaryAxis = kind != .bar
            let bridge = HYMCartesianChartViewBridge(kind: kind, frame: CGRect(x: 0, y: 0, width: 600, height: 360))
            try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
            source.yAxisStyle.showsLabels = true; source.xAxisStyle = HYMCartesianAxisStyle()
            try bridge.update(model: source, preserveViewport: true); bridge.chartView.layoutIfNeeded()
            XCTAssertTrue(bridge.chartView.subviews.compactMap { $0 as? UILabel }.contains { $0.accessibilityIdentifier?.hasPrefix("chart.axis.") == true })
        }
    }

    func testDemoAllAxisStyleBindingsAndResetOnExistingPages() throws {
        for kind in [CartesianDemoKind.line, .column, .bar, .combined] {
            var state = CartesianDemoState(kind: kind)
            let b = Binding(get: { state }, set: { state = $0 })
            state.independentAxesPreset()
            XCTAssertEqual(state.model.xAxis.categoryLabelInterval, 2)
            for title in ["类目轴", "主值轴"] + (kind == .bar ? [] : ["次值轴"]) {
                func item(_ label: String) throws -> ChartDemoPanel.Item {
                    let section = try XCTUnwrap(CartesianDemoControls.sections(b).first { $0.title == title })
                    return try XCTUnwrap(section.items.first { $0.label == label })
                }
                guard case .toggle(_, let shown) = try item("轴标签显示").control else { return XCTFail() }
                shown.wrappedValue = false
                let axis = title == "类目轴" ? state.model.xAxis : title == "主值轴" ? state.model.yAxis : state.model.secondaryYAxis!
                XCTAssertFalse(axis.style.showsLabels)
                guard case .toggle(_, let customFont) = try item("自定义轴标签字体").control else { return XCTFail() }
                customFont.wrappedValue = false
                XCTAssertNil(title == "类目轴" ? state.categoryAxis.style.labelFont : title == "主值轴" ? state.primaryAxis.style.labelFont : state.secondaryAxis.style.labelFont)
            }
            state.reset()
            XCTAssertNil(state.model.xAxis.style.labelColor); XCTAssertTrue(state.model.yAxis.style.showsLabels)
            XCTAssertNil(state.model.xAxis.categoryLabelInterval)
        }
    }
}
