import XCTest
import SwiftUI
@testable import SwiftFunctionProject

final class ChartUpdateTests: XCTestCase {
    private var model: CartesianChartModel {
        CartesianChartModel(series: [CartesianSeriesElement(name: "a", data: [10, 20, 30, 40])])
    }

    private func findChart<R: HYMChartRenderer>(in view: UIView, renderer: R.Type) -> HYMChartView<R>? {
        if let chart = view as? HYMChartView<R> { return chart }
        return view.subviews.lazy.compactMap { self.findChart(in: $0, renderer: renderer) }.first
    }

    private func checkCallback<R: HYMChartRenderer>(
        renderer: R.Type, makeView: (Bool, @escaping () -> Void) -> AnyView,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        var received: [Int] = []
        let host = UIHostingController(rootView: makeView(true) { received.append(1) })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let chart = try XCTUnwrap(findChart(in: host.view, renderer: renderer), file: file, line: line)
        chart.performTap(at: CGPoint(x: chart.bounds.midX, y: chart.bounds.midY))
        XCTAssertEqual(received, [1], file: file, line: line)
        let viewport = chart.rendererForTesting as? any HYMChartXAxisZoomable
        viewport?.zoomXAxis(factor: 2, anchorScreenX: chart.bounds.midX)
        let before = viewport?.xAxisViewport
        host.rootView = makeView(true) { received.append(2) }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(chart === findChart(in: host.view, renderer: renderer), file: file, line: line)
        XCTAssertEqual(viewport?.xAxisViewport, before, "SwiftUI 更新应保留窗口", file: file, line: line)
        chart.performTap(at: CGPoint(x: chart.bounds.midX, y: chart.bounds.midY))
        XCTAssertEqual(received, [1, 2], "SwiftUI 更新应替换最初捕获的回调", file: file, line: line)
        host.rootView = makeView(false) { received.append(3) }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertNil(chart.onHit, "移除回调应释放旧闭包", file: file, line: line)
        chart.performTap(at: CGPoint(x: chart.bounds.midX, y: chart.bounds.midY))
        XCTAssertEqual(received, [1, 2], file: file, line: line)

    }

    func testLineSwiftUIUsesLatestCallback() throws {
        try checkCallback(renderer: LineChartRenderer.self) { enabled, callback in
            AnyView(LineChart(model: self.model, playsAnimationOnAppear: false,
                              onHit: enabled ? { _, _ in callback() } : nil, isSharedTooltipOnTapEnabled: false)
                .frame(height: 300))
        }
    }

    func testColumnSwiftUIUsesLatestCallback() throws {
        try checkCallback(renderer: ColumnChartRenderer.self) { enabled, callback in
            AnyView(ColumnChart(model: self.model, playsAnimationOnAppear: false,
                                onHit: enabled ? { _, _ in callback() } : nil, isSharedTooltipOnTapEnabled: false)
                .frame(height: 300))
        }
    }

    func testBarSwiftUIUsesLatestCallback() throws {
        try checkCallback(renderer: BarChartRenderer.self) { enabled, callback in
            AnyView(BarChart(model: self.model, playsAnimationOnAppear: false,
                             onHit: enabled ? { _, _ in callback() } : nil, isSharedTooltipOnTapEnabled: false)
                .frame(height: 300))
        }
    }

