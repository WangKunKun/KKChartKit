import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class RichTooltipTests: XCTestCase {
    private func state(_ kind: CartesianDemoKind = .line) -> CartesianDemoState {
        var s = CartesianDemoState(kind: kind); s.richTooltipPreset(); return s
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ s: CartesianDemoState) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 390, height: 420))
        view.showsTooltipOnHit = true; view.isSharedTooltipOnTapEnabled = true
        view.tooltipTextOptions = s.interaction.textOptions
        view.cartesianTooltipPresentation = s.interaction.presentation
        view.tooltipTheme = s.tooltipTheme; view.tooltipTheme.showsAnimation = false
        view.configure(model: s.model, theme: s.builtTheme); view.layoutIfNeeded()
        return view
    }
    private func data(_ s: CartesianDemoState, category: Int = 0) -> [CartesianDatum] {
        let view = chart(ColumnChartRenderer.self, s)
        return s.model.series.indices.compactMap { view.rendererForTesting.datum(series: $0, category: category) }
    }
    private func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }
    private func content(_ s: CartesianDemoState, category: Int = 0) throws -> CartesianTooltipContent {
        try XCTUnwrap(CartesianTooltipContent.make(data: data(s, category: category), options: s.interaction.textOptions,
            presentation: s.interaction.presentation, header: s.model.categoryLabels[category]))
    }

    func testStructuredContentKeepsGroupsMetadataImagesAndSignedSubtotal() throws {
        let s = state(); let content = try content(s)
        XCTAssertEqual(content.header, "08:00")
        XCTAssertEqual(content.sections.map(\.title), ["能源", "环境", "未分组"])
        XCTAssertEqual(content.sections[0].rows.map(\.value), ["100 W", "-40 W", "60 W"])
        XCTAssertEqual(content.sections[0].rows[0].title, "光伏（采样1）")
        XCTAssertNotNil(content.sections[0].rows[0].image)
        XCTAssertEqual(content.sections[0].rows[1].datum?.rawValue, -40)
        XCTAssertTrue(content.sections[0].rows[2].isSubtotal)
        XCTAssertNil(content.sections[2].rows[0].value)
        XCTAssertEqual(content.sections[2].rows[0].text, "备用（采样1）")
        let second = try self.content(s, category: 1)
        XCTAssertEqual(second.sections.map(\.title), ["能源", "未分组"])
        XCTAssertEqual(data(s, category: 1).count, 4, "逐点隐藏不修改原数据")
    }

    func testProviderRunsAfterGlobalFilterAndOnlyOncePerIncludedDatum() throws {
        let s = state(); let data = data(s)
        var options = s.interaction.textOptions; options.cartesian.hidesZeroValues = true
        options.cartesian.excludedSeriesIDs = ["series-2"]
        var visited: [String] = []; var presentation = CartesianTooltipPresentation()
        presentation.rowStyleProvider = { datum in
            visited.append(datum.seriesID)
            return datum.seriesID == "series-1" ? .init(hidesValue: true) : nil
        }
        let content = try XCTUnwrap(CartesianTooltipContent.make(data: data, options: options, presentation: presentation))
        XCTAssertEqual(visited, ["series-0", "series-1"])
        XCTAssertEqual(content.text, "能源\n  光伏: 100 W\n  电池")
        XCTAssertFalse(content.text.contains("小计"))
        presentation.rowStyleProvider = { _ in .init(isHidden: true) }
        XCTAssertNil(CartesianTooltipContent.make(data: data, options: options, presentation: presentation, header: "08:00"))
    }

    func testAggregationRulesKeepIntervalAndOriginalRangeWithoutInventingPointName() throws {
        var s = state(.column); s.pointCount = 300; s.timeEnabled = true; s.grouping = true
        s.groupingConfig.minimumColumnWidth = 20
        for i in 0..<4 { s.series[i].dataText = ""; s.series[i].aggregation = "平均" }
        let data = data(s)
        XCTAssertTrue(data.allSatisfy { $0.rawValue == nil && $0.sourceRange.count > 1 })
        let content = try XCTUnwrap(CartesianTooltipContent.make(data: data, options: s.interaction.textOptions,
            presentation: s.interaction.presentation, header: "bucket"))
        XCTAssertTrue(content.text.contains("有效")); XCTAssertFalse(content.text.contains("（采样"))
        XCTAssertFalse(content.text.contains("小计"))
        XCTAssertEqual(content.sections[0].rows[0].datum?.sourceRange, data[0].sourceRange)
    }

    func testSingleAndSharedPathsUseSameRulesAcrossFourRenderersAndCanClearThem() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ kind: CartesianDemoKind) throws {
            let s = state(kind); let view = chart(type, s)
            var last: [CartesianDatum] = []
            view.onHit = { target, _ in last = (target as? CartesianHitDataSource)?.chartData ?? [] }
            let plot = view.rendererForTesting.currentPlotFrame
            let point = CGPoint(x: plot.midX, y: plot.midY)
            for shared in [true, false] {
                view.isSharedTooltipOnTapEnabled = shared
                view.cartesianTooltipPresentation.rowStyleProvider = { _ in .init(title: "OVERRIDE", hidesValue: true) }
                view.performTap(at: point)
                let tooltip = try XCTUnwrap(view.subviews.compactMap { $0 as? HYMChartTooltip }.first)
                XCTAssertFalse(tooltip.isHidden)
                XCTAssertTrue(tooltip.isUserInteractionEnabled)
                XCTAssertTrue(descendants(tooltip).contains { $0.accessibilityLabel == "OVERRIDE" })
                XCTAssertEqual(last.count, shared ? 4 : 1)
                XCTAssertTrue(last.allSatisfy { $0.name != "OVERRIDE" })
                view.cartesianTooltipPresentation.rowStyleProvider = { _ in .init(isHidden: true) }
                view.performTap(at: point)
                XCTAssertTrue(tooltip.isHidden)
                XCTAssertTrue(view.isCrosshairVisibleForTesting)
                view.cartesianTooltipPresentation = .init()
                view.performTap(at: point)
                XCTAssertFalse(tooltip.isHidden); XCTAssertFalse(tooltip.isUserInteractionEnabled)
                XCTAssertFalse(descendants(tooltip).contains { $0 is CartesianTooltipContentView })
                view.cartesianTooltipPresentation = s.interaction.presentation
            }
        }
        try verify(LineChartRenderer.self, .line); try verify(ColumnChartRenderer.self, .column)
        try verify(BarChartRenderer.self, .bar); try verify(CombinedChartRenderer.self, .combined)
    }

    func testLongMultilingualRowsManyGroupsConstrainAndScrollWithoutClipping() throws {
        var model = CartesianChartModel(series: (0..<16).map { i in
            var series = CartesianSeriesElement(name: "名称 VeryLongUnbrokenName長い名前 \(i)", data: [Double(i)], id: "s\(i)")
            series.groupID = "g\(i % 5)"; series.unit = "kWh"; return series
        })
        model.groups = (0..<5).map { .init(id: "g\($0)", name: "业务组 \($0)") }
        let chart = HYMChartView<LineChartRenderer>(frame: .init(x: 0, y: 0, width: 240, height: 240))
        chart.configure(model: model, theme: CartesianChartTheme()); chart.layoutIfNeeded()
        let data = (0..<16).compactMap { chart.rendererForTesting.datum(series: $0, category: 0) }
        var options = HYMChartTooltipTextOptions(); options.cartesian.groupsByBusinessID = true
        var presentation = CartesianTooltipPresentation(); presentation.layout = .columns
        presentation.rowStyleProvider = { _ in .init(image: UIImage(systemName: "bolt.fill")) }
        let content = try XCTUnwrap(CartesianTooltipContent.make(data: data, options: options, presentation: presentation))
        for width: CGFloat in [90, 180, 340] {
            let host = UIView(frame: .init(x: 0, y: 0, width: width, height: 170))
            var theme = HYMChartTooltipTheme(); theme.maxWidth = 400; theme.showsAnimation = false
            let controller = HYMChartTooltipController(host: host, theme: theme)
            let body = CartesianTooltipContentView(content: content, presentation: presentation, theme: theme)
            controller.show(anchor: .init(x: width / 2, y: 10, width: 1, height: 1), contentView: body,
                in: host.bounds, preferred: [.top, .bottom], allowsContentInteraction: true)
            let tooltip = try XCTUnwrap(host.subviews.first as? HYMChartTooltip)
            tooltip.layoutIfNeeded(); body.layoutIfNeeded()
            XCTAssertTrue(host.bounds.contains(tooltip.frame))
            XCTAssertTrue(body.isScrollEnabled); XCTAssertGreaterThan(body.contentSize.height, body.bounds.height)
            let items = descendants(body).filter { $0.isAccessibilityElement && $0.accessibilityLabel?.contains("名称") == true }
            XCTAssertEqual(items.count, 16)
            for item in items {
                item.layoutIfNeeded()
                XCTAssertLessThanOrEqual(item.frame.maxX, body.bounds.width - 8, "为滚动条保留空间，避免遮挡数值")
                for label in item.subviews.compactMap({ $0 as? UILabel }) where label.text?.isEmpty == false {
                    XCTAssertGreaterThan(label.frame.width, 0)
                    XCTAssertTrue(item.bounds.insetBy(dx: -0.5, dy: -0.5).contains(label.frame))
                    XCTAssertGreaterThanOrEqual(label.frame.height + 0.5, label.sizeThatFits(.init(width: label.frame.width, height: 10000)).height)
                }
            }
            body.setContentOffset(CGPoint(x: 0, y: body.contentSize.height - body.bounds.height), animated: false)
            XCTAssertGreaterThan(body.contentOffset.y, 0)
            let last = try XCTUnwrap(items.last)
            XCTAssertTrue(last.convert(last.bounds, to: body).intersects(body.bounds))
        }
    }

    func testOCPresentationCopiesSettingsAndRemovesProviderOnUpdate() throws {
        let model = HYMCartesianModel(); let row = HYMCartesianSeries()
        row.identifier = "s"; row.name = "original"; row.data = [10, 20]; model.series = [row]
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: .init(x: 0, y: 0, width: 390, height: 300))
        bridge.tooltipOptions.layout = .columns; bridge.tooltipOptions.iconSize = 24
        bridge.tooltipOptions.rowStyleProvider = { datum in
            XCTAssertEqual(datum.sourceRange.length, 1)
            let style = HYMCartesianTooltipRowStyle(); style.title = "OC point"; style.hidesValue = true
            style.image = UIImage(systemName: "sun.max.fill"); return style
        }
        try bridge.configure(model: model); bridge.chartView.layoutIfNeeded()
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        let datum = try XCTUnwrap(view.rendererForTesting.datum(series: 0, category: 0))
        let content = try XCTUnwrap(CartesianTooltipContent.make(data: [datum], presentation: view.cartesianTooltipPresentation))
        XCTAssertEqual(content.text, "OC point"); XCTAssertEqual(view.cartesianTooltipPresentation.iconSize, 24)
        bridge.tooltipOptions.layout = .text; bridge.tooltipOptions.rowStyleProvider = nil
        try bridge.update(model: model, preserveViewport: true)
        XCTAssertNil(view.cartesianTooltipPresentation.rowStyleProvider)
        XCTAssertEqual(view.cartesianTooltipPresentation.layout, .text)
    }

    func testSwiftUIUpdatesPresentationWithoutRecreatingAnyCartesianChart() throws {
        let s = state()
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
            build: (CartesianTooltipPresentation) -> AnyView) throws {
            let host = UIHostingController(rootView: build(s.interaction.presentation))
            let window = UIWindow(frame: .init(x: 0, y: 0, width: 390, height: 500))
            window.rootViewController = host; window.isHidden = false
            defer { window.isHidden = true; window.rootViewController = nil }
            host.view.layoutIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            let chart = try XCTUnwrap(descendants(host.view).compactMap { $0 as? HYMChartView<R> }.first)
            XCTAssertEqual(chart.cartesianTooltipPresentation.layout, .columns)
            XCTAssertNotNil(chart.cartesianTooltipPresentation.rowStyleProvider)
            host.rootView = build(.init()); host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            XCTAssertTrue(chart === descendants(host.view).compactMap { $0 as? HYMChartView<R> }.first)
            XCTAssertEqual(chart.cartesianTooltipPresentation.layout, .text)
            XCTAssertNil(chart.cartesianTooltipPresentation.rowStyleProvider)
        }
        try verify(LineChartRenderer.self) { AnyView(LineChart(model: s.model, playsAnimationOnAppear: false, cartesianTooltipPresentation: $0).frame(height: 300)) }
        try verify(ColumnChartRenderer.self) { AnyView(ColumnChart(model: s.model, playsAnimationOnAppear: false, cartesianTooltipPresentation: $0).frame(height: 300)) }
        try verify(BarChartRenderer.self) { AnyView(BarChart(model: s.model, playsAnimationOnAppear: false, cartesianTooltipPresentation: $0).frame(height: 300)) }
        try verify(CombinedChartRenderer.self) { AnyView(CombinedChart(model: s.model, playsAnimationOnAppear: false, cartesianTooltipPresentation: $0).frame(height: 300)) }
    }

    func testHideAnimationCannotHideNewContentAndInteractionResets() throws {
        let host = UIView(frame: .init(x: 0, y: 0, width: 300, height: 400))
        let controller = HYMChartTooltipController(host: host)
        let anchor = CGRect(x: 100, y: 100, width: 2, height: 2)
        controller.show(anchor: anchor, text: "old", in: host.bounds, preferred: [.top], animated: false)
        controller.hide()
        controller.show(anchor: anchor, text: "new", in: host.bounds, preferred: [.top], animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        let tooltip = try XCTUnwrap(host.subviews.first as? HYMChartTooltip)
        XCTAssertFalse(tooltip.isHidden); XCTAssertEqual(tooltip.alpha, 1)
        XCTAssertFalse(tooltip.isUserInteractionEnabled)
    }

    func testDemoRulesDisableIrrelevantControlsAndResetRestoresDefaults() throws {
        var s = state()
        func item(_ name: String) throws -> ChartDemoPanel.Item {
            let b = Binding(get: { s }, set: { s = $0 })
            return try XCTUnwrap(CartesianDemoControls.sections(b).flatMap(\.items).first { $0.label == name })
        }
        XCTAssertTrue(try item("提示图标尺寸").isEnabled)
        s.interaction.tooltipPresentation.layout = .text
        XCTAssertFalse(try item("提示图标尺寸").isEnabled)
        XCTAssertTrue(try item("提示逐点规则预设").isEnabled)
        s.interaction.popupMode = "位置回调"
        XCTAssertFalse(try item("提示逐点规则预设").isEnabled)
        s.reset(); XCTAssertEqual(s.interaction.tooltipPresentation.layout, .text)
        XCTAssertNil(s.interaction.presentation.rowStyleProvider)
    }
}
