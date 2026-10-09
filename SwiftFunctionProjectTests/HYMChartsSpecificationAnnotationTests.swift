import XCTest
import UIKit
@testable import SwiftFunctionProject

@MainActor final class HYMChartsSpecificationAnnotationTests: XCTestCase {
    private let adapter = HYMChartsSpecificationAdapter()
    private func source(_ kind: CartesianDemoKind = .column, secondary: Bool = false) -> ChartSpecification {
        var settings = ChartSpecificationDemoSettings(); settings.secondaryAxis = secondary
        var value = settings.specification(kind: kind); value.schemaVersion = 5
        value.valueAxes[0].minimum = -100; value.valueAxes[0].maximum = 150
        if secondary { value.valueAxes[1].minimum = 0; value.valueAxes[1].maximum = 1000 }
        value.plotLines = [.init(id: "limit", valueAxisID: "power", value: 40, label: "limit",
                                labelStyle: .init(verticalAlignment: .center))]
        value.plotBands = [.init(id: "range", valueAxisID: "power", from: -150, to: -50,
                                color: .init(red: 0.2, green: 0.5, blue: 0.9, alpha: 0.27), label: "range")]
        return value
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ source: ChartSpecification) throws -> HYMChartView<R> {
        let output = try adapter.makeConfiguration(from: source)
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 640, height: 400))
        view.configure(model: output.model, theme: output.theme); view.layoutIfNeeded(); return view
    }
    private func labels(_ root: CALayer) -> [CATextLayer] {
        (root.sublayers ?? []).compactMap { $0 as? CATextLayer }.filter { $0.name?.hasPrefix("chart.annotation.") == true }
    }

    func testStableAxisAndAnnotationIDsSurviveReorderAndHiddenItemsRemainInSource() throws {
        var input = source(.combined, secondary: true)
        input.plotLines.append(.init(id: "other", valueAxisID: "temperature", value: 500))
        input.plotLines.append(.init(id: "hidden", valueAxisID: "power", value: 90, isVisible: false))
        var output = try adapter.makeConfiguration(from: input)
        XCTAssertEqual(output.model.plotLines.map(\.yAxisIndex), [0, 1])
        XCTAssertEqual(output.source.plotLines.map(\.id), ["limit", "other", "hidden"])
        input.valueAxes.reverse(); input.plotLines.reverse(); input.series.reverse()
        output = try adapter.makeConfiguration(from: input)
        XCTAssertEqual(output.model.plotLines.map(\.value), [500, 40])
        XCTAssertEqual(output.model.plotLines.map(\.yAxisIndex), [0, 1])
        XCTAssertEqual(output.model.plotBands[0].yAxisIndex, 1)
        XCTAssertEqual(output.source.series, input.series)
        input.plotLines[0].isVisible = true
        XCTAssertEqual(try adapter.makeConfiguration(from: input).model.plotLines.map(\.value), [90, 500, 40])
    }

    func testStylesMapAllWeightsDefaultsPatternsColorsOffsetsAndBounds() throws {
        var input = source()
        let nativeWeights: [UIFont.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        XCTAssertNil(try adapter.makeConfiguration(from: input).model.plotLines[0].labelStyle.font)
        for (weight, expected) in zip(ChartFontWeight.allCases, nativeWeights) {
            input.plotLines[0].labelStyle = .init(fontSize: 17, fontWeight: weight, alignment: .trailing,
                verticalAlignment: .bottom, offsetX: -5, offsetY: 7, bounds: .hide)
            let style = try adapter.makeConfiguration(from: input).model.plotLines[0].labelStyle
            XCTAssertEqual(style.font, UIFont.systemFont(ofSize: 17, weight: expected))
            XCTAssertEqual(style.alignment, .trailing); XCTAssertEqual(style.verticalAlignment, .bottom)
            XCTAssertEqual(style.offset, CGSize(width: -5, height: 7)); XCTAssertEqual(style.bounds, .hide)
        }
        input.plotLines[0].labelStyle = .init(fontSize: 18)
        XCTAssertEqual(try adapter.makeConfiguration(from: input).model.plotLines[0].labelStyle.font, .systemFont(ofSize: 18, weight: .medium))
        for (a, b) in zip(ChartAnnotationAlignment.allCases, CartesianAnnotationAlignment.allCases) {
            input.plotLines[0].labelStyle.alignment = a
            XCTAssertEqual(try adapter.makeConfiguration(from: input).model.plotLines[0].labelStyle.alignment, b)
        }
        for (a, b) in zip(ChartAnnotationVerticalAlignment.allCases, CartesianAnnotationVerticalAlignment.allCases) {
            input.plotLines[0].labelStyle.verticalAlignment = a
            XCTAssertEqual(try adapter.makeConfiguration(from: input).model.plotLines[0].labelStyle.verticalAlignment, b)
        }
        for (a, b) in zip([ChartStrokePattern.solid, .dashed, .dotted], [LineDashStyle.solid, .dash, .dot]) {
            input.plotLines[0].strokePattern = a; input.plotLines[0].lineWidth = 2
            let line = try adapter.makeConfiguration(from: input).model.plotLines[0]
            XCTAssertEqual(line.dashStyle, b); XCTAssertEqual(line.lineWidth, 2)
        }
        let rgba = ChartRGBA(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.25)
        input.plotLines[0].color = rgba; input.plotLines[0].labelStyle.color = rgba
        input.plotLines[0].labelStyle.backgroundColor = rgba
        let line = try adapter.makeConfiguration(from: input).model.plotLines[0]
        let color = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.25)
        XCTAssertEqual(line.color, color); XCTAssertEqual(line.labelStyle.color, color)
        XCTAssertEqual(line.labelStyle.backgroundColor, color)
    }

    func testFourRenderersClipBandsPlaceLabelsAndRetainFixedLayeringWithoutExpandingDomain() throws {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ kind: CartesianDemoKind) throws {
            let input = source(kind), output = try adapter.makeConfiguration(from: input)
            let view = try chart(type, input), r = view.rendererForTesting
            let texts = labels(r.rootLayer); XCTAssertEqual(texts.count, 2)
            XCTAssertTrue(texts.allSatisfy { r.currentPlotFrame.contains($0.frame) })
            let layers = r.rootLayer.sublayers ?? [], seriesIndex = try XCTUnwrap(layers.firstIndex(of: r.seriesLayer))
            let band = try XCTUnwrap(layers.first { !($0 is CATextLayer) && $0.backgroundColor == output.model.plotBands[0].color.cgColor })
            XCTAssertLessThan(try XCTUnwrap(layers.firstIndex(of: band)), seriesIndex)
            XCTAssertTrue(texts.allSatisfy { (layers.firstIndex(of: $0) ?? -1) > seriesIndex })
            XCTAssertEqual(kind == .bar ? r.currentViewport.xDomain : r.currentViewport.yDomain, -100...150)
            if kind == .bar {
                XCTAssertEqual(band.frame.minX, r.currentPlotFrame.minX, accuracy: 0.01)
                XCTAssertEqual(band.frame.width, r.currentPlotFrame.width * 0.2, accuracy: 0.01)
            } else {
                XCTAssertEqual(band.frame.maxY, r.currentPlotFrame.maxY, accuracy: 0.01)
                XCTAssertEqual(band.frame.height, r.currentPlotFrame.height * 0.2, accuracy: 0.01)
            }
            XCTAssertEqual(r.datum(series: 0, category: 0)?.rawValue, 40)
        }
        try check(LineChartRenderer.self, .line); try check(ColumnChartRenderer.self, .column)
        try check(BarChartRenderer.self, .bar); try check(CombinedChartRenderer.self, .combined)
    }

    func testSecondaryAxisPositionAndOutOfRangeLabels() throws {
        var input = source(.combined, secondary: true)
        input.plotLines[0].valueAxisID = "temperature"; input.plotLines[0].value = 500
        let view = try chart(CombinedChartRenderer.self, input), r = view.rendererForTesting
        let label = try XCTUnwrap(labels(r.rootLayer).first { $0.name == "chart.annotation.line" })
        XCTAssertEqual(label.frame.midY, r.currentPlotFrame.midY, accuracy: 0.01)
        input.plotLines[0].value = 2000; input.plotBands[0].from = 200; input.plotBands[0].to = 300
        view.update(model: try adapter.makeConfiguration(from: input).model); view.layoutIfNeeded()
        XCTAssertTrue(labels(r.rootLayer).isEmpty)
        XCTAssertEqual(r.currentSecondaryYDomain, 0...1000)
    }

    func testG1PercentMissingValuesAndHitGeometryAreUnaffected() throws {
        for boundary in ChartStackedAreaBoundary.allCases {
            for stacking in [ChartStackingPolicy.sum, .percentOfAbsoluteTotal, .percentOfFixedTotal(200)] {
                var input = source(.line); input.stackedAreaBoundary = boundary; input.stacking = stacking
                let output = try adapter.makeConfiguration(from: input)
                let view = try chart(LineChartRenderer.self, input), r = view.rendererForTesting
                let target = try XCTUnwrap(r.makeHitTarget(seriesIndex: 0, categoryIndex: 0, value: 40))
                let hit = r.hitFrame(for: target), viewport = r.currentViewport
                input.plotLines = []; input.plotBands = []
                let bare = try adapter.makeConfiguration(from: input)
                view.update(model: bare.model); view.layoutIfNeeded()
                XCTAssertEqual(r.hitFrame(for: target), hit)
                XCTAssertEqual(r.currentViewport.yDomain, viewport.yDomain)
                XCTAssertEqual(r.datum(series: 0, category: 0)?.rawValue, 40)
                XCTAssertTrue(bare.model.series[0].data[2].isNaN)
                XCTAssertEqual(output.source.series, bare.source.series)
                for (a, b) in zip(output.model.stackedDrawValues.flatMap({ $0 }), bare.model.stackedDrawValues.flatMap({ $0 })) {
                    XCTAssertTrue(a == b || (a.isNaN && b.isNaN))
                }
                XCTAssertEqual(output.model.plotLines[0].value, 40) // percent is already a logical percentage, never renormalized
            }
        }
    }

    func testLongTextClampHideResizeAndVisibilityReuse() throws {
        var input = source(); input.plotBands = []; input.plotLines[0].label = String(repeating: "阈值 label ", count: 40)
        let view = try chart(ColumnChartRenderer.self, input), r = view.rendererForTesting
        XCTAssertEqual(labels(r.rootLayer).first?.truncationMode, .end)
        XCTAssertEqual(try XCTUnwrap(labels(r.rootLayer).first).frame.width, r.currentPlotFrame.width - 4, accuracy: 0.01)
        input.plotLines[0].labelStyle.bounds = .hide
        view.update(model: try adapter.makeConfiguration(from: input).model); view.layoutIfNeeded()
        XCTAssertTrue(labels(r.rootLayer).isEmpty)
        input.plotLines[0].label = "short"; input.plotLines[0].labelStyle.bounds = .clamp
        input.plotLines[0].labelStyle.offsetX = 1e9; input.plotLines[0].labelStyle.offsetY = -1e9
        view.bounds.size.width = 320
        view.update(model: try adapter.makeConfiguration(from: input).model); view.layoutIfNeeded()
        XCTAssertTrue(r.currentPlotFrame.contains(try XCTUnwrap(labels(r.rootLayer).first).frame))
        input.plotLines[0].isVisible = false
        view.update(model: try adapter.makeConfiguration(from: input).model); view.layoutIfNeeded()
        XCTAssertTrue(labels(r.rootLayer).isEmpty)
    }

    func testDemoPerAxisAndPerObjectStateResetAndSecondaryToggle() throws {
        for kind in [CartesianDemoKind.line, .column, .bar, .combined] {
            var settings = ChartSpecificationDemoSettings(); settings.secondaryAxis = true
            var main = ChartSpecificationAnnotationDemoSettings(axisID: "power")
            main.lineEnabled = true; main.bandEnabled = true; main.line.value = 12
            var secondary = ChartSpecificationAnnotationDemoSettings(axisID: "temperature"); secondary.lineEnabled = true
            settings.annotations = ["power": main, "temperature": secondary]
            let source = settings.specification(kind: kind)
            XCTAssertEqual(source.schemaVersion, 5); XCTAssertEqual(source.plotLines.first?.value, 12)
            XCTAssertEqual(source.plotLines.count, kind == .bar ? 1 : 2)
            XCTAssertEqual(source.plotBands.first?.valueAxisID, "power")
            XCTAssertNoThrow(try adapter.makeConfiguration(from: source))
            settings.secondaryAxis = false
            XCTAssertEqual(settings.specification(kind: kind).plotLines.count, 1)
            XCTAssertTrue(settings.annotations["temperature"]?.lineEnabled == true)
            settings = .init(); let reset = settings.specification(kind: kind)
            XCTAssertEqual(reset.schemaVersion, 1); XCTAssertTrue(reset.plotLines.isEmpty && reset.plotBands.isEmpty)
        }
    }

    func testOCUpdatesAreAtomicPreserveViewportAndDoNotRelaxG6Rejections() throws {
        var input = source()
        let document = try HYMChartSpecificationDocument(jsonData: input.jsonData())
        let bridge = try document.makeNativeBridge(frame: CGRect(x: 0, y: 0, width: 640, height: 400))
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<ColumnChartRenderer>)
        view.layoutIfNeeded(); let r = view.rendererForTesting
        r.minimumXAxisCategories = 2; r.zoomXAxis(factor: 2, anchorScreenX: r.currentPlotFrame.midX)
        let viewport = r.xAxisViewport
        input.plotLines[0].value = 55; input.plotLines[0].label = "updated"
        try bridge.update(specification: HYMChartSpecificationDocument(specification: input), preserveViewport: true)
        view.layoutIfNeeded(); XCTAssertEqual(r.xAxisViewport, viewport)
        XCTAssertEqual(r.currentModel?.plotLines.first?.value, 55)
        var bad = input; bad.valueAxes[0].isReversed = true
        XCTAssertThrowsError(try bridge.update(specification: HYMChartSpecificationDocument(specification: bad), preserveViewport: false))
        XCTAssertEqual(r.xAxisViewport, viewport); XCTAssertEqual(r.currentModel?.plotLines.first?.label, "updated")
        XCTAssertEqual(try ChartSpecification.decodeJSON(document.jsonData()).plotLines.first?.value, 40)
        bad = input; bad.plotLines[0].valueAxisID = "missing"
        XCTAssertThrowsError(try HYMChartSpecificationDocument(specification: bad))
        input.plotLines = []; input.plotBands = []
        try bridge.update(specification: HYMChartSpecificationDocument(specification: input), preserveViewport: false)
        view.layoutIfNeeded(); XCTAssertEqual(r.xAxisViewport, r.fullXAxisDomain); XCTAssertTrue(labels(r.rootLayer).isEmpty)
        bad = source(.bar); bad.valueAxes.append(.init(id: "other"))
        XCTAssertTrue(adapter.diagnostics(for: bad).contains { $0.code == .unsupportedCapability && $0.path == "valueAxes" })
        bad = source(); bad.domain = .numeric
        for i in bad.series.indices { for j in bad.series[i].samples.indices { bad.series[i].samples[j].coordinate = .number(Double(j)) } }
        XCTAssertTrue(adapter.diagnostics(for: bad).contains { $0.code == .unsupportedCapability && $0.path == "domain" })
    }
}
