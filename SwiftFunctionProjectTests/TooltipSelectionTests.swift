import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class TooltipSelectionTests: XCTestCase {
    private func state(_ kind: CartesianDemoKind = .line) -> CartesianDemoState {
        var s = CartesianDemoState(kind: kind); s.tooltipSelectionPreset(); return s
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ s: CartesianDemoState) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: .init(x: 0, y: 0, width: 390, height: 420))
        view.showsTooltipOnHit = true; view.isSharedTooltipOnTapEnabled = true
        view.tooltipTextOptions = s.interaction.textOptions
        view.cartesianTooltipPresentation = s.interaction.presentation
        view.cartesianTooltipSampleSelection = s.interaction.sampleSelection
        view.tooltipTheme = s.tooltipTheme; view.tooltipTheme.showsAnimation = false
        view.configure(model: s.model, theme: s.builtTheme); view.layoutIfNeeded()
        return view
    }
    private func data<R: CartesianRendererBase<CartesianChartTheme>>(_ view: HYMChartView<R>, category: Int) -> [CartesianDatum] {
        (0..<4).compactMap { view.rendererForTesting.datum(series: $0, category: category) }
    }
    private func target(_ data: [CartesianDatum], key: String = "08:05") -> CartesianSharedHitTarget {
        .init(categoryIndex: data.first?.categoryIndex ?? 0, entries: data.map {
            .init(seriesID: $0.seriesID, seriesIndex: $0.seriesIndex, name: $0.name, value: $0.displayValue,
                  isSecondaryAxis: $0.yAxisIndex == 1, datum: $0, timeBucket: $0.timeBucket)
        }, crosshairX: 100, headerKey: key)
    }
    private func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }

    func testPreviousValuesKeepCurrentHeaderHitProviderAndAlignedSubtotal() throws {
        let view = chart(LineChartRenderer.self, state())
        var providerIndices: [Int] = []
        view.cartesianTooltipPresentation.rowStyleProvider = { providerIndices.append($0.sourceRange.lowerBound); return nil }
        let original = data(view, category: 1)
        let content = try XCTUnwrap(view.cartesianTooltipContent(for: target(original)))
        XCTAssertEqual(content.header, "08:05")
        XCTAssertEqual(content.sections[0].rows.map(\.value), ["100 W", "-40 W", "60 W"])
        XCTAssertEqual(content.sections[1].rows[0].value, "28 °C")
        XCTAssertEqual(providerIndices, [1, 1, 1, 1])
        let row = content.sections[0].rows[0]
        XCTAssertEqual(row.datum?.rawValue, 120); XCTAssertEqual(row.datum?.sourceRange, 1..<2)
        XCTAssertEqual(row.displayedDatum?.rawValue, 100); XCTAssertEqual(row.displayedDatum?.sourceRange, 0..<1)
        XCTAssertEqual(row.sourceLabel, "取值 08:00"); XCTAssertTrue(row.title.contains("取值 08:00"))
        XCTAssertEqual(original[0].rawValue, 120)
        view.cartesianTooltipSampleSelection.offsetsBySeriesID["series-1"] = 0
        XCTAssertFalse(try XCTUnwrap(view.cartesianTooltipContent(for: target(original))).text.contains("小计"), "不同来源索引不合计")
    }

    func testBoundaryPoliciesAndExtremeOffsetsDoNotOverflow() {
        var selection = CartesianTooltipSampleSelection(); selection.offset = -1
        XCTAssertNil(selection.index(for: 0, count: 3, seriesID: "s"))
        selection.boundaryPolicy = .clamp
        XCTAssertEqual(selection.index(for: 0, count: 3, seriesID: "s"), 0)
        selection.boundaryPolicy = .current; selection.offset = Int.max
        XCTAssertEqual(selection.index(for: 2, count: 3, seriesID: "s"), 2)
        selection.boundaryPolicy = .clamp
        XCTAssertEqual(selection.index(for: 2, count: 3, seriesID: "s"), 2)
        selection.offset = Int.min
        XCTAssertEqual(selection.index(for: 1, count: 3, seriesID: "s"), 0)
        selection.boundaryPolicy = .omit
        XCTAssertNil(selection.index(for: 1, count: 3, seriesID: "s"))
        selection.offsetsBySeriesID["s"] = 0
        XCTAssertEqual(selection.index(for: 1, count: 3, seriesID: "s"), 1)
        XCTAssertNil(selection.index(for: 0, count: 0, seriesID: "s"))
    }

    func testExactMissingSourceIsOmittedWithoutSearchingEarlierSample() throws {
        var s = state(); s.series[0].dataText = "100,nan,140"; s.series[1].dataText = "-40,20"
        let view = chart(ColumnChartRenderer.self, s)
        let samples = view.rendererForTesting.tooltipSamples(for: data(view, category: 2), selection: s.interaction.sampleSelection)
        XCTAssertFalse(samples.contains { $0.hitDatum.seriesID == "series-0" })
        XCTAssertFalse(samples.contains { $0.hitDatum.seriesID == "series-1" }, "不能为当前缺失的行制造前值")
        view.cartesianTooltipSampleSelection.offset = 2
        view.cartesianTooltipSampleSelection.boundaryPolicy = .clamp
        let rows = try XCTUnwrap(view.cartesianTooltipContent(for: target(data(view, category: 0)))).sections.flatMap(\.rows)
        XCTAssertEqual(rows.first { $0.datum?.seriesID == "series-1" }?.displayedDatum?.sourceRange, 1..<2, "短系列按自身末端约束")
    }

    func testZeroFilterUsesDisplayedValueAndSourceLabelsCanBeLocalizedOrHidden() throws {
        var s = state(); s.series[1].dataText = "0,20,30"
        let view = chart(LineChartRenderer.self, s)
        view.tooltipTextOptions.cartesian.hidesZeroValues = true
        view.cartesianTooltipSampleSelection.sourceLabelTemplate = "Value at {key}"
        let content = try XCTUnwrap(view.cartesianTooltipContent(for: target(data(view, category: 1))))
        XCTAssertFalse(content.text.contains("电池")); XCTAssertTrue(content.text.contains("Value at 08:00"))
        view.cartesianTooltipSampleSelection.sourceLabelTemplate = ""
        XCTAssertFalse(try XCTUnwrap(view.cartesianTooltipContent(for: target(data(view, category: 1)))).text.contains(" · "))
        view.cartesianTooltipSampleSelection.showsSourceLabel = false
        XCTAssertFalse(try XCTUnwrap(view.cartesianTooltipContent(for: target(data(view, category: 1)))).text.contains("08:00"))
        view.cartesianTooltipPresentation.rowStyleProvider = { _ in .init(hidesValue: true) }
        let names = try XCTUnwrap(view.cartesianTooltipContent(for: target(data(view, category: 1))))
        XCTAssertFalse(names.text.contains("小计")); XCTAssertTrue(names.sections.flatMap(\.rows).allSatisfy { $0.value == nil })
    }

    func testSourceOutsideVisibleWindowRemainsAvailableAndHiddenSeriesStayExcluded() throws {
        var s = state(); s.pointCount = 10
        for i in 0..<4 { s.series[i].dataText = (0..<10).map { String($0 + i * 100) }.joined(separator: ",") }
        s.series[3].visible = false
        let view = chart(LineChartRenderer.self, s); view.showCategoryRange(5..<8); view.layoutIfNeeded()
        let viewport = view.xAxisViewportForTesting
        let original = data(view, category: 5)
        XCTAssertEqual(original.count, 3)
        let samples = view.rendererForTesting.tooltipSamples(for: original, selection: s.interaction.sampleSelection)
        XCTAssertEqual(samples.first?.displayedDatum.sourceRange, 4..<5)
        XCTAssertEqual(samples.first?.displayedDatum.rawValue, 4)
        XCTAssertEqual(view.xAxisViewportForTesting, viewport)
    }

    func testActualTimeAggregationIncludingSinglePointTailKeepsBucketStatistics() throws {
        var s = state(.column); s.pointCount = 301; s.timeEnabled = true; s.grouping = true
        s.daily = false; s.interval = 1; s.intervalText = "300"
        s.groupingConfig.minimumColumnWidth = 4
        for i in 0..<4 { s.series[i].dataText = ""; s.series[i].aggregation = "平均" }
        let view = chart(ColumnChartRenderer.self, s)
        let prepared = try XCTUnwrap(view.rendererForTesting.currentModel)
        XCTAssertEqual(prepared.timeBucketStride, 300)
        for category in [0, prepared.maxPointCount - 1] {
            let original = data(view, category: category)
            XCTAssertEqual(original.count, 4)
            if category != 0 { XCTAssertTrue(original.allSatisfy { $0.sourceRange.count == 1 }) }
            let samples = view.rendererForTesting.tooltipSamples(for: original, selection: s.interaction.sampleSelection)
            XCTAssertEqual(samples.count, original.count)
            for sample in samples {
                XCTAssertEqual(sample.hitDatum.sourceRange, sample.displayedDatum.sourceRange)
                XCTAssertEqual(sample.hitDatum.displayValue, sample.displayedDatum.displayValue)
                XCTAssertNil(sample.sourceLabel)
            }
            XCTAssertFalse(try XCTUnwrap(view.cartesianTooltipContent(for: target(original))).text.contains("取值"))
        }
    }

    func testSingleSharedAndClearSelectionAcrossAllFourRenderers() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ kind: CartesianDemoKind) throws {
            let view = chart(type, state(kind)); let plot = view.rendererForTesting.currentPlotFrame
            var selection = state(kind).interaction.sampleSelection; selection.offsetsBySeriesID = [:]
            view.cartesianTooltipSampleSelection = selection
            var received: [CartesianDatum] = []
            view.onHit = { target, _ in received = (target as? CartesianHitDataSource)?.chartData ?? [] }
            for shared in [true, false] {
                view.isSharedTooltipOnTapEnabled = shared
                view.performTap(at: .init(x: plot.midX, y: plot.midY))
                let tooltip = try XCTUnwrap(view.subviews.compactMap { $0 as? HYMChartTooltip }.first)
                XCTAssertFalse(tooltip.isHidden); XCTAssertEqual(tooltip.frame.minY, 8, accuracy: 0.1)
                XCTAssertEqual(received.count, shared ? 4 : 1)
                XCTAssertTrue(received.allSatisfy { $0.sourceRange == 1..<2 })
                XCTAssertTrue(descendants(tooltip).contains { $0.accessibilityLabel?.contains("取值 08:00") == true })
                view.cartesianTooltipSampleSelection = .init()
                view.performTap(at: .init(x: plot.midX, y: plot.midY))
                XCTAssertFalse(descendants(tooltip).contains { $0.accessibilityLabel?.contains("取值") == true })
                view.cartesianTooltipSampleSelection = selection
            }
            view.frame.size = .init(width: 230, height: 170); view.layoutIfNeeded()
            let tooltip = try XCTUnwrap(view.subviews.compactMap { $0 as? HYMChartTooltip }.first)
            XCTAssertTrue(view.bounds.contains(tooltip.frame))
            view.update(model: state(kind).model, theme: state(kind).builtTheme)
            XCTAssertTrue(tooltip.isHidden, "数据更新清理旧提示")
        }
        try verify(LineChartRenderer.self, .line); try verify(ColumnChartRenderer.self, .column)
        try verify(BarChartRenderer.self, .bar); try verify(CombinedChartRenderer.self, .combined)
    }

    func testPinnedGeometryIgnoresAnchorClampsOffsetsAndRejectsInvalidContainers() throws {
        let container = CGRect(x: 10, y: 20, width: 300, height: 200)
        func resolve(_ anchor: CGRect, _ offset: CGPoint = .zero, _ size: CGSize = .init(width: 100, height: 70)) -> HYMChartTooltipGeometry.Result? {
            HYMChartTooltipGeometry.resolve(anchor: anchor, size: size, container: container, preferred: [.bottom],
                gap: 999, position: .fixedTop, offset: offset, topInset: 8)
        }
        let first = try XCTUnwrap(resolve(.init(x: 20, y: 40, width: 1, height: 1)))
        let second = try XCTUnwrap(resolve(.init(x: 280, y: 180, width: 1, height: 1)))
        XCTAssertEqual(first.frame, second.frame); XCTAssertEqual(first.frame, .init(x: 110, y: 28, width: 100, height: 70))
        XCTAssertEqual(try XCTUnwrap(resolve(.zero, .init(x: 999, y: -999))).frame.origin, .init(x: 210, y: 20))
        XCTAssertEqual(try XCTUnwrap(resolve(.zero, .init(x: CGFloat.nan, y: CGFloat.infinity))).frame, first.frame)
        XCTAssertEqual(try XCTUnwrap(resolve(.zero, .zero, .init(width: 500, height: 500))).frame, container)
        XCTAssertNil(HYMChartTooltipGeometry.resolve(anchor: .zero, size: .init(width: 10, height: 10), container: .zero,
            preferred: [], gap: 0, position: .fixedTop))
    }

    func testAutomaticOffsetRetainsArrowAtRealAnchorAndDefaultGeometry() throws {
        let anchor = CGRect(x: 150, y: 130, width: 10, height: 10), size = CGSize(width: 100, height: 40)
        let container = CGRect(x: 0, y: 0, width: 300, height: 300)
        let old = try XCTUnwrap(HYMChartTooltipGeometry.resolve(anchor: anchor, size: size, container: container, preferred: [.top], gap: 6))
        let current = try XCTUnwrap(HYMChartTooltipGeometry.resolve(anchor: anchor, size: size, container: container, preferred: [.top], gap: 6, position: .automatic))
        XCTAssertEqual(current.frame, old.frame)
        let offset = try XCTUnwrap(HYMChartTooltipGeometry.resolve(anchor: anchor, size: size, container: container,
            preferred: [.top], gap: 6, position: .automatic, offset: .init(x: 20, y: 12)))
        XCTAssertEqual(offset.frame.origin, .init(x: old.frame.minX + 20, y: old.frame.minY + 12))
        XCTAssertEqual(offset.arrowX, anchor.midX)
    }

    func testPinnedControllerFitsLongTextAndRemeasuresScrollableContentAfterResize() throws {
        let host = UIView(frame: .init(x: 0, y: 0, width: 320, height: 200))
        var theme = HYMChartTooltipTheme(); theme.position = .fixedTop; theme.maxWidth = 500; theme.showsAnimation = false
        let controller = HYMChartTooltipController(host: host, theme: theme)
        controller.show(anchor: .zero, text: String(repeating: "超长名称 long name\n", count: 60), in: host.bounds, preferred: [.top])
        let tooltip = try XCTUnwrap(host.subviews.first as? HYMChartTooltip)
        XCTAssertTrue(host.bounds.contains(tooltip.frame))
        let label = try XCTUnwrap(descendants(tooltip).compactMap { $0 as? UILabel }.first)
        XCTAssertEqual(label.frame, tooltip.bounds.inset(by: theme.contentInset), "固定顶部没有箭头占位")
        let view = chart(LineChartRenderer.self, state())
        let content = try XCTUnwrap(view.cartesianTooltipContent(for: target(data(view, category: 1))))
        let body = CartesianTooltipContentView(content: content, presentation: view.cartesianTooltipPresentation, theme: theme)
        controller.show(anchor: .zero, contentView: body, in: host.bounds, preferred: [.bottom], allowsContentInteraction: true)
        host.frame.size = .init(width: 160, height: 120); controller.relayout(in: host.bounds); tooltip.layoutIfNeeded(); body.layoutIfNeeded()
        XCTAssertTrue(host.bounds.contains(tooltip.frame)); XCTAssertTrue(body.isScrollEnabled)
        XCTAssertGreaterThan(body.contentSize.height, body.bounds.height)
        controller.hide(animated: false); controller.relayout(in: .init(x: 0, y: 0, width: 200, height: 200))
        XCTAssertTrue(tooltip.isHidden)
    }

    func testOCUpdatesAndResetsSampleAndPlacementSettings() throws {
        let model = HYMCartesianModel(); let row = HYMCartesianSeries(); row.identifier = "s"; row.name = "S"; row.data = [10, 20]; model.series = [row]
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: .init(x: 0, y: 0, width: 390, height: 300))
        bridge.tooltipOptions.sampleOffset = -1; bridge.tooltipOptions.sampleBoundaryPolicy = .clamp
        bridge.tooltipOptions.sampleOffsetsBySeriesID = ["other": 0]
        bridge.tooltipOptions.fixedTopUsesPlotArea = true
        bridge.tooltipOptions.position = .fixedTop; bridge.tooltipOptions.offset = .init(x: 12, y: 3)
        try bridge.configure(model: model)
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>); view.layoutIfNeeded()
        let content = try XCTUnwrap(view.cartesianTooltipContent(for: target([try XCTUnwrap(view.rendererForTesting.datum(series: 0, category: 1))])))
        XCTAssertTrue(content.text.contains("10")); XCTAssertEqual(view.tooltipTheme.position, .fixedTop)
        XCTAssertTrue(view.tooltipTheme.fixedTopUsesPlotArea)
        XCTAssertEqual(view.tooltipTheme.offset, .init(x: 12, y: 3)); XCTAssertEqual(view.cartesianTooltipSampleSelection.boundaryPolicy, .clamp)
        view.tooltipTheme.font = .systemFont(ofSize: 20)
        bridge.tooltipOptions = .init(); try bridge.update(model: model, preserveViewport: true)
        XCTAssertEqual(view.cartesianTooltipSampleSelection, .init()); XCTAssertEqual(view.tooltipTheme.position, .automatic)
        XCTAssertEqual(view.tooltipTheme.offset, .zero); XCTAssertFalse(view.tooltipTheme.fixedTopUsesPlotArea)
        XCTAssertEqual(view.tooltipTheme.font.pointSize, 20, "更新位置选项保留原有外观覆盖")
    }

    func testSwiftUIUpdatesSampleAndPositionWithoutReplacingCharts() throws {
        var s = state(); s.tooltipTheme.fixedTopUsesPlotArea = true
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
            build: (CartesianTooltipSampleSelection, HYMChartTooltipTheme) -> AnyView) throws {
            let host = UIHostingController(rootView: build(s.interaction.sampleSelection, s.tooltipTheme))
            let window = UIWindow(frame: .init(x: 0, y: 0, width: 390, height: 500)); window.rootViewController = host; window.isHidden = false
            defer { window.isHidden = true; window.rootViewController = nil }
            host.view.layoutIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            let chart = try XCTUnwrap(descendants(host.view).compactMap { $0 as? HYMChartView<R> }.first)
            XCTAssertEqual(chart.cartesianTooltipSampleSelection.offset, -1); XCTAssertEqual(chart.tooltipTheme.position, .fixedTop)
            XCTAssertTrue(chart.tooltipTheme.fixedTopUsesPlotArea)
            host.rootView = build(.init(), .default); host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            XCTAssertTrue(chart === descendants(host.view).compactMap { $0 as? HYMChartView<R> }.first)
            XCTAssertEqual(chart.cartesianTooltipSampleSelection, .init()); XCTAssertEqual(chart.tooltipTheme.position, .automatic)
            XCTAssertFalse(chart.tooltipTheme.fixedTopUsesPlotArea)
        }
        try verify(LineChartRenderer.self) { AnyView(LineChart(model: s.model, playsAnimationOnAppear: false, cartesianTooltipSampleSelection: $0, tooltipTheme: $1).frame(height: 300)) }
        try verify(ColumnChartRenderer.self) { AnyView(ColumnChart(model: s.model, playsAnimationOnAppear: false, cartesianTooltipSampleSelection: $0, tooltipTheme: $1).frame(height: 300)) }
        try verify(BarChartRenderer.self) { AnyView(BarChart(model: s.model, playsAnimationOnAppear: false, cartesianTooltipSampleSelection: $0, tooltipTheme: $1).frame(height: 300)) }
        try verify(CombinedChartRenderer.self) { AnyView(CombinedChart(model: s.model, playsAnimationOnAppear: false, cartesianTooltipSampleSelection: $0, tooltipTheme: $1).frame(height: 300)) }
    }

    func testDemoConditionsParserAndResetAreConsistent() throws {
        var s = state()
        func item(_ name: String, section: String? = nil) throws -> ChartDemoPanel.Item {
            let b = Binding(get: { s }, set: { s = $0 })
            return try XCTUnwrap(CartesianDemoControls.sections(b).filter { section == nil || $0.title == section }.flatMap(\.items).first { $0.label == name })
        }
        XCTAssertTrue(try item("fixedTopInset", section: "弹窗外观").isEnabled)
        XCTAssertTrue(try item("fixedTopUsesPlotArea", section: "弹窗外观").isEnabled)
        XCTAssertFalse(try item("showsArrow", section: "弹窗外观").isEnabled)
        s.tooltipTheme.position = .automatic
        XCTAssertFalse(try item("fixedTopInset", section: "弹窗外观").isEnabled)
        XCTAssertFalse(try item("fixedTopUsesPlotArea", section: "弹窗外观").isEnabled)
        s.interaction.tooltipSampleSelection.showsSourceLabel = false
        XCTAssertFalse(try item("提示取值来源模板").isEnabled)
        s.interaction.tooltipSeriesOffsets = "series-2:2,invalid, s : -3,series-2:0,x:no"
        XCTAssertEqual(s.interaction.sampleSelection.offsetsBySeriesID, ["series-2": 0, "s": -3])
        s.interaction.popupMode = "位置回调"; XCTAssertFalse(try item("提示取值索引偏移").isEnabled)
        s.reset(); XCTAssertEqual(s.interaction.sampleSelection, .init()); XCTAssertEqual(s.tooltipTheme.position, .automatic)
    }
}
