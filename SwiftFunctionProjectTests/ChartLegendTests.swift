import XCTest
import SwiftUI
@testable import SwiftFunctionProject

final class ChartLegendTests: XCTestCase {
    private func model(_ stacking: StackConfig? = nil) -> CartesianChartModel {
        CartesianChartModel(title: "Energy", series: [
            .init(name: "Solar", data: [20, 30, 40], color: .systemBlue, id: "solar"),
            .init(name: "Battery", data: [60, 50, 70], color: .systemOrange, id: "battery"),
            .init(name: "Grid", data: [10, 15, 20], color: .systemGreen, id: "grid")
        ], stacking: stacking)
    }

    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(
        _ renderer: R.Type, model: CartesianChartModel? = nil,
        position: ChartLegendPosition = .bottom
    ) -> HYMChartView<R> {
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = true
        theme.legend.position = position
        let chart = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 390, height: 340))
        chart.configure(model: model ?? self.model(), theme: theme)
        chart.layoutIfNeeded()
        return chart
    }

    func testDefaultOffAndEmptyLegendDoNotReserveSpace() {
        let chart = chart(LineChartRenderer.self)
        var theme = CartesianChartTheme()
        chart.update(theme: theme)
        chart.layoutIfNeeded()
        let plot = chart.rendererForTesting.currentPlotFrame
        XCTAssertTrue(chart.rendererForTesting.legendView.isHidden)
        var noItems = model()
        for i in noItems.series.indices { noItems.series[i].showsInLegend = false }
        theme.legend.isEnabled = true
        chart.update(model: noItems, theme: theme)
        chart.layoutIfNeeded()
        XCTAssertEqual(chart.rendererForTesting.currentPlotFrame, plot)
        XCTAssertTrue(chart.rendererForTesting.legendView.isHidden)
    }

    func testDefaultSymbolAndPerIDOverrides() {
        var data = model()
        data.series[0].pointSymbol = .diamond
        data.series[0].legendOrder = 10
        data.series[2].showsInLegend = false
        let chart = chart(LineChartRenderer.self, model: data)
        var theme = CartesianChartTheme()
        theme.showsPoints = true
        theme.legend.isEnabled = true
        theme.legend.itemOverrides["battery"] = .init(title: "Storage", symbol: .rectangle, symbolColor: .purple)
        chart.update(theme: theme)
        chart.layoutIfNeeded()
        let items = chart.rendererForTesting.legendItems
        XCTAssertEqual(items.map(\.id), ["battery", "solar"])
        XCTAssertEqual(items[0].title, "Storage")
        XCTAssertEqual(items[0].color, .purple)
        if case .rectangle = items[0].symbol {} else { XCTFail("explicit symbol") }
        if case .lineWithMarker(.diamond) = items[1].symbol {} else { XCTFail("series marker") }
        XCTAssertEqual(chart.rendererForTesting.currentModel?.series[1].color, .systemOrange)
        let column = self.chart(ColumnChartRenderer.self)
        if case .roundedRectangle = column.rendererForTesting.legendItems[0].symbol {} else { XCTFail("column symbol") }
    }

    func testFourPositionsReserveSpaceOutsidePlotAndTitle() {
        for position in ChartLegendPosition.allCases {
            let chart = chart(ColumnChartRenderer.self, position: position)
            let r = chart.rendererForTesting
            let legend = r.legendView.frame
            let plot = r.currentPlotFrame
            XCTAssertFalse(legend.intersects(plot), "\(position)")
            XCTAssertTrue(chart.bounds.contains(legend), "\(position)")
            XCTAssertGreaterThanOrEqual(plot.height, 80)
            XCTAssertGreaterThanOrEqual(plot.width, 80)
            let title = chart.subviews.compactMap { $0 as? UILabel }.first { $0.text == "Energy" }
            XCTAssertFalse(title!.frame.intersects(legend))
            switch position {
            case .top: XCTAssertLessThan(legend.maxY, plot.minY)
            case .bottom: XCTAssertGreaterThan(legend.minY, plot.maxY)
            case .left: XCTAssertLessThan(legend.maxX, plot.minX)
            case .right: XCTAssertGreaterThan(legend.minX, plot.maxX)
            }
        }
    }

    func testWrapScrollLimitAndAlignment() {
        let items = (0..<12).map { index in
            ChartLegendItem(id: "\(index)", title: "Series \(index)", symbol: .rectangle,
                            color: .blue, dashStyle: .solid, isVisible: true)
        }
        var c = ChartLegendConfiguration()
        c.isEnabled = true
        c.maxRows = 2
        c.maxHeight = 500
        let available = CGRect(x: 10, y: 20, width: 240, height: 300)
        let plot = CGRect(x: 40, y: 30, width: 210, height: 240)
        let layout = ChartLegendLayout.make(items: items, configuration: c, available: available, plot: plot)
        XCTAssertGreaterThan(layout.contentSize.height, layout.frame.height)
        XCTAssertEqual(layout.frame.height, 68)
        XCTAssertEqual(layout.itemFrames.count, items.count)
        for frame in layout.itemFrames { XCTAssertLessThanOrEqual(frame.maxX, available.width) }
        let one = Array(items.prefix(1))
        c.alignment = .leading
        let leading = ChartLegendLayout.make(items: one, configuration: c, available: available, plot: plot)
        c.alignment = .trailing
        let trailing = ChartLegendLayout.make(items: one, configuration: c, available: available, plot: plot)
        XCTAssertEqual(leading.itemFrames[0].minX, 0)
        XCTAssertEqual(trailing.itemFrames[0].maxX, available.width)
        let view = ChartLegendView()
        view.update(items: items, configuration: c, layout: layout)
        view.contentOffset.y = 20
        let first = view.buttons[0]
        view.update(items: items, configuration: c, layout: layout)
        XCTAssertTrue(view.buttons[0] === first, "redraw must preserve scroll controls")
        XCTAssertEqual(view.contentOffset.y, 20)
    }

    func testSmallContainerAndLongLabelsCannotConsumeMinimumPlot() {
        let item = ChartLegendItem(id: "a", title: String(repeating: "Very long", count: 100),
                                   symbol: .line, color: .blue, dashStyle: .solid, isVisible: true)
        var c = ChartLegendConfiguration()
        c.isEnabled = true
        let plot = CGRect(x: 30, y: 20, width: 100, height: 85)
        let layout = ChartLegendLayout.make(items: [item], configuration: c,
                                            available: CGRect(x: 0, y: 0, width: 150, height: 140), plot: plot)
        XCTAssertTrue(layout.itemFrames.isEmpty)
        XCTAssertEqual(layout.plotFrame, plot)
        let larger = ChartLegendLayout.make(items: [item], configuration: c,
                                             available: CGRect(x: 0, y: 0, width: 150, height: 300),
                                             plot: CGRect(x: 30, y: 20, width: 100, height: 240))
        XCTAssertEqual(larger.itemFrames[0].width, 150)
        XCTAssertGreaterThanOrEqual(larger.plotFrame.height, 80)
    }

    func testClickPreservesLegendAndClearsSelectionWithoutPlotHit() {
        let chart = chart(LineChartRenderer.self)
        chart.isSharedTooltipOnTapEnabled = false
        var hits = 0
        var invalidations = 0
        var changed: [String] = []
        chart.onHit = { _, _ in hits += 1 }
        chart.onHitLocated = { context, _ in if context == nil { invalidations += 1 } }
        chart.onSeriesVisibilityChanged = { id, visible in changed.append("\(id):\(visible)") }
        let r = chart.rendererForTesting
        chart.performTap(at: r.testScreenPoint(series: 0, index: 1))
        XCTAssertEqual(hits, 1)
        let oldLegend = r.legendView.frame
        r.legendView.buttons[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(chart.isSeriesVisible("solar"), false)
        XCTAssertEqual(changed, ["solar:false"])
        XCTAssertEqual(invalidations, 1)
        XCTAssertFalse(chart.isCrosshairVisibleForTesting)
        XCTAssertEqual(r.legendView.buttons.count, 3)
        XCTAssertEqual(r.legendView.frame, oldLegend)
        XCTAssertEqual(r.legendView.buttons[0].accessibilityValue, "已隐藏")
        chart.performTap(at: CGPoint(x: oldLegend.midX, y: oldLegend.midY))
        XCTAssertEqual(hits, 1, "legend region must not snap to chart data")
        r.legendView.buttons[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(chart.isSeriesVisible("solar"), true)
    }

    func testVisibilitySurvivesReorderingAndCanBeResetOrDrivenByModel() {
        let chart = chart(ColumnChartRenderer.self)
        chart.setSeriesVisible(false, for: "battery")
        var reordered = model()
        reordered.series.reverse()
        chart.update(model: reordered)
        chart.layoutIfNeeded()
        XCTAssertEqual(chart.isSeriesVisible("battery"), false)
        XCTAssertEqual(chart.rendererForTesting.legendItems.map(\.id), ["grid", "battery", "solar"])
        XCTAssertEqual(chart.rendererForTesting.legendItems[1].color, .systemOrange)
        reordered.series[1].isVisible = false
        chart.update(model: reordered)
        reordered.series[1].isVisible = true
        chart.update(model: reordered)
        XCTAssertEqual(chart.isSeriesVisible("battery"), true, "explicit model change wins")
        chart.setSeriesVisible(false, for: "solar")
        chart.resetSeriesVisibility()
        XCTAssertEqual(chart.isSeriesVisible("solar"), true)
        chart.setSeriesVisible(false, for: "solar")
        chart.configure(model: model(), theme: CartesianChartTheme())
        XCTAssertEqual(chart.isSeriesVisible("solar"), true)
    }

    func testRemovedIDDoesNotRetainOldVisibility() {
        let chart = chart(LineChartRenderer.self)
        chart.setSeriesVisible(false, for: "solar")
        var reduced = model()
        reduced.series.removeFirst()
        chart.update(model: reduced)
        chart.update(model: model())
        XCTAssertEqual(chart.isSeriesVisible("solar"), true)
        XCTAssertNil(chart.isSeriesVisible("missing"))
        chart.setSeriesVisible(false, for: "missing")
    }

    func testHiddenSeriesAreExcludedFromBoundsStacksAndPercentDenominator() {
        var data = model(.percent)
        data.series[1].isVisible = false
        XCTAssertEqual(data.rawBaseValues(forSeries: 0)[0], 20.0 / 30.0 * 100, accuracy: 0.001)
        XCTAssertEqual(data.stackedDrawValues[2][0], 100, accuracy: 0.001)
        data.stacking = .normal
        XCTAssertEqual(data.stackedDrawValues[2][0], 30)
        XCTAssertEqual(data.dataBounds()?.max, 60)
        data.stacking = .percentFixed(max: 100)
        XCTAssertEqual(data.stackedDrawValues[2][0], 30)
        data.stacking = nil
        XCTAssertEqual(data.dataBounds()?.max, 40)
        XCTAssertEqual(data.maxPointCount, 3)
    }

    func testHideAllKeepsLegendAndCategoriesButRemovesAllHits() {
        let chart = chart(LineChartRenderer.self)
        let r = chart.rendererForTesting
        for id in ["solar", "battery", "grid"] { chart.setSeriesVisible(false, for: id) }
        let center = CGPoint(x: r.currentPlotFrame.midX, y: r.currentPlotFrame.midY)
        XCTAssertNil(r.hitTest(center))
        XCTAssertNil(r.snapHit(at: center))
        XCTAssertNil(r.sharedHit(at: center))
        XCTAssertEqual(r.currentModel?.maxPointCount, 3)
        XCTAssertNil(r.currentModel?.dataBounds())
        XCTAssertEqual(r.legendView.buttons.count, 3)
        XCTAssertTrue(r.seriesLayerSublayersForTesting().isEmpty)
        r.legendView.buttons[0].sendActions(for: .touchUpInside)
        XCTAssertNotNil(r.snapHit(at: center))
    }

    func testGroupedMarksRecenterAndRetainOriginalSeriesIndex() throws {
        let chart = chart(ColumnChartRenderer.self)
        let r = chart.rendererForTesting
        chart.setSeriesVisible(false, for: "solar")
        chart.setSeriesVisible(false, for: "grid")
        let target = try XCTUnwrap(r.makeHitTarget(seriesIndex: 1, categoryIndex: 1, value: 50))
        let frame = try XCTUnwrap(r.hitFrame(for: target))
        let categoryX = r.screenPoint(x: 1, y: 0).x
        XCTAssertEqual(frame.midX, categoryX, accuracy: 0.01)
        let hit = try XCTUnwrap(r.hitTest(CGPoint(x: frame.midX, y: frame.midY)) as? ColumnHitTarget)
        XCTAssertEqual(hit.seriesIndex, 1)
        XCTAssertEqual(hit.seriesID, "battery")
        let shared = try XCTUnwrap(r.sharedHit(at: CGPoint(x: frame.midX, y: frame.midY))?.target as? CartesianSharedHitTarget)
        XCTAssertEqual(shared.entries.map(\.seriesID), ["battery"])
    }

    func testColumnAndBarStackSegmentsHitAfterVisibilityChange() throws {
        for stack: StackConfig in [.normal, .percent, .percentFixed(max: 200)] {
            let column = chart(ColumnChartRenderer.self, model: model(stack))
            column.setSeriesVisible(false, for: "solar")
            let cr = column.rendererForTesting
            let ct = try XCTUnwrap(cr.makeHitTarget(seriesIndex: 2, categoryIndex: 1, value: 0))
            let cf = try XCTUnwrap(cr.hitFrame(for: ct))
            let ch = try XCTUnwrap(cr.hitTest(CGPoint(x: cf.midX, y: cf.midY)) as? ColumnHitTarget)
            XCTAssertEqual(ch.seriesID, "grid")
            let bar = chart(BarChartRenderer.self, model: model(stack))
            bar.setSeriesVisible(false, for: "solar")
            let br = bar.rendererForTesting
            let bt = try XCTUnwrap(br.makeHitTarget(seriesIndex: 2, categoryIndex: 1, value: 0))
            let bf = try XCTUnwrap(br.hitFrame(for: bt))
            let bh = try XCTUnwrap(br.hitTest(CGPoint(x: bf.midX, y: bf.midY)) as? BarHitTarget)
            XCTAssertEqual(bh.seriesID, "grid")
        }
    }

    func testHiddenRightAxisSeriesAndMissingValues() throws {
        var data = model(.percent)
        data.series[1].yAxisIndex = 1
        data.series[1].data = [500, 800]
        data.series[0].data = [.nan, 20, -40]
        data.secondaryYAxis = .init(kind: .value)
        let chart = chart(ColumnChartRenderer.self, model: data)
        chart.setSeriesVisible(false, for: "battery")
        let r = chart.rendererForTesting
        XCTAssertNil(r.currentModel?.dataBounds(yAxisIndex: 1))
        XCTAssertEqual(r.currentModel!.rawBaseValues(forSeries: 2)[0], 100)
        XCTAssertEqual(r.currentModel!.rawBaseValues(forSeries: 0)[2], -40.0 / 60.0 * 100, accuracy: 0.001)
        let target = try XCTUnwrap(r.makeHitTarget(seriesIndex: 2, categoryIndex: 0, value: 100))
        let frame = try XCTUnwrap(r.hitFrame(for: target))
        XCTAssertEqual((r.hitTest(CGPoint(x: frame.midX, y: frame.midY)) as? ColumnHitTarget)?.seriesID, "grid")
    }

    func testTogglePreservesCategoryViewport() {
        let chart = chart(LineChartRenderer.self)
        let r = chart.rendererForTesting
        r.zoomXAxis(factor: 2, anchorScreenX: r.currentPlotFrame.midX)
        let range = r.xAxisViewport
        chart.setSeriesVisible(false, for: "battery")
        XCTAssertEqual(r.xAxisViewport, range)
    }

    private func findChart<R: HYMChartRenderer>(in view: UIView, type: R.Type) -> HYMChartView<R>? {
        if let result = view as? HYMChartView<R> { return result }
        return view.subviews.lazy.compactMap { self.findChart(in: $0, type: type) }.first
    }

    func testSwiftUIVisibilityCallbackRefreshAndLocalStatePreservation() throws {
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = true
        var received: [Int] = []
        let data = model()
        func root(_ generation: Int, enabled: Bool) -> some View {
            LineChart(model: data, theme: theme, playsAnimationOnAppear: false,
                      onSeriesVisibilityChanged: enabled ? { _, _ in received.append(generation) } : nil)
                .frame(height: 340)
        }
        let host = UIHostingController(rootView: root(1, enabled: true))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let view = try XCTUnwrap(findChart(in: host.view, type: LineChartRenderer.self))
        view.rendererForTesting.legendView.buttons[0].sendActions(for: .touchUpInside)
        host.rootView = root(2, enabled: true)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(view.isSeriesVisible("solar"), false)
        view.rendererForTesting.legendView.buttons[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(received, [1, 2])
        host.rootView = root(3, enabled: false)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertNil(view.onSeriesVisibilityChanged)
    }

    func testPublicMeasurementMatchesRenderedLegendAndPreservesBasePlotHeight() {
        for position in [ChartLegendPosition.top, .bottom] {
            var data = model()
            data.series += (0..<8).map { .init(name: "Extra series \($0)", data: [1, 2, 3], id: "extra-\($0)") }
            var theme = CartesianChartTheme()
            let view = HYMChartView<ColumnChartRenderer>(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
            view.configure(model: data, theme: theme)
            view.layoutIfNeeded()
            let originalPlotHeight = view.rendererForTesting.currentPlotFrame.height
            theme.legend.isEnabled = true
            theme.legend.position = position
            theme.legend.overflow = .expand
            theme.legend.maxRows = 1
            theme.legend.maxHeight = 32
            let measurement = ChartLegendMeasurer.measure(model: data, theme: theme,
                                                           availableWidth: 300 - theme.contentInset.left - theme.contentInset.right)
            XCTAssertGreaterThan(measurement.rowCount, 1)
            XCTAssertGreaterThan(measurement.size.height, 32)
            XCTAssertFalse(measurement.isScrollable)
            view.frame.size.height += measurement.additionalChartHeight
            view.update(theme: theme)
            view.layoutIfNeeded()
            XCTAssertEqual(view.rendererForTesting.legendView.frame.size, measurement.size)
            XCTAssertEqual(view.rendererForTesting.currentPlotFrame.height, originalPlotHeight, accuracy: 0.001)
        }
    }

    func testMeasurementReportsFullContentSeparatelyFromScrollViewport() {
        var data = model()
        data.series += (0..<8).map { .init(name: "Extra series \($0)", data: [1], id: "extra-\($0)") }
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = true
        theme.legend.maxRows = 1
        let measured = ChartLegendMeasurer.measure(model: data, theme: theme, availableWidth: 160)
        XCTAssertEqual(measured.size, CGSize(width: 160, height: 32))
        XCTAssertGreaterThan(measured.contentSize.height, measured.size.height)
        XCTAssertTrue(measured.isScrollable)
        XCTAssertEqual(measured.additionalChartHeight, 32 + theme.legend.chartSpacing)
        XCTAssertEqual(measured.additionalChartWidth, 0)
        let wide = ChartLegendMeasurer.measure(model: data, theme: theme, availableWidth: 500)
        XCTAssertLessThan(wide.rowCount, measured.rowCount)
    }

    func testMeasurementUsesTitleOverridesFontAndLegendMembership() {
        var data = model()
        data.series[0].isVisible = false // hidden series remain in legend
        data.series[1].showsInLegend = false
        data.series[2].showsInLegend = false
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = true
        let original = ChartLegendMeasurer.measure(model: data, theme: theme, availableWidth: 300)
        theme.legend.itemOverrides["solar"] = .init(title: "A much longer legend label")
        let renamed = ChartLegendMeasurer.measure(model: data, theme: theme, availableWidth: 300)
        XCTAssertGreaterThan(renamed.contentSize.width, original.contentSize.width)
        theme.legend.font = .systemFont(ofSize: 40)
        let large = ChartLegendMeasurer.measure(model: data, theme: theme, availableWidth: 300)
        XCTAssertGreaterThan(large.contentSize.height, renamed.contentSize.height)
        XCTAssertEqual(large.rowCount, 1)
        XCTAssertLessThanOrEqual(large.contentSize.width, 300)
    }

    func testMeasurementEmptyDisabledAndInvalidWidthHaveNoSpacing() {
        var theme = CartesianChartTheme()
        XCTAssertEqual(ChartLegendMeasurer.measure(model: model(), theme: theme, availableWidth: 300).size, .zero)
        theme.legend.isEnabled = true
        for width: CGFloat in [0, -1, .nan, .infinity] {
            let result = ChartLegendMeasurer.measure(model: model(), theme: theme, availableWidth: width)
            XCTAssertEqual(result.additionalChartHeight, 0)
            XCTAssertEqual(result.contentSize, .zero)
        }
        var empty = model()
        empty.series = []
        XCTAssertEqual(ChartLegendMeasurer.measure(model: empty, theme: theme, availableWidth: 300).rowCount, 0)
    }

    func testSideMeasurementReservesWidthInsteadOfAddingHeights() {
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = true
        theme.legend.position = .right
        theme.legend.overflow = .expand
        let result = ChartLegendMeasurer.measure(model: model(), theme: theme, availableWidth: 120)
        XCTAssertEqual(result.additionalChartHeight, 0)
        XCTAssertEqual(result.additionalChartWidth, result.size.width + theme.legend.chartSpacing)
        XCTAssertEqual(result.rowCount, 3)
        let view = chart(ColumnChartRenderer.self, position: .right)
        XCTAssertEqual(view.rendererForTesting.legendView.frame.size, result.size)
    }

    func testExpandStillProtectsPlotWhenCallerDoesNotProvideEnoughHeight() {
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = true
        theme.legend.overflow = .expand
        let data = CartesianChartModel(series: (0..<30).map {
            .init(name: "Long item \($0)", data: [1, 2], id: "\($0)")
        })
        let result = ChartLegendMeasurer.measure(model: data, theme: theme, availableWidth: 200)
        let view = HYMChartView<ColumnChartRenderer>(frame: CGRect(x: 0, y: 0, width: 224, height: 300))
        view.configure(model: data, theme: theme)
        view.layoutIfNeeded()
        XCTAssertGreaterThan(result.size.height, view.rendererForTesting.legendView.frame.height)
        XCTAssertGreaterThanOrEqual(view.rendererForTesting.currentPlotFrame.height, theme.legend.minimumPlotSize.height)
    }

    func testRenderSnapshots() {
        for position in ChartLegendPosition.allCases {
            let view = chart(ColumnChartRenderer.self, model: model(.normal), position: position)
            view.backgroundColor = .systemBackground
            view.layoutIfNeeded()
            view.rendererForTesting.legendView.layoutIfNeeded()
            view.rendererForTesting.legendView.buttons.forEach { $0.layoutIfNeeded() }
            let image = UIGraphicsImageRenderer(bounds: view.bounds).image { context in
                view.layer.render(in: context.cgContext)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "legend-\(position.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
