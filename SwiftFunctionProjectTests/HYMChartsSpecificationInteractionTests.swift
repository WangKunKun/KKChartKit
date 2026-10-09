import XCTest
import UIKit
@testable import SwiftFunctionProject

@MainActor final class HYMChartsSpecificationInteractionTests: XCTestCase {
    private let adapter = HYMChartsSpecificationAdapter()
    private func source(_ kind: CartesianDemoKind = .line) -> ChartSpecification {
        var settings = ChartSpecificationDemoSettings(); settings.missing = false
        settings.interaction.usesTooltip = true; settings.interaction.usesLegend = true
        return settings.specification(kind: kind)
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ s: ChartSpecification) throws -> HYMChartView<R> {
        let config = try adapter.makeConfiguration(from: s)
        let view = HYMChartView<R>(frame: .init(x: 0, y: 0, width: 480, height: 360))
        view.showsTooltipOnHit = config.tooltip?.isEnabled ?? true; view.isSharedTooltipOnTapEnabled = true
        view.tooltipTextOptions = config.tooltip?.textOptions ?? .init()
        view.cartesianTooltipPresentation = config.tooltip?.presentation() ?? .init()
        view.cartesianTooltipSampleSelection = config.tooltip?.sampleSelection ?? .init()
        view.tooltipTheme = config.tooltip?.theme() ?? .default; view.tooltipTheme.showsAnimation = false
        view.configure(model: config.model, theme: config.theme); view.layoutIfNeeded(); return view
    }
    private func target<R: CartesianRendererBase<CartesianChartTheme>>(_ view: HYMChartView<R>, _ index: Int) -> CartesianSharedHitTarget {
        let data = (view.rendererForTesting.currentModel?.series.indices ?? 0..<0).compactMap { view.rendererForTesting.datum(series: $0, category: index) }
        return .init(categoryIndex: index, entries: data.map {
            .init(seriesID: $0.seriesID, seriesIndex: $0.seriesIndex, name: $0.name, value: $0.displayValue,
                  isSecondaryAxis: $0.yAxisIndex == 1, datum: $0, timeBucket: $0.timeBucket)
        }, crosshairX: 100, headerKey: "current-\(index)")
    }
    func testDefaultsAndEveryLegendEnumMapWithoutChangingDataOrSeriesOrder() throws {
        var s = source(); s.tooltip = nil; s.legend = nil; s.schemaVersion = 1
        let original = try adapter.makeConfiguration(from: s)
        XCTAssertNil(original.tooltip); XCTAssertTrue(original.theme.showsTooltipOnHit)
        XCTAssertEqual(original.theme.legend.position, .bottom)
        for position in ChartLegendPlacement.allCases {
            for alignment in ChartLegendRowAlignment.allCases {
                for overflow in ChartLegendOverflowPolicy.allCases {
                    s.schemaVersion = 6; s.legend = .init(); s.legend?.position = position
                    s.legend?.alignment = alignment; s.legend?.overflow = overflow
                    s.legend?.maxRows = 7; s.legend?.maxWidth = 99; s.legend?.maxHeight = 83
                    s.legend?.allowsToggling = false; s.legend?.startsNewRowPerGroup = true
                    s.legend?.titlesBySeriesID = ["source-1": "图例别名"]
                    let c = try adapter.makeConfiguration(from: s)
                    XCTAssertEqual(c.theme.legend.position.rawValue, position.rawValue)
                    XCTAssertEqual(c.theme.legend.alignment.rawValue, alignment.rawValue)
                    XCTAssertEqual(c.theme.legend.overflow, overflow == .scroll ? .scroll : .expand)
                    XCTAssertEqual(c.theme.legend.maxRows, 7); XCTAssertEqual(c.theme.legend.maxWidth, 99)
                    XCTAssertEqual(c.theme.legend.maxHeight, 83); XCTAssertFalse(c.theme.legend.allowsToggling)
                    XCTAssertTrue(c.theme.legend.startsNewRowPerGroup)
                    XCTAssertEqual(c.theme.legend.itemOverrides["source-1"]?.title, "图例别名")
                    XCTAssertEqual(c.model.series.map(\.id), original.model.series.map(\.id))
                    XCTAssertEqual(c.model.series.map(\.data), original.model.series.map(\.data))
                }
            }
        }
    }
    func testSeriesRulesUseStableIDsRetainRuntimeImagesAndDoNotLeakAfterReorder() throws {
        var s = source(); s.tooltip?.seriesRules = ["source-1": .init(title: "提示别名", hidesValue: true)]
        s.legend?.titlesBySeriesID = ["source-0": "图例别名"]
        s.series.reverse()
        let c = try adapter.makeConfiguration(from: s), tooltip = try XCTUnwrap(c.tooltip)
        var runtime = CartesianTooltipPresentation(); let image = UIImage()
        runtime.iconSize = 23; runtime.rowStyleProvider = { _ in .init(title: "runtime", image: image) }
        let view = try chart(LineChartRenderer.self, s)
        view.cartesianTooltipPresentation = tooltip.presentation(preservingRuntime: runtime)
        let content = try XCTUnwrap(view.cartesianTooltipContent(for: target(view, 1)))
        let rows = content.sections.flatMap(\.rows)
        XCTAssertEqual(rows.map { $0.datum?.seriesID }, ["source-1", "source-0"])
        XCTAssertEqual(rows[0].title, "提示别名"); XCTAssertNil(rows[0].value)
        XCTAssertTrue(rows[0].image === image); XCTAssertEqual(view.cartesianTooltipPresentation.iconSize, 23)
        XCTAssertTrue(rows[1].title.hasPrefix("runtime")); XCTAssertEqual(rows[0].datum?.categoryIndex, 1)
        XCTAssertEqual(rows[0].displayedDatum?.categoryIndex, 0)
        XCTAssertFalse(content.text.contains("小计"))
        XCTAssertEqual(view.rendererForTesting.legendItems.map(\.title), ["电池", "图例别名"])
        s.tooltip?.seriesRules = [:]
        view.cartesianTooltipPresentation = try XCTUnwrap(adapter.makeConfiguration(from: s).tooltip).presentation(preservingRuntime: runtime)
        XCTAssertNotNil(try XCTUnwrap(view.cartesianTooltipContent(for: target(view, 1))).sections[0].rows[0].value)
    }
    func testFourRenderersPreviousRawValuesKeepCurrentHitHeaderG1AndPercentCoordinates() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ kind: CartesianDemoKind) throws {
            // G1 shared boundaries are a line/area capability, not a column/bar policy.
            let boundaries: [ChartStackedAreaBoundary] = (kind == .line || kind == .combined) ? ChartStackedAreaBoundary.allCases : [.independent]
            for boundary in boundaries {
                for stacking in [ChartStackingPolicy.sum, .percentOfAbsoluteTotal, .percentOfFixedTotal(200)] {
                    var s = source(kind); s.stackedAreaBoundary = boundary; s.stacking = stacking
                    s.tooltip?.sampleSelection.offsetsBySeriesID = ["source-1": 0]
                    let view = try chart(type, s), hit = target(view, 1)
                    let rows = try XCTUnwrap(view.cartesianTooltipContent(for: hit)).sections.flatMap(\.rows)
                    XCTAssertEqual(rows[0].datum?.rawValue, 60); XCTAssertEqual(rows[0].displayedDatum?.rawValue, 40)
                    XCTAssertEqual(rows[0].sourceLabel, "取值 8:00"); XCTAssertTrue(rows[0].value?.contains("40 W") == true)
                    XCTAssertEqual(rows[1].datum?.rawValue, 30); XCTAssertEqual(rows[1].displayedDatum?.rawValue, 30)
                    XCTAssertNil(rows[1].sourceLabel)
                    XCTAssertEqual(view.cartesianTooltipContent(for: hit)?.header, "当前 current-1")
                    let before = view.rendererForTesting.datum(series: 0, category: 1)?.drawValue
                    var bare = s; bare.tooltip = nil
                    let c = try adapter.makeConfiguration(from: bare); view.update(model: c.model, theme: c.theme); view.layoutIfNeeded()
                    XCTAssertEqual(view.rendererForTesting.datum(series: 0, category: 1)?.drawValue, before)
                    XCTAssertEqual(c.source.series, s.series)
                }
            }
        }
        try verify(LineChartRenderer.self, .line); try verify(ColumnChartRenderer.self, .column)
        try verify(BarChartRenderer.self, .bar); try verify(CombinedChartRenderer.self, .combined)
    }
    func testBoundaryExtremeOffsetsSparseMissingAndZeroFilterUseDisplaySample() throws {
        for boundary in ChartTooltipBoundaryPolicy.allCases {
            for offset in [Int.min, -1, Int.max] {
                var s = source(); s.tooltip?.sampleSelection.offset = offset; s.tooltip?.sampleSelection.boundaryPolicy = boundary
                let view = try chart(LineChartRenderer.self, s), content = view.cartesianTooltipContent(for: target(view, 0))
                switch boundary {
                case .omit: XCTAssertNil(content)
                case .current: XCTAssertEqual(content?.sections[0].rows[0].displayedDatum?.categoryIndex, 0)
                case .clamp: XCTAssertEqual(content?.sections[0].rows[0].displayedDatum?.categoryIndex, offset < 0 ? 0 : 5)
                }
            }
        }
        var s = source(); s.series[0].samples[0].value = 0; s.tooltip?.hidesZeroValues = true
        var view = try chart(ColumnChartRenderer.self, s)
        XCTAssertEqual(view.cartesianTooltipContent(for: target(view, 1))?.sections[0].rows.count, 1)
        s.series[0].samples.remove(at: 0); s.series[1].samples[0].value = nil
        view = try chart(ColumnChartRenderer.self, s)
        XCTAssertNil(view.cartesianTooltipContent(for: target(view, 1)), "缺测不向前搜索；所有行省略不留空表头")
        XCTAssertEqual(view.rendererForTesting.datum(series: 0, category: 1)?.rawValue, 60)
    }
    func testLegendPositionsClippingToggleIsolationAndHiddenRowsOnFourRenderers() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ kind: CartesianDemoKind) throws {
            for position in ChartLegendPlacement.allCases {
                var s = source(kind); s.legend?.position = position; s.legend?.titlesBySeriesID = ["source-0": "别名"]
                s.tooltip?.seriesRules = ["source-0": .init(isHidden: true)]
                let view = try chart(type, s), renderer = view.rendererForTesting
                XCTAssertFalse(renderer.legendView.isHidden); XCTAssertTrue(view.bounds.contains(renderer.legendView.frame))
                XCTAssertFalse(renderer.legendView.frame.intersects(renderer.currentPlotFrame))
                XCTAssertEqual(renderer.legendItems.first?.title, "别名")
                XCTAssertFalse(view.cartesianTooltipContent(for: target(view, 1))!.sections[0].rows.contains { $0.datum?.seriesID == "source-0" })
                var events: [String] = []; view.onSeriesVisibilityChanged = { id, _ in events.append(id) }
                renderer.legendView.buttons[0].sendActions(for: .touchUpInside); view.layoutIfNeeded()
                XCTAssertEqual(events, ["source-0"]); XCTAssertFalse(view.isSeriesVisible("source-0") ?? true)
                XCTAssertEqual(s.series[0].isVisible, true)
                s.legend?.allowsToggling = false
                let c = try adapter.makeConfiguration(from: s); view.update(model: c.model, theme: c.theme); view.layoutIfNeeded()
                XCTAssertFalse(renderer.legendView.buttons[0].isEnabled)
                s.showsLegend = false
                let hidden = try adapter.makeConfiguration(from: s); view.update(theme: hidden.theme); view.layoutIfNeeded()
                XCTAssertTrue(renderer.legendView.isHidden)
            }
        }
        try verify(LineChartRenderer.self, .line); try verify(ColumnChartRenderer.self, .column)
        try verify(BarChartRenderer.self, .bar); try verify(CombinedChartRenderer.self, .combined)
    }
    func testBridgeAtomicFailureViewportRuntimeRestorationAndDisabledTooltip() throws {
        var s = source(); let bridge = HYMCartesianChartViewBridge(kind: .line, frame: .init(x: 0, y: 0, width: 480, height: 360))
        bridge.showsTooltip = false; bridge.tooltipOptions.header = "宿主 {key}"
        bridge.tooltipOptions.sampleOffset = 2
        try bridge.configure(specification: .init(specification: s))
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>); view.layoutIfNeeded()
        XCTAssertTrue(view.showsTooltipOnHit); XCTAssertEqual(view.tooltipTheme.position, .fixedTop)
        XCTAssertEqual(view.cartesianTooltipPresentation.layout, .columns)
        bridge.showCategoryRange(NSRange(location: 1, length: 3)); let window = view.rendererForTesting.currentViewport
        var bad = s; bad.valueAxes[0].isReversed = true
        XCTAssertThrowsError(try bridge.update(specification: .init(specification: bad), preserveViewport: true))
        XCTAssertEqual(view.cartesianTooltipSampleSelection.offset, -1); XCTAssertEqual(view.tooltipTextOptions.header, "当前 {key}")
        XCTAssertEqual(view.rendererForTesting.currentViewport, window)
        s.tooltip?.isEnabled = false
        try bridge.update(specification: .init(specification: s), preserveViewport: true); view.layoutIfNeeded()
        XCTAssertFalse(view.showsTooltipOnHit)
        let plot = view.rendererForTesting.currentPlotFrame
        view.performTap(at: .init(x: plot.midX, y: plot.midY))
        XCTAssertFalse(view.subviews.contains { $0 is HYMChartTooltip && !$0.isHidden })
        s.tooltip = nil; s.legend = nil; s.schemaVersion = 5
        try bridge.update(specification: .init(specification: s), preserveViewport: true); view.layoutIfNeeded()
        XCTAssertFalse(view.showsTooltipOnHit); XCTAssertEqual(view.tooltipTextOptions.header, "宿主 {key}")
        XCTAssertEqual(view.cartesianTooltipSampleSelection.offset, 2); XCTAssertEqual(view.tooltipTheme.position, .automatic)
        XCTAssertEqual(view.cartesianTooltipPresentation.layout, .text)
        XCTAssertEqual(view.rendererForTesting.currentViewport, window)
    }
    func testPinnedTooltipOnRealTapResizesAndUpdateClearsPresentation() throws {
        let s = source(), view = try chart(LineChartRenderer.self, s)
        var indices: [Int] = []; view.onHit = { hit, _ in indices = (hit as? CartesianHitDataSource)?.chartData.map(\.categoryIndex) ?? [] }
        let plot = view.rendererForTesting.currentPlotFrame
        view.performTap(at: .init(x: plot.midX, y: plot.midY))
        let popup = try XCTUnwrap(view.subviews.compactMap { $0 as? HYMChartTooltip }.first)
        XCTAssertFalse(popup.isHidden); XCTAssertEqual(popup.frame.minY, plot.minY + 8, accuracy: 0.1)
        XCTAssertFalse(indices.isEmpty)
        view.frame.size = .init(width: 220, height: 170); view.layoutIfNeeded()
        XCTAssertTrue(view.bounds.contains(popup.frame))
        let c = try adapter.makeConfiguration(from: s); view.update(model: c.model, theme: c.theme)
        XCTAssertTrue(popup.isHidden)
    }
    func testDemoEnableDisableKeepsPerIDRulesAndResetRestoresV1() throws {
        var settings = ChartSpecificationDemoSettings()
        settings.interaction.usesTooltip = true; settings.interaction.usesLegend = true
        settings.interaction.tooltip.seriesRules = ["source-0": .init(title: "零"), "source-1": .init(isHidden: true)]
        for kind in [CartesianDemoKind.line, .column, .bar, .combined] {
            let s = settings.specification(kind: kind); XCTAssertEqual(s.schemaVersion, 6); XCTAssertNoThrow(try s.validate())
            XCTAssertEqual(s.tooltip?.seriesRules["source-0"]?.title, "零")
        }
        settings.interaction.usesTooltip = false; settings.interaction.usesLegend = false
        XCTAssertEqual(settings.specification(kind: .line).schemaVersion, 1)
        settings.interaction.usesTooltip = true
        XCTAssertEqual(settings.specification(kind: .line).tooltip?.seriesRules["source-1"]?.isHidden, true)
        settings = .init(); XCTAssertEqual(settings.specification(kind: .line).schemaVersion, 1)
        XCTAssertTrue(settings.interaction.tooltip.seriesRules.isEmpty)
    }
}