    private func data(count: Int = 100, value: Double = 50) -> CartesianChartModel {
        CartesianChartModel(series: [CartesianSeriesElement(name: "a", data: Array(repeating: value, count: count))],
                            yAxis: CartesianAxisModel(kind: .value, min: 0, max: 100))
    }

    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ renderer: R.Type,
                                                                      model: CartesianChartModel? = nil) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        view.configure(model: model ?? data(), theme: CartesianChartTheme())
        view.layoutIfNeeded()
        return view
    }

    func testDataAndThemeUpdatesPreserveBothWindows() {
        let view = chart(LineChartRenderer.self)
        let renderer = view.rendererForTesting
        renderer.setXAxisViewport(20...40)
        renderer.setYAxisViewport(30...70)
        view.update(model: data(count: 150, value: 60))
        view.layoutIfNeeded()
        XCTAssertEqual(renderer.xAxisViewport, 20...40)
        XCTAssertEqual(renderer.yAxisViewport, 30...70)
        var theme = CartesianChartTheme()
        theme.lineWidth = 7
        theme.contentInset = UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30)
        view.update(theme: theme)
        view.layoutIfNeeded()
        XCTAssertEqual(renderer.xAxisViewport, 20...40)
        XCTAssertEqual(renderer.yAxisViewport, 30...70)
        XCTAssertEqual(renderer.currentTheme?.lineWidth, 7)
        XCTAssertEqual(renderer.currentModel?.series.first?.data.first, 60)
    }

    func testBarPreservesValueXAndCategoryYWindows() {
        let view = chart(BarChartRenderer.self)
        let renderer = view.rendererForTesting
        renderer.setXAxisViewport(20...70)
        renderer.setYAxisViewport(40...60)
        view.update(model: data(count: 150))
        view.layoutIfNeeded()
        XCTAssertEqual(renderer.xAxisViewport, 20...70)
        XCTAssertEqual(renderer.yAxisViewport, 40...60)
    }

    func testShrinkingDataClampsWindowAndGrowingDoesNotRestoreStaleRange() {
        let view = chart(ColumnChartRenderer.self)
        let renderer = view.rendererForTesting
        renderer.setXAxisViewport(80...90)
        view.update(model: data(count: 40))
        view.layoutIfNeeded()
        XCTAssertEqual(renderer.xAxisViewport, 29.5...39.5)
        view.update(model: data(count: 150))
        view.layoutIfNeeded()
        // 新数据域下默认最小跨度由 10 变为 12，但不得恢复原来 80...90 的旧窗口。
        XCTAssertEqual(renderer.xAxisViewport, 29.5...41.5)
    }

    func testFullViewContinuesToFollowAllData() {
        let view = chart(LineChartRenderer.self)
        let renderer = view.rendererForTesting
        renderer.setXAxisViewport(renderer.fullXAxisDomain)
        view.update(model: data(count: 150))
        view.layoutIfNeeded()
        XCTAssertEqual(renderer.xAxisViewport, -0.5...149.5)
        XCTAssertEqual(renderer.xAxisZoomScale, 1)
    }

    func testEmptyDataClearsOldWindowBeforeRepopulation() {
        let view = chart(ColumnChartRenderer.self)
        let renderer = view.rendererForTesting
        renderer.setXAxisViewport(20...40)
        view.update(model: CartesianChartModel(series: []))
        view.layoutIfNeeded()
        XCTAssertEqual(renderer.xAxisViewport, renderer.fullXAxisDomain)
        view.update(model: data(count: 150))
        view.layoutIfNeeded()
        XCTAssertEqual(renderer.xAxisViewport, -0.5...149.5)
    }

    func testDualAxisWindowsPreserveClampAndClearWhenRemoved() throws {
        var model = data()
        model.series.append(CartesianSeriesElement(name: "b", data: Array(repeating: 500, count: 100), yAxisIndex: 1))
        model.secondaryYAxis = CartesianAxisModel(kind: .value, min: 0, max: 1000)
        let view = chart(LineChartRenderer.self, model: model)
        let r = view.rendererForTesting
        r.zoomYAxis(factor: 2, anchorScreenY: r.currentPlotFrame.midY)
        XCTAssertEqual(r.yAxisViewport, 25...75)
        XCTAssertEqual(r.currentSecondaryYDomain, 250...750)
        view.update(theme: CartesianChartTheme(lineWidth: 5))
        view.layoutIfNeeded()
        XCTAssertEqual(r.yAxisViewport, 25...75)
        XCTAssertEqual(r.currentSecondaryYDomain, 250...750)
        model.secondaryYAxis = CartesianAxisModel(kind: .value, min: 0, max: 600)
        view.update(model: model)
        view.layoutIfNeeded()
        XCTAssertEqual(r.currentSecondaryYDomain, 100...600)
        model.secondaryYAxis = nil
        view.update(model: model)
        view.layoutIfNeeded()
        XCTAssertNil(r.currentSecondaryYDomain)
        model.secondaryYAxis = CartesianAxisModel(kind: .value, min: 0, max: 1000)
        view.update(model: model)
        view.layoutIfNeeded()
        XCTAssertEqual(r.currentSecondaryYDomain, 0...1000)
    }

    func testExplicitResetAndLegacyConfigureStillShowFullData() {
        let view = chart(LineChartRenderer.self)
        let r = view.rendererForTesting
        r.setXAxisViewport(20...40)
        r.setYAxisViewport(30...70)
        view.resetViewport()
        view.layoutIfNeeded()
        XCTAssertEqual(r.xAxisViewport, r.fullXAxisDomain)
        XCTAssertEqual(r.yAxisViewport, r.fullYAxisDomain)
        r.setXAxisViewport(20...40)
        view.configure(model: data(count: 50), theme: CartesianChartTheme())
        view.layoutIfNeeded()
        XCTAssertEqual(r.xAxisViewport, -0.5...49.5)
        r.setXAxisViewport(20...40)
        view.update(model: data(count: 100), viewportPolicy: .reset)
        view.layoutIfNeeded()
        XCTAssertEqual(r.xAxisViewport, -0.5...99.5)
    }

    func testDataUpdateClearsStaleTooltipAndHitsNewDataImmediately() {
        let view = chart(LineChartRenderer.self)
        view.showsTooltipOnHit = true
        view.tooltipTheme.showsAnimation = false
        view.isSharedTooltipOnTapEnabled = false
        let point = CGPoint(x: 195, y: 150)
        view.performTap(at: point)
        XCTAssertTrue(view.isCrosshairVisibleForTesting)
        XCTAssertTrue(view.subviews.contains { $0 is HYMChartTooltip && !$0.isHidden })
        view.update(model: data(value: 75))
        XCTAssertFalse(view.isCrosshairVisibleForTesting)
        XCTAssertFalse(view.subviews.contains { $0 is HYMChartTooltip && !$0.isHidden })
        var hit: Double?
        view.onHit = { target, _ in hit = (target as? LineHitTarget)?.value }
        view.performTap(at: point) // 故意不手动 layout，验证事件命中新模型。
        XCTAssertEqual(hit, 75)
    }

    func testExternalLocatedPopupReceivesOneInvalidation() {
        let view = chart(LineChartRenderer.self)
        view.isSharedTooltipOnTapEnabled = false
        var hits: [Bool] = []
        view.onHitLocated = { context, _ in hits.append(context != nil) }
        view.performTap(at: CGPoint(x: 195, y: 150))
        view.update(model: data(value: 70))
        view.update(theme: CartesianChartTheme())
        XCTAssertEqual(hits, [true, false])
    }

    func testUpdateStopsReboundFromWritingOldWindow() {
        let view = chart(LineChartRenderer.self)
        view.isZoomEnabled = true
        view.simulateViewportPan(deltaX: 5000)
        view.update(model: data(count: 30))
        view.layoutIfNeeded()
        let r = view.rendererForTesting
        let before = r.xAxisViewport
        XCTAssertGreaterThanOrEqual(before.lowerBound, r.fullXAxisDomain.lowerBound)
        XCTAssertLessThanOrEqual(before.upperBound, r.fullXAxisDomain.upperBound)
        let done = expectation(description: "旧回弹已取消")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { done.fulfill() }
        wait(for: [done], timeout: 2)
        XCTAssertEqual(r.xAxisViewport, before)
    }

    func testUpdateStopsEntranceAnimationAtCompleteState() {
        let view = chart(ColumnChartRenderer.self)
        view.playEntranceAnimation()
        view.layoutIfNeeded()
        view.update(model: data(value: 75))
        view.layoutIfNeeded()
        XCTAssertTrue(view.rendererForTesting.animatableLayers.allSatisfy { $0.opacity == 1 })
    }

    func testSwiftUIExplicitResetPolicyRestoresFullViewport() throws {
        func content(_ policy: HYMChartViewportUpdatePolicy) -> AnyView {
            AnyView(LineChart(model: data(), playsAnimationOnAppear: false,
                              viewportUpdatePolicy: policy).frame(height: 300))
        }
        let host = UIHostingController(rootView: content(.preserve))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let chart = try XCTUnwrap(findChart(in: host.view, renderer: LineChartRenderer.self))
        chart.rendererForTesting.setXAxisViewport(20...40)
        host.rootView = content(.reset)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(chart === findChart(in: host.view, renderer: LineChartRenderer.self))
        XCTAssertEqual(chart.rendererForTesting.xAxisViewport, -0.5...99.5)
    }
}
