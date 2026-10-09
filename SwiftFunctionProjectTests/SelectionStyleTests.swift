import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class SelectionStyleTests: XCTestCase {
    private func model() -> CartesianChartModel {
        .init(series: [.init(name: "A", data: [10, 20, 15, 25], color: .blue, id: "a", kind: .column),
                       .init(name: "B", data: [5, 8, .nan, 3], color: .red, id: "b", kind: .line)],
              xAxis: .init(kind: .category(labels: ["A", "B", "C", "D"])),
              yAxis: .init(kind: .value, min: 0, max: 40), stacking: .normal)
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
        _ m: CartesianChartModel, enabled: Bool = true) -> HYMChartView<R> {
        let v = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 500, height: 320))
        var theme = CartesianChartTheme(); theme.selection.isEnabled = enabled
        v.configure(model: m, theme: theme); v.layoutIfNeeded(); return v
    }
    private func target(_ r: CartesianRendererBase<CartesianChartTheme>, _ series: Int = 0, _ category: Int = 1) throws -> HYMChartHitTarget {
        try XCTUnwrap(r.makeHitTarget(seriesIndex: series, categoryIndex: category, value: r.currentDrawValues[series][category]))
    }
    private func image(_ v: UIView, scale: CGFloat = 1) -> Data? {
        let f = UIGraphicsImageRendererFormat(); f.scale = scale
        return UIGraphicsImageRenderer(bounds: v.bounds, format: f).image { v.layer.render(in: $0.cgContext) }.pngData()
    }
    func testDisabledByDefaultAndSelectionNeverMutatesOriginalColorsOrData() throws {
        let v = chart(ColumnChartRenderer.self, model(), enabled: false), r = v.rendererForTesting
        let hit = try target(r), original = image(v), data = r.currentDrawValues
        r.applySelection(hit); XCTAssertNil(r.selectionLayer.superlayer); XCTAssertEqual(image(v), original)
        var theme = try XCTUnwrap(r.currentTheme); theme.selection.isEnabled = true
        v.update(model: model(), theme: theme); v.layoutIfNeeded()
        let unselected = image(v); let shapes = r.seriesLayer.sublayers?.compactMap { ($0 as? CAShapeLayer)?.fillColor }
        r.applySelection(hit)
        XCTAssertEqual(r.selectionShapes.count, 1); XCTAssertNotEqual(image(v), unselected)
        XCTAssertEqual(r.currentDrawValues.map { $0.map { $0.isNaN ? 0 : $0 } }, data.map { $0.map { $0.isNaN ? 0 : $0 } })
        XCTAssertEqual(r.seriesLayer.sublayers?.compactMap { ($0 as? CAShapeLayer)?.fillColor }, shapes)
        r.applySelection(nil); XCTAssertEqual(image(v), unselected); XCTAssertTrue(r.selectionShapes.isEmpty)
    }
    func testSingleLineColumnBarAndCombinedUseRealMarkFrames() throws {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            let v = chart(type, model()), r = v.rendererForTesting
            for s in 0..<2 {
                let hit = try target(r, s), frame = try XCTUnwrap(r.hitFrame(for: hit))
                r.applySelection(hit)
                let shape = try XCTUnwrap(r.selectionShapes.first), path = try XCTUnwrap(shape.path)
                XCTAssertEqual(shape.name, "chart.selection.\(s == 0 ? "a" : "b"):1")
                if hit is LineHitTarget {
                    XCTAssertEqual(path.boundingBox.midX, frame.midX, accuracy: 0.001)
                    XCTAssertEqual(path.boundingBox.midY, frame.midY, accuracy: 0.001)
                    XCTAssertEqual(path.boundingBox.width, 14, accuracy: 0.001)
                } else {
                    XCTAssertEqual(path.boundingBox, frame.intersection(r.currentPlotFrame).insetBy(dx: 1, dy: 1))
                }
                XCTAssertEqual(r.selectionLayer.frame, r.currentPlotFrame)
                XCTAssertTrue(r.selectionLayer.masksToBounds)
            }
        }
        try check(LineChartRenderer.self); try check(ColumnChartRenderer.self)
        try check(BarChartRenderer.self); try check(CombinedChartRenderer.self)
    }
    func testSharedHighlightsOnlyFiniteVisibleEntriesAndClearsMissingColumn() throws {
        let v = chart(CombinedChartRenderer.self, model()), r = v.rendererForTesting
        let hit = try target(r), rect = try XCTUnwrap(r.hitFrame(for: hit))
        let shared = try XCTUnwrap(r.sharedHit(at: CGPoint(x: rect.midX, y: r.currentPlotFrame.midY)))
        r.applySelection(shared.target); XCTAssertEqual(r.selectionKeys.map(\.seriesID), ["a", "b"])
        XCTAssertEqual(Set(r.selectionKeys.map(\.kind)), ["column", "line"])
        let missing = try target(r, 0, 2), second = try XCTUnwrap(r.hitFrame(for: missing))
        r.applySelection(try XCTUnwrap(r.sharedHit(at: CGPoint(x: second.midX, y: r.currentPlotFrame.midY))).target)
        XCTAssertEqual(r.selectionKeys.map(\.seriesID), ["a"]); XCTAssertEqual(r.selectionShapes.count, 1)
        v.setSeriesVisible(false, for: "a"); v.layoutIfNeeded()
        XCTAssertNil(r.selectionLayer.superlayer); XCTAssertTrue(r.selectionKeys.isEmpty)
    }
    func testActualTapIgnoresTooltipAndCrosshairSwitchesThenUpdateAndMissClear() throws {
        let v = chart(ColumnChartRenderer.self, model()), r = v.rendererForTesting
        v.showsTooltipOnHit = false; v.isCrosshairEnabled = false; v.isSharedTooltipOnTapEnabled = true
        let hit = try target(r), rect = try XCTUnwrap(r.hitFrame(for: hit))
        v.performTap(at: CGPoint(x: rect.midX, y: rect.midY))
        XCTAssertEqual(r.selectionShapes.count, 2); XCTAssertFalse(v.isCrosshairVisibleForTesting)
        v.performTap(at: CGPoint(x: -100, y: -100)); XCTAssertTrue(r.selectionShapes.isEmpty)
        v.performTap(at: CGPoint(x: rect.midX, y: rect.midY)); XCTAssertFalse(r.selectionShapes.isEmpty)
        v.update(model: model()); XCTAssertTrue(r.selectionShapes.isEmpty)
        v.layoutIfNeeded(); XCTAssertNil(r.selectionLayer.superlayer)
    }
    func testStableIDAndFamilyValidationRejectsStaleOrForeignTargets() throws {
        var m = model(); let v = chart(CombinedChartRenderer.self, m), r = v.rendererForTesting
        let old = try target(r); r.applySelection(old)
        m.series[0].id = "replacement"; v.update(model: m); v.layoutIfNeeded(); r.applySelection(old)
        XCTAssertTrue(r.selectionKeys.isEmpty)
        r.applySelection(LineHitTarget(seriesIndex: 0, index: 1, value: 20, label: nil, seriesID: "replacement"))
        XCTAssertTrue(r.selectionKeys.isEmpty)
        r.applySelection(ColumnHitTarget(seriesIndex: -1, categoryIndex: Int.max, value: .nan))
        XCTAssertTrue(r.selectionKeys.isEmpty)
        r.applySelection(try target(r)); XCTAssertEqual(r.selectionKeys.first?.seriesID, "replacement")
        m.series[0].kind = .line; v.update(model: m); v.layoutIfNeeded(); r.applySelection(old)
        XCTAssertTrue(r.selectionKeys.isEmpty)
    }
    func testLayoutAnimationAndViewportKeepSelectionAlignedOrClear() throws {
        let v = chart(ColumnChartRenderer.self, model()), r = v.rendererForTesting
        let hit = try target(r); r.applySelection(hit)
        let old = try XCTUnwrap(r.selectionShapes.first?.path?.boundingBox)
        v.bounds.size.width = 700; v.setNeedsLayout(); v.layoutIfNeeded()
        XCTAssertNotEqual(r.selectionShapes.first?.path?.boundingBox, old)
        r.updateEntranceAnimation(progress: 0.4)
        XCTAssertEqual(r.selectionShapes.first?.path?.boundingBox,
            try XCTUnwrap(r.hitFrame(for: hit)).intersection(r.currentPlotFrame).insetBy(dx: 1, dy: 1))
        r.updateEntranceAnimation(progress: 1)
        v.isZoomEnabled = true; v.showCategoryRange(0..<2); v.layoutIfNeeded()
        r.applySelection(try target(r)); XCTAssertFalse(r.selectionKeys.isEmpty)
        v.simulateViewportPan(deltaX: -50); XCTAssertTrue(r.selectionKeys.isEmpty)
        r.applySelection(nil); r.unmount(from: v); XCTAssertNil(r.selectionLayer.superlayer)
    }
    func testReplayClearsSelectionImmediatelyAcrossAllCartesianFamilies() throws {
        func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            let v = chart(type, model()), r = v.rendererForTesting
            r.applySelection(try target(r)); XCTAssertFalse(r.selectionKeys.isEmpty)
            v.playEntranceAnimation()
            XCTAssertTrue(r.selectionKeys.isEmpty)
            XCTAssertTrue(r.selectionShapes.isEmpty)
            XCTAssertNil(r.selectionLayer.superlayer)
            // 取消待播放动画，确保此测试不启动 display link。
            v.update(model: model()); v.layoutIfNeeded()
            XCTAssertTrue(r.selectionKeys.isEmpty)
        }
        try check(LineChartRenderer.self); try check(ColumnChartRenderer.self)
        try check(BarChartRenderer.self); try check(CombinedChartRenderer.self)
    }
    func testSamplingAndSecondaryAxisUseOriginalPointAndMarkerRadius() throws {
        var m = model(); m.series[0].data = (0..<500).map { Double($0 % 80 + 1) }
        m.series[0].kind = .line; m.series[0].yAxisIndex = 1
        m.series[0].style.pointRadius = 12; m.secondaryYAxis = .init(kind: .value, min: 0, max: 100)
        m.stacking = StackConfig.none
        let v = chart(LineChartRenderer.self, m), r = v.rendererForTesting
        var t = try XCTUnwrap(r.currentTheme); t.lineSampling = .init(); t.lineSampling?.targetPointCount = 20
        v.update(model: m, theme: t); v.layoutIfNeeded()
        let hit = try target(r, 0, 213); r.applySelection(hit)
        let box = try XCTUnwrap(r.selectionShapes.first?.path?.boundingBox)
        XCTAssertEqual(box.width, 24, accuracy: 0.001)
        XCTAssertEqual(box.midY, r.testScreenPoint(series: 0, index: 213).y, accuracy: 0.001)
        XCTAssertEqual(r.datum(series: 0, category: 213)?.rawValue, 54)
    }
    func testRepeatedSelectionHasBoundedLayersAndRestoresIdenticalPixelsAtAllScales() throws {
        let v = chart(CombinedChartRenderer.self, model()), r = v.rendererForTesting
        let before = [1, 2, 3].map { image(v, scale: CGFloat($0)) }
        for i in 0..<100 {
            r.applySelection(try target(r, i % 2, 1))
            XCTAssertEqual(r.selectionShapes.count, 1)
            XCTAssertEqual(r.rootLayer.sublayers?.filter { $0.name == "chart.selection" }.count, 1)
        }
        r.applySelection(nil)
        XCTAssertEqual([1, 2, 3].map { image(v, scale: CGFloat($0)) }, before)
        var t = try XCTUnwrap(r.currentTheme)
        t.selection.lineWidth = .nan; t.selection.fillOpacity = .infinity; t.selection.pointRadius = .nan
        v.update(model: model(), theme: t); v.layoutIfNeeded(); r.applySelection(try target(r, 1))
        XCTAssertEqual(r.selectionShapes.first?.lineWidth, 2)
        XCTAssertEqual(r.selectionShapes.first?.path?.boundingBox.width, 14)
        t.selection.isEnabled = false; v.update(model: model(), theme: t); v.layoutIfNeeded()
        XCTAssertNil(r.selectionLayer.superlayer)
    }
    func testObjectiveCAndSamePageDemoExposeDefaultCompatibleSelection() throws {
        let oc = HYMCartesianSelectionStyle(); XCTAssertFalse(oc.isEnabled)
        oc.isEnabled = true; oc.color = .purple; oc.lineWidth = 4; oc.pointRadius = 11; oc.fillOpacity = 0.3
        XCTAssertEqual(oc.build().pointRadius, 11)
        let m = HYMCartesianModel(), s = HYMCartesianSeries(); s.identifier = "a"; s.data = [10, 20]
        m.series = [s]; let bridge = HYMCartesianChartViewBridge(kind: .line, frame: CGRect(x: 0, y: 0, width: 500, height: 320))
        bridge.selectionStyle = oc; try bridge.configure(model: m); bridge.chartView.layoutIfNeeded()
        let v = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        let r = v.rendererForTesting; r.applySelection(try target(r))
        XCTAssertEqual(r.selectionShapes.first?.lineWidth, 4)
        XCTAssertEqual(r.selectionShapes.first?.strokeColor, UIColor.purple.cgColor)
        for kind in CartesianDemoKind.allCases {
            var state = CartesianDemoState(kind: kind); state.bodySelectionPreset()
            XCTAssertTrue(state.builtTheme.selection.isEnabled); XCTAssertTrue(state.interaction.shared)
            let items = CartesianDemoControls.sections(Binding(get: { state }, set: { state = $0 })).flatMap(\.items).map(\.control)
            guard case .toggle(_, let binding) = try XCTUnwrap(items.first { $0.label == "selection 主体选中高亮" }) else { return XCTFail() }
            binding.wrappedValue = false; XCTAssertFalse(state.builtTheme.selection.isEnabled)
        }
    }
}
