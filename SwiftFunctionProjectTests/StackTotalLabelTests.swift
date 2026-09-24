import XCTest
import UIKit
@testable import SwiftFunctionProject

final class StackTotalLabelTests: XCTestCase {
    private func model(_ data: [[Double]], stacking: StackConfig = .normal) -> CartesianChartModel {
        CartesianChartModel(series: data.enumerated().map {
            CartesianSeriesElement(name: "s\($0.offset)", data: $0.element)
        }, stacking: stacking)
    }

    private func render<R: CartesianRendererBase<CartesianChartTheme>>(
        _ renderer: R, model: CartesianChartModel,
        limit: Int = 200
    ) -> UIView {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        var theme = CartesianChartTheme()
        theme.showsStackTotalLabels = true
        theme.stackTotalLabelFormatter = { "sum:\($0)" }
        theme.dataLabelMaxMarkCount = limit
        renderer.mount(into: host)
        renderer.render(model: model, theme: theme,
                        context: HYMChartRenderContext(bounds: host.bounds, center: host.center))
        return host
    }

    private func labels(_ host: UIView) -> [CATextLayer] {
        func collect(_ layer: CALayer) -> [CATextLayer] {
            let own = (layer as? CATextLayer).map { [$0] } ?? []
            return own + (layer.sublayers ?? []).flatMap(collect)
        }
        return collect(host.layer).filter { ($0.string as? String)?.hasPrefix("sum:") == true }
    }

    private func texts(_ host: UIView) -> [String] {
        labels(host).compactMap { $0.string as? String }.sorted()
    }

    func testSmallSegmentsStillContributeToTotals() {
        let m = model([[1000], [0.001]])
        XCTAssertEqual(texts(render(ColumnChartRenderer(), model: m)), ["sum:1000.001"])
        XCTAssertEqual(texts(render(BarChartRenderer(), model: m)), ["sum:1000.001"])
    }

    func testAnimationReplacesLabelsInsteadOfAccumulatingThem() {
        let column = ColumnChartRenderer(), bar = BarChartRenderer()
        let m = model([[12, -5], [15, -8]])
        let ch = render(column, model: m), bh = render(bar, model: m)
        for progress in [0.1, 0.3, 0.7, 1.0] {
            column.updateSeriesAnimation(progress: progress)
            bar.updateSeriesAnimation(progress: progress)
            XCTAssertEqual(texts(ch), ["sum:-13.0", "sum:27.0"])
            XCTAssertEqual(texts(bh), ["sum:-13.0", "sum:27.0"])
        }
    }

    func testClippedChainEndDoesNotProduceMisleadingEdgeLabel() {
        var m = model([[40], [60]])
        m.yAxis = CartesianAxisModel(kind: .value, min: 0, max: 50)
        XCTAssertTrue(labels(render(ColumnChartRenderer(), model: m)).isEmpty)
        XCTAssertTrue(labels(render(BarChartRenderer(), model: m)).isEmpty)
    }

    func testMixedSignsAndPercentageModesUseRawTotals() {
        for mode in [StackConfig.normal, .percent, .percentFixed(max: 200)] {
            let m = model([[12, -5], [15, -8], [-3, 9]], stacking: mode)
            let expected = ["sum:-13.0", "sum:-3.0", "sum:27.0", "sum:9.0"]
            XCTAssertEqual(texts(render(ColumnChartRenderer(), model: m)), expected)
            XCTAssertEqual(texts(render(BarChartRenderer(), model: m)), expected)
        }
    }

    func testDualAxesHaveIndependentTotalsAndShareLabelLimit() {
        var m = model([[12], [15], [30], [40]])
        m.series[2].yAxisIndex = 1
        m.series[3].yAxisIndex = 1
        m.secondaryYAxis = CartesianAxisModel(kind: .value)
        XCTAssertEqual(texts(render(ColumnChartRenderer(), model: m)), ["sum:27.0", "sum:70.0"])
        XCTAssertTrue(labels(render(ColumnChartRenderer(), model: m, limit: 1)).isEmpty)
    }

    func testNonStackedAndAllZeroDoNotShowTotals() {
        for m in [model([[0], [0]]), model([[12], [15]], stacking: .none)] {
            XCTAssertTrue(labels(render(ColumnChartRenderer(), model: m)).isEmpty)
            XCTAssertTrue(labels(render(BarChartRenderer(), model: m)).isEmpty)
        }
    }

    func testRaggedAndMissingDataDoNotLoseValidContributions() {
        for mode in [StackConfig.normal, .percent, .percentFixed(max: 100)] {
            let m = model([[10, 20, 30], [5], [.nan, 2, .infinity]], stacking: mode)
            let expected = ["sum:15.0", "sum:22.0", "sum:30.0"]
            XCTAssertEqual(texts(render(ColumnChartRenderer(), model: m)), expected)
            XCTAssertEqual(texts(render(BarChartRenderer(), model: m)), expected)
        }
    }

    func testMissingPercentageValueDoesNotResetDenominator() {
        let series = model([[10], [.nan], [5]]).series
        let values = CartesianGeometry.percentNormalizedValues(series: series)
        XCTAssertEqual(values[0][0], 100 * 10 / 15, accuracy: 1e-9)
        XCTAssertTrue(values[1][0].isNaN)
        XCTAssertEqual(values[2][0], 100 * 5 / 15, accuracy: 1e-9)
    }

    func testLabelsRecoverWhenZoomingIntoLargeCategorySet() {
        let m = model([Array(repeating: 1, count: 300), Array(repeating: 2, count: 300)])
        let column = ColumnChartRenderer(), bar = BarChartRenderer()
        let ch = render(column, model: m, limit: 10), bh = render(bar, model: m, limit: 10)
        XCTAssertTrue(labels(ch).isEmpty)
        XCTAssertTrue(labels(bh).isEmpty)
        column.maximumXAxisZoomScale = 1000
        bar.maximumYAxisZoomScale = 1000
        column.setXAxisViewport(49.5...54.5)
        bar.setYAxisViewport(49.5...54.5)
        XCTAssertEqual(texts(ch), Array(repeating: "sum:3.0", count: 5))
        XCTAssertEqual(texts(bh), Array(repeating: "sum:3.0", count: 5))
        for label in labels(ch) { XCTAssertTrue(column.currentPlotFrame.contains(label.frame)) }
        for label in labels(bh) { XCTAssertTrue(bar.currentPlotFrame.contains(label.frame)) }
    }

    func testLabelsRemainInsidePlotAndDoNotOverlapTitleOrAxisLabels() {
        var m = model([[12, -5], [15, -8]])
        m.title = "Stack totals"
        m.yAxis = CartesianAxisModel(kind: .value, min: -13, max: 27)
        let column = ColumnChartRenderer(), bar = BarChartRenderer()
        let ch = render(column, model: m), bh = render(bar, model: m)
        XCTAssertEqual(labels(ch).count, 2)
        XCTAssertEqual(labels(bh).count, 2)
        for label in labels(ch) { XCTAssertTrue(column.currentPlotFrame.contains(label.frame)) }
        for label in labels(bh) { XCTAssertTrue(bar.currentPlotFrame.contains(label.frame)) }
    }
}
