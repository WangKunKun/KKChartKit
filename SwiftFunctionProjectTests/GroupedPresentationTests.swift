import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class GroupedPresentationTests: XCTestCase {
    private func state(_ kind: CartesianDemoKind = .line) -> CartesianDemoState {
        var state = CartesianDemoState(kind: kind)
        state.groupedPresentationPreset()
        return state
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
            state: CartesianDemoState) -> HYMChartView<R> {
        let chart = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 390, height: 420))
        chart.showsTooltipOnHit = true; chart.isSharedTooltipOnTapEnabled = true
        chart.tooltipTextOptions = state.interaction.textOptions
        chart.configure(model: state.model, theme: state.builtTheme)
        chart.layoutIfNeeded()
        return chart
    }
    private func rows(_ state: CartesianDemoState) -> [CartesianDatum] {
        let view = chart(LineChartRenderer.self, state: state)
        return state.model.series.indices.compactMap { view.rendererForTesting.datum(series: $0, category: 0) }
    }
    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    func testGroupedTextKeepsStableOrderAndSumsRawSignedValues() throws {
        var s = state(); s.stacking = "普通"
        let data = rows(s)
        let text = try XCTUnwrap(CartesianDatumText.text(data, options: s.interaction.textOptions, header: "08:00"))
        XCTAssertEqual(text, "08:00\n能源\n  光伏: 100 W\n  电池: -40 W\n  小计: 60 W\n环境\n  温度: 25 °C\n未分组\n  备用: 0 W")
        var reordered = data; reordered.swapAt(1, 2)
        XCTAssertEqual(CartesianDatumText.text(reordered, options: s.interaction.textOptions, header: "08:00"), text)
        XCTAssertEqual(data[1].rawValue, -40)
    }

    func testFiltersAffectOnlyTextAndEmptyContentHasNoHeader() throws {
        let s = state(); let data = rows(s)
        var options = s.interaction.textOptions
        options.cartesian.hidesZeroValues = true
        options.cartesian.excludedSeriesIDs = ["series-1"]
        let text = try XCTUnwrap(CartesianDatumText.text(data, options: options))
        XCTAssertFalse(text.contains("电池")); XCTAssertFalse(text.contains("备用"))
        XCTAssertFalse(text.contains("小计")); XCTAssertEqual(data.count, 4)
        options.cartesian.excludedSeriesIDs = Set(data.map(\.seriesID))
        XCTAssertNil(CartesianDatumText.text(data, options: options, header: "08:00"))
    }

    func testSubtotalRejectsDifferentUnitsAxesFormatsAndAggregates() throws {
        for variant in 0..<4 {
            var s = state(); s.seriesCount = 2
            switch variant {
            case 0: s.series[1].unit = "Wh"
            case 1: s.dualAxis = true; s.series[1].axis = 1
            case 2: s.series[1].valueFormat = .init()
            default: s.series[1].dataText = "nan,nan,nan"
            }
            XCTAssertFalse(try XCTUnwrap(CartesianDatumText.text(rows(s), options: s.interaction.textOptions)).contains("小计"))
        }
        var s = state(.column); s.seriesCount = 2; s.pointCount = 300
        s.timeEnabled = true; s.grouping = true; s.groupingConfig.minimumColumnWidth = 20
        for i in 0..<2 { s.series[i].dataText = ""; s.series[i].aggregation = "平均" }
        let view = chart(ColumnChartRenderer.self, state: s)
        let data = (0..<2).compactMap { view.rendererForTesting.datum(series: $0, category: 0) }
        XCTAssertEqual(data.count, 2); XCTAssertTrue(data.allSatisfy { $0.aggregatedValue != nil })
        let text = try XCTUnwrap(CartesianDatumText.text(data, options: s.interaction.textOptions))
        XCTAssertFalse(text.contains("小计")); XCTAssertTrue(text.contains("有效"))
    }

    func testSubtotalUsesSignedSumBeforeAbsoluteFormattingAndRejectsOverflow() throws {
        var s = state(); s.seriesCount = 2
        for i in 0..<2 {
            s.series[i].valueFormat = .init()
            s.series[i].valueFormat?.showsAbsoluteValue = true
            s.series[i].valueFormat?.localeIdentifier = "en_US"
            s.series[i].dataText = i == 0 ? "-100,-100,-100" : "40,40,40"
        }
        let text = try XCTUnwrap(CartesianDatumText.text(rows(s), options: s.interaction.textOptions))
        XCTAssertTrue(text.contains("光伏: 100 W")); XCTAssertTrue(text.contains("小计: -60 W"))
        for value in [Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, Double(Int.max)] {
            XCTAssertFalse(AxisRenderer.format(value).isEmpty)
            XCTAssertFalse(CartesianDataLabelGeometry.labelText(value).isEmpty)
        }
        let original = rows(s)
        let extreme = original.map { row in
            CartesianDatum(seriesID: row.seriesID, seriesIndex: row.seriesIndex, categoryIndex: 0,
                name: row.name, stackID: nil, groupID: row.groupID, groupName: row.groupName,
                unit: row.unit, yAxisIndex: 0, rawValue: Double.greatestFiniteMagnitude,
                aggregatedValue: nil, drawValue: 0, stackBase: 0, percentage: nil,
                sourceRange: 0..<1, timeBucket: nil, valueFormat: nil)
        }
        XCTAssertFalse(try XCTUnwrap(CartesianDatumText.text(extreme, options: s.interaction.textOptions)).contains("小计"))
    }

    func testDefaultFlatTextAndUnknownGroupFallback() throws {
        var s = state(); s.series[0].groupName = ""
        let data = rows(s)
        XCTAssertTrue(try XCTUnwrap(CartesianDatumText.text(data, options: s.interaction.textOptions)).hasPrefix("energy\n"))
        let text = try XCTUnwrap(CartesianDatumText.text(data))
        XCTAssertTrue(text.hasPrefix("光伏: 100 W")); XCTAssertFalse(text.contains("小计"))
        XCTAssertFalse(text.contains("未分组"))
    }

    func testSharedTapUsesGroupingAcrossAllCartesianRenderersAndPreservesCallbacks() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ kind: CartesianDemoKind) throws {
            let s = state(kind); let view = chart(type, state: s)
            let plot = view.rendererForTesting.currentPlotFrame
            let point = CGPoint(x: plot.midX, y: plot.midY)
            var hit: (any HYMChartHitTarget)?
            view.onHit = { target, _ in hit = target }
            view.performTap(at: point)
            let target = try XCTUnwrap(hit)
            XCTAssertEqual((target as? CartesianHitDataSource)?.chartData.count, 4)
            XCTAssertTrue(try XCTUnwrap(view.formattedTooltipText(for: target)).contains("小计"))
            view.tooltipTextOptions.cartesian.excludedSeriesIDs = ["series-0"]
            view.performTap(at: point)
            XCTAssertEqual((hit as? CartesianHitDataSource)?.chartData.count, 4)
            view.setSeriesVisible(false, for: "series-1"); view.layoutIfNeeded()
            view.performTap(at: point)
            XCTAssertEqual((hit as? CartesianHitDataSource)?.chartData.count, 3)
        }
        try verify(LineChartRenderer.self, .line); try verify(ColumnChartRenderer.self, .column)
        try verify(BarChartRenderer.self, .bar); try verify(CombinedChartRenderer.self, .combined)
    }

    func testGroupedLegendMeasurementMatchesRendererAtAllPositions() {
        for position in ChartLegendPosition.allCases {
            var s = state(); s.theme.legend.position = position; s.expandLegend = true
            let view = chart(LineChartRenderer.self, state: s)
            let r = view.rendererForTesting
            if position == .bottom || position == .top {
                let measured = ChartLegendMeasurer.measure(model: s.model, theme: s.builtTheme,
                    availableWidth: view.bounds.width - s.theme.contentInset.left - s.theme.contentInset.right)
                XCTAssertEqual(r.legendView.frame.size, measured.size)
                XCTAssertEqual(measured.rowCount, 3)
            }
            XCTAssertGreaterThan(r.legendView.buttons[2].frame.minY, r.legendView.buttons[1].frame.minY)
            XCTAssertFalse(r.legendView.frame.intersects(r.currentPlotFrame))
            XCTAssertEqual(r.legendItems.map(\.id), ["series-0", "series-1", "series-2", "series-3"])
        }
    }

    func testImageVisibilityCustomSymbolReuseAndFallbackCleanUp() throws {
        let s = state(); let view = chart(LineChartRenderer.self, state: s)
        let r = view.rendererForTesting; let button = r.legendView.buttons[0]
        button.layoutIfNeeded()
        var imageView = try XCTUnwrap(descendants(button).compactMap { $0 as? UIImageView }.first)
        XCTAssertNotNil(imageView.image); XCTAssertFalse(imageView.isHidden)
        let originalImage = imageView.image
        view.setSeriesVisible(false, for: "series-0"); view.layoutIfNeeded(); button.layoutIfNeeded()
        XCTAssertFalse(imageView.image === originalImage)
        XCTAssertEqual(button.accessibilityValue, "已隐藏")
        let custom = UILabel(); custom.text = "CUSTOM"
        var states: [Bool] = []
        var theme = s.builtTheme
        theme.legend.itemOverrides["series-0"]?.symbolViewProvider = { visible in states.append(visible); return custom }
        view.update(theme: theme); view.layoutIfNeeded(); button.layoutIfNeeded()
        XCTAssertTrue(descendants(button).contains { $0 === custom }); XCTAssertEqual(states.last, false)
        XCTAssertEqual(custom.frame.size, theme.legend.symbolSize)
        XCTAssertFalse(try XCTUnwrap(custom.superview).isUserInteractionEnabled)
        view.setSeriesVisible(true, for: "series-0"); view.layoutIfNeeded()
        XCTAssertEqual(states.last, true)
        theme.legend.itemOverrides["series-0"]?.symbolViewProvider = { _ in nil }
        view.update(theme: theme); view.layoutIfNeeded(); button.layoutIfNeeded()
        XCTAssertNil(custom.superview); XCTAssertFalse(imageView.isHidden)
        theme.legend.itemOverrides = [:]
        view.update(theme: theme); view.layoutIfNeeded(); button.layoutIfNeeded()
        imageView = try XCTUnwrap(descendants(button).compactMap { $0 as? UIImageView }.first)
        XCTAssertNil(imageView.image); XCTAssertTrue(imageView.isHidden); XCTAssertNil(button.backgroundColor)
        XCTAssertTrue(button.layer.sublayers!.compactMap { $0 as? CAShapeLayer }.contains { $0.path != nil })
    }

    func testOCBridgeConfiguresGroupingAndLegendOverrides() throws {
        let model = HYMCartesianModel(); let group = HYMCartesianGroup()
        group.identifier = "g"; group.name = "能源"; model.groups = [group]
        model.series = (0..<2).map { i in
            let row = HYMCartesianSeries(); row.identifier = "s\(i)"; row.name = "S\(i)"
            row.groupID = "g"; row.unit = "W"; row.data = [NSNumber(value: i == 0 ? 100 : -40)]
            return row
        }
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: .init(x: 0, y: 0, width: 390, height: 400))
        bridge.tooltipOptions.groupsByBusinessID = true; bridge.tooltipOptions.showsGroupSubtotals = true
        bridge.legendStartsNewRowPerGroup = true
        let style = HYMCartesianLegendItemStyle(); style.image = UIImage(systemName: "sun.max.fill")
        bridge.legendItemStyles = ["s0": style]
        try bridge.configure(model: model); bridge.chartView.layoutIfNeeded()
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        let plot = view.rendererForTesting.currentPlotFrame
        let target = try XCTUnwrap(view.rendererForTesting.sharedHit(at: .init(x: plot.midX, y: plot.midY))?.target)
        XCTAssertTrue(try XCTUnwrap(view.formattedTooltipText(for: target)).contains("小计: 60 W"))
        XCTAssertNotNil(view.rendererForTesting.legendItems[0].style.image)
        bridge.tooltipOptions.groupsByBusinessID = false; bridge.legendItemStyles = [:]
        try bridge.update(model: model, preserveViewport: true); bridge.chartView.layoutIfNeeded()
        XCTAssertFalse(try XCTUnwrap(view.formattedTooltipText(for: target)).contains("小计"))
        XCTAssertNil(view.rendererForTesting.legendItems[0].style.image)
    }

    func testDemoDependenciesKeepValuesAndRestoreDefaults() throws {
        var s = state()
        func item(_ label: String) throws -> ChartDemoPanel.Item {
            let binding = Binding(get: { s }, set: { s = $0 })
            return try XCTUnwrap(CartesianDemoControls.sections(binding).flatMap(\.items).first { $0.label == label })
        }
        s.interaction.tooltipGrouping.groupsByBusinessID = false
        XCTAssertFalse(try item("显示组小计").isEnabled)
        XCTAssertTrue(s.interaction.tooltipGrouping.showsGroupSubtotals)
        s.interaction.tooltipGrouping.groupsByBusinessID = true
        XCTAssertTrue(try item("显示组小计").isEnabled)
        s.interaction.popupMode = "自定义内容"
        XCTAssertFalse(try item("按业务组显示提示").isEnabled)
        s.series[0].legendContent = "默认"
        XCTAssertFalse(try item("图例图片 SF Symbol").isEnabled)
        s.theme.legend.isEnabled = false
        XCTAssertFalse(try item("图例内容预设").isEnabled)
        XCTAssertFalse(try item("图例项圆角").isEnabled)
        s.reset()
        XCTAssertFalse(s.interaction.tooltipGrouping.groupsByBusinessID)
        XCTAssertFalse(s.theme.legend.startsNewRowPerGroup)
        XCTAssertNil(s.theme.lineSampling)
    }
}
