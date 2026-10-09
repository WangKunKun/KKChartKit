import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class FixedTooltipLayoutTests: XCTestCase {
    private func model() -> CartesianChartModel {
        .init(title: "Energy", series: [
            .init(name: "Solar", data: [20, 30, 40], color: .systemBlue, id: "solar"),
            .init(name: "Battery", data: [-10, -20, -30], color: .systemOrange, id: "battery"),
            .init(name: "Grid", data: [10, 15, 20], color: .systemGreen, id: "grid")
        ])
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
        size: CGSize = .init(width: 390, height: 340), position: ChartLegendPosition = .top,
        columns: Bool = true) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: .init(origin: .zero, size: size))
        var theme = CartesianChartTheme(); theme.legend.isEnabled = true; theme.legend.position = position
        theme.legend.maxRows = 2; theme.legend.maxHeight = 90
        view.showsTooltipOnHit = true; view.isSharedTooltipOnTapEnabled = true
        view.tooltipTheme.position = .fixedTop; view.tooltipTheme.fixedTopUsesPlotArea = true
        view.tooltipTheme.showsAnimation = false
        view.cartesianTooltipPresentation.layout = columns ? .columns : .text
        view.configure(model: model(), theme: theme); view.layoutIfNeeded()
        return view
    }
    private func show<R: CartesianRendererBase<CartesianChartTheme>>(_ view: HYMChartView<R>) throws -> HYMChartTooltip {
        let plot = view.rendererForTesting.currentPlotFrame
        view.performTap(at: .init(x: plot.midX, y: plot.midY))
        let popup = try XCTUnwrap(view.subviews.compactMap { $0 as? HYMChartTooltip }.first)
        XCTAssertFalse(popup.isHidden)
        return popup
    }
    private func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }
    private func assertContained<R: CartesianRendererBase<CartesianChartTheme>>(_ popup: UIView, in view: HYMChartView<R>,
        file: StaticString = #filePath, line: UInt = #line) throws {
        let plot = view.rendererForTesting.currentPlotFrame.intersection(view.bounds)
        XCTAssertTrue(plot.insetBy(dx: -0.01, dy: -0.01).contains(popup.frame), "\(plot) / \(popup.frame)", file: file, line: line)
        let legend = view.rendererForTesting.legendView
        if !legend.isHidden { XCTAssertFalse(popup.frame.intersects(legend.frame), file: file, line: line) }
        let title = try XCTUnwrap(view.subviews.compactMap { $0 as? UILabel }.first { $0.text == "Energy" }, file: file, line: line)
        XCTAssertFalse(popup.frame.intersects(title.frame), file: file, line: line)
    }

    func testOptInPreservesNativeDefaultsPlotViewportHitAndAutomaticPlacement() throws {
        XCTAssertFalse(HYMChartTooltipTheme().fixedTopUsesPlotArea)
        XCTAssertFalse(HYMCartesianTooltipOptions().fixedTopUsesPlotArea)
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            let view = chart(type); let renderer = view.rendererForTesting
            view.tooltipTheme.fixedTopUsesPlotArea = false
            var hits = 0; view.onHit = { _, _ in hits += 1 }
            let popup = try show(view); XCTAssertEqual(popup.frame.minY, 8, accuracy: 0.01)
            let plot = renderer.currentPlotFrame, x = renderer.xAxisViewport, y = renderer.yAxisViewport
            let datum = try XCTUnwrap(renderer.datum(series: 1, category: 1))
            let selection = view.isCrosshairVisibleForTesting
            view.tooltipTheme.fixedTopUsesPlotArea = true; view.layoutIfNeeded()
            try assertContained(popup, in: view)
            XCTAssertEqual(renderer.currentPlotFrame, plot); XCTAssertEqual(renderer.xAxisViewport, x); XCTAssertEqual(renderer.yAxisViewport, y)
            XCTAssertEqual(renderer.datum(series: 1, category: 1)?.rawValue, datum.rawValue)
            XCTAssertEqual(view.isCrosshairVisibleForTesting, selection); XCTAssertEqual(hits, 1, "布局重定位不能伪造命中")
            view.tooltipTheme.fixedTopUsesPlotArea = false; view.layoutIfNeeded()
            XCTAssertEqual(popup.frame.minY, 8, accuracy: 0.01)
            view.tooltipTheme.position = .automatic; _ = try show(view); let automatic = popup.frame
            view.tooltipTheme.fixedTopUsesPlotArea = true; _ = try show(view)
            XCTAssertEqual(popup.frame, automatic, "新边界不影响 automatic")
        }
        try verify(LineChartRenderer.self); try verify(ColumnChartRenderer.self)
        try verify(BarChartRenderer.self); try verify(CombinedChartRenderer.self)
    }

    func testFourRenderersAllLegendEdgesTextColumnsNarrowAndLandscapeSizes() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            for size in [CGSize(width: 390, height: 340), .init(width: 220, height: 280), .init(width: 700, height: 240)] {
                for edge in [ChartLegendPosition.top, .bottom, .left, .right] {
                    for columns in [false, true] {
                        let view = chart(type, size: size, position: edge, columns: columns)
                        try assertContained(try show(view), in: view)
                    }
                }
            }
        }
        try verify(LineChartRenderer.self); try verify(ColumnChartRenderer.self)
        try verify(BarChartRenderer.self); try verify(CombinedChartRenderer.self)
    }

    func testLongContentScrollsOrTruncatesWithinPlotWithoutCoveringDecorations() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            for columns in [false, true] {
                let view = chart(type, size: .init(width: 220, height: 230), columns: columns)
                view.tooltipTextOptions.header = String(repeating: "Very long multiline header\n", count: 40)
                view.tooltipTheme.maxWidth = 1000
                let popup = try show(view); try assertContained(popup, in: view)
                if columns {
                    let body = try XCTUnwrap(descendants(popup).compactMap { $0 as? CartesianTooltipContentView }.first)
                    body.layoutIfNeeded(); XCTAssertTrue(body.isScrollEnabled)
                    XCTAssertGreaterThan(body.contentSize.height, body.bounds.height)
                    body.setContentOffset(.init(x: 0, y: body.contentSize.height - body.bounds.height), animated: false)
                    XCTAssertGreaterThan(body.contentOffset.y, 0); try assertContained(popup, in: view)
                }
            }
        }
        try verify(LineChartRenderer.self); try verify(ColumnChartRenderer.self)
        try verify(BarChartRenderer.self); try verify(CombinedChartRenderer.self)
    }

    func testResizeAndSameBoundsThemeChangesRelayoutWithoutNewSelection() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            let view = chart(type); let popup = try show(view)
            for size in [CGSize(width: 220, height: 240), .init(width: 700, height: 240), .init(width: 390, height: 340)] {
                view.frame.size = size; view.layoutIfNeeded(); XCTAssertFalse(popup.isHidden)
                try assertContained(popup, in: view)
            }
            let before = popup.frame
            view.tooltipTheme.fixedTopInset = 17; view.layoutIfNeeded()
            XCTAssertEqual(popup.frame.minY, before.minY + 9, accuracy: 0.01)
            view.tooltipTheme.offset = .init(x: -10000, y: -10000); view.layoutIfNeeded()
            try assertContained(popup, in: view)
            XCTAssertEqual(popup.frame.minY, view.rendererForTesting.currentPlotFrame.minY, accuracy: 0.01)
            view.tooltipTheme.offset = .init(x: 10000, y: 10000); view.layoutIfNeeded()
            try assertContained(popup, in: view)
        }
        try verify(LineChartRenderer.self); try verify(ColumnChartRenderer.self)
        try verify(BarChartRenderer.self); try verify(CombinedChartRenderer.self)
    }

    func testCollapsedPlotHidesRatherThanFallsBackOverTitleAndNextHitRecovers() throws {
        let view = chart(LineChartRenderer.self); let popup = try show(view)
        view.frame.size = .zero; view.layoutIfNeeded(); XCTAssertTrue(popup.isHidden)
        view.frame.size = .init(width: 390, height: 340); view.layoutIfNeeded()
        XCTAssertTrue(popup.isHidden, "不可用布局隐藏后等待下一次真实命中")
        try assertContained(try show(view), in: view)
    }

    func testNeutralFixedTopChoosesPlotAreaWhileNullRestoresIndependentOCRuntime() throws {
        var settings = ChartSpecificationDemoSettings(); settings.interaction.usesTooltip = true
        for kind in [CartesianDemoKind.line, .column, .bar, .combined] {
            let source = settings.specification(kind: kind)
            let config = try HYMChartsSpecificationAdapter().makeConfiguration(from: source)
            XCTAssertTrue(try XCTUnwrap(config.tooltip).theme().fixedTopUsesPlotArea)
            let document = try HYMChartSpecificationDocument(specification: source)
            let bridge = try document.makeNativeBridge(frame: .init(x: 0, y: 0, width: 390, height: 340))
            func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
                let view = try XCTUnwrap(bridge.chartView as? HYMChartView<R>)
                XCTAssertTrue(view.tooltipTheme.fixedTopUsesPlotArea)
                bridge.tooltipOptions.position = .fixedTop; bridge.tooltipOptions.fixedTopUsesPlotArea = false
                var plain = source; plain.tooltip = nil; plain.legend = nil; plain.schemaVersion = 1
                try bridge.update(specification: HYMChartSpecificationDocument(specification: plain), preserveViewport: true)
                XCTAssertFalse(view.tooltipTheme.fixedTopUsesPlotArea); XCTAssertEqual(view.tooltipTheme.position, .fixedTop)
                bridge.tooltipOptions.fixedTopUsesPlotArea = true
                try bridge.update(specification: HYMChartSpecificationDocument(specification: plain), preserveViewport: true)
                XCTAssertTrue(view.tooltipTheme.fixedTopUsesPlotArea)
            }
            switch kind {
            case .line: try verify(LineChartRenderer.self)
            case .column: try verify(ColumnChartRenderer.self)
            case .bar: try verify(BarChartRenderer.self)
            case .combined: try verify(CombinedChartRenderer.self)
            }
        }
    }

    func testDirectControllerKeepsExplicitContainerContractAndInvalidatesThemeCache() throws {
        let controllerHost = UIView(frame: .init(x: 0, y: 0, width: 220, height: 200))
        var theme = HYMChartTooltipTheme(); theme.position = .fixedTop; theme.fixedTopUsesPlotArea = true
        theme.showsAnimation = false
        let controller = HYMChartTooltipController(host: controllerHost, theme: theme)
        controller.show(anchor: .zero, text: "text", in: controllerHost.bounds, preferred: [.top])
        let popup = try XCTUnwrap(controllerHost.subviews.first as? HYMChartTooltip)
        XCTAssertEqual(popup.frame.minY, 8, accuracy: 0.01, "独立 controller 不推断 renderer 的边界")
        controller.theme.fixedTopInset = 21; controller.relayout(in: controllerHost.bounds)
        XCTAssertEqual(popup.frame.minY, 21, accuracy: 0.01)
    }
    func testCategoryZoomAndLegendToggleClearOldPopupAndNextHitUsesCurrentPlot() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            let view = chart(type); view.minimumVisibleCategories = 2
            let popup = try show(view)
            view.showCategoryRange(1..<3); XCTAssertTrue(popup.isHidden)
            let plot = view.rendererForTesting.currentPlotFrame
            let x = view.rendererForTesting.xAxisViewport, y = view.rendererForTesting.yAxisViewport
            try assertContained(try show(view), in: view)
            view.tooltipTheme.fixedTopUsesPlotArea = false; view.layoutIfNeeded()
            view.tooltipTheme.fixedTopUsesPlotArea = true; view.layoutIfNeeded()
            XCTAssertEqual(view.rendererForTesting.currentPlotFrame, plot)
            XCTAssertEqual(view.rendererForTesting.xAxisViewport, x); XCTAssertEqual(view.rendererForTesting.yAxisViewport, y)
            view.setSeriesVisible(false, for: "battery"); XCTAssertTrue(popup.isHidden)
            try assertContained(try show(view), in: view)
            XCTAssertEqual(view.isSeriesVisible("battery"), false)
        }
        try verify(LineChartRenderer.self); try verify(ColumnChartRenderer.self)
        try verify(BarChartRenderer.self); try verify(CombinedChartRenderer.self)
    }

    func testRendererWithoutPlotAreaCapabilityFallsBackToHostBounds() throws {
        let view = HYMChartView<BoundsOnlyTooltipRenderer>(frame: .init(x: 0, y: 0, width: 220, height: 180))
        view.tooltipTheme = .init(showsAnimation: false, position: .fixedTop, fixedTopUsesPlotArea: true)
        view.showsTooltipOnHit = true; view.configure(model: model(), theme: CartesianChartTheme())
        view.performTap(at: .init(x: 100, y: 100))
        let popup = try XCTUnwrap(view.subviews.compactMap { $0 as? HYMChartTooltip }.first)
        XCTAssertFalse(popup.isHidden); XCTAssertEqual(popup.frame.minY, 8, accuracy: 0.01)
        XCTAssertTrue(view.bounds.contains(popup.frame))
    }

}


private final class BoundsOnlyTooltipRenderer: HYMChartRenderer {
    typealias Model = CartesianChartModel
    typealias Theme = CartesianChartTheme
    required init() {}
    func mount(into view: UIView) {}
    func unmount(from view: UIView) {}
    func render(model: Model, theme: Theme, context: HYMChartRenderContext) {}
    var animatableLayers: [CALayer] { [] }
    func hitTest(_ point: CGPoint) -> (any HYMChartHitTarget)? { Target() }
    func tooltipAnchor(for target: any HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        .init(frame: .init(x: 100, y: 100, width: 1, height: 1), preferredPlacements: [.top])
    }
    private struct Target: HYMChartHitTarget {
        let identifier = "point"
        let index = 0
        var tooltipText: String? { "Value" }
    }
}
