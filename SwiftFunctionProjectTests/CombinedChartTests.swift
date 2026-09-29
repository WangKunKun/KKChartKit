import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class CombinedChartTests: XCTestCase {
    private func model(count: Int = 3) -> CartesianChartModel {
        .init(series: [
            .init(name: "A1", data: Array(repeating: 60, count: count), color: .blue, id: "a1", kind: .column, stackID: "A"),
            .init(name: "A2", data: Array(repeating: 20, count: count), color: .cyan, id: "a2", kind: .column, stackID: "A"),
            .init(name: "B1", data: Array(repeating: 30, count: count), color: .orange, id: "b1", kind: .column, stackID: "B"),
            .init(name: "B2", data: Array(repeating: 10, count: count), color: .yellow, id: "b2", kind: .column, stackID: "B"),
            .init(name: "Target", data: Array(repeating: 90, count: count), color: .red, yAxisIndex: 1, id: "target", kind: .spline, participatesInStack: false)
        ], secondaryYAxis: .init(kind: .value), stacking: .normal)
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type, _ m: CartesianChartModel, theme: CartesianChartTheme = .init()) -> HYMChartView<R> {
        let v = HYMChartView<R>(frame: .init(x: 0, y: 0, width: 390, height: 340))
        v.configure(model: m, theme: theme); v.layoutIfNeeded(); return v
    }
    private func rect<R: CartesianRendererBase<CartesianChartTheme>>(_ r: R, _ s: Int, _ i: Int = 0) throws -> CGRect {
        let t = try XCTUnwrap(r.makeHitTarget(seriesIndex: s, categoryIndex: i, value: r.currentDrawValues[s][i]))
        return try XCTUnwrap(r.hitFrame(for: t))
    }
    private func layers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(layers) }

    func testIndependentGroupsSignsMissingAndRaggedData() {
        var m = model(); m.series.removeLast()
        m.series[0].data = [60, -60, .nan]; m.series[1].data = [20, -20]
        m.series[2].data = [30, -30, 5]; m.series[3].data = [10, -10, 0]
        XCTAssertEqual(m.stackedDrawValues[1], [80, -80, 0])
        XCTAssertEqual(m.stackedDrawValues[3], [40, -40, 5])
        XCTAssertTrue(m.stackedDrawValues[0][2].isNaN)
        XCTAssertEqual(m.dataBounds()?.max, 80); XCTAssertEqual(m.dataBounds()?.min, -80)
        m.series[1].groupID = "unrelated-business-group"
        XCTAssertEqual(m.stackedDrawValues[1][0], 80)
        m.series[0].isVisible = false
        XCTAssertEqual(m.stackedDrawValues[1][0], 20)
        XCTAssertEqual(m.dataBounds()?.max, 40)
    }
    func testPercentDenominatorsAndUnstackedSeries() throws {
        var m = model(); m.stacking = .percent
        let v = chart(CombinedChartRenderer.self, m); let r = v.rendererForTesting
        XCTAssertEqual(r.datum(series: 1, category: 0)?.percentage, 25)
        XCTAssertEqual(r.datum(series: 3, category: 0)?.percentage, 25)
        XCTAssertEqual(r.datum(series: 4, category: 0)?.drawValue, 90)
        XCTAssertNil(r.datum(series: 4, category: 0)?.percentage)
        XCTAssertEqual(r.datum(series: 4, category: 0)?.stackBase, 0)
        v.setSeriesVisible(false, for: "a1"); v.layoutIfNeeded()
        XCTAssertEqual(r.datum(series: 1, category: 0)?.percentage, 100)
        XCTAssertEqual(r.datum(series: 3, category: 0)?.percentage, 25)
        m.stacking = .percentFixed(max: 200); v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(r.datum(series: 1, category: 0)?.percentage, 10)
        XCTAssertEqual(r.datum(series: 3, category: 0)?.percentage, 5)
    }
    func testAxesAndFamiliesNeverMixStacksWithSameID() {
        var m = model(); m.series[2].stackID = "A"; m.series[2].yAxisIndex = 1
        m.series[4].participatesInStack = true; m.series[4].stackID = "A"
        XCTAssertEqual(m.stackedDrawValues[2][0], 30)
        XCTAssertEqual(m.stackedDrawValues[4][0], 90)
        m.series.append(.init(name: "Area", data: [10], yAxisIndex: 1, kind: .areaspline, stackID: "A"))
        XCTAssertEqual(m.stackedDrawValues[5][0], 100)
    }
    func testGroupedCompatibilityKeepsOriginalPartitionsWhenHidden() {
        var m = model(); m.series.removeLast()
        for i in m.series.indices { m.series[i].stackID = nil }
        m.stacking = .grouped(groupCount: 2)
        XCTAssertEqual(m.stackedDrawValues[2][0], 90)
        XCTAssertEqual(m.stackedDrawValues[3][0], 30)
        XCTAssertEqual(m.columnSlotCount, 2)
        m.series[0].isVisible = false
        XCTAssertEqual(m.stackedDrawValues[2][0], 30)
        XCTAssertEqual(m.stackedDrawValues[3][0], 30)
    }
    func testGroupedFixedGeometryAndBodyHitsInAllColumnRenderers() throws {
        var m = model(count: 60); m.series.removeLast(); m.secondaryYAxis = nil
        let t = CartesianChartTheme(columnSpacing: .init(columnWidth: 12, inner: 4, group: 16))
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            let v = chart(type, m, theme: t); let r = v.rendererForTesting
            let a1 = try rect(r, 0), a2 = try rect(r, 1), b = try rect(r, 2)
            let horizontal = r.isHorizontalValueAxis
            XCTAssertEqual(horizontal ? a1.height : a1.width, 12, accuracy: 0.001)
            XCTAssertEqual(horizontal ? a1.midY : a1.midX, horizontal ? a2.midY : a2.midX, accuracy: 0.001)
            XCTAssertEqual(horizontal ? b.minY - a1.maxY : b.minX - a1.maxX, 4, accuracy: 0.001)
            let hit = try XCTUnwrap(r.seriesHitTest(.init(x: a2.midX, y: a2.midY)) as? CartesianHitDataSource)
            XCTAssertEqual(hit.chartData.first?.seriesID, "a2"); XCTAssertEqual(hit.chartData.first?.rawValue, 20)
            v.setSeriesVisible(false, for: "a1"); v.setSeriesVisible(false, for: "a2"); v.layoutIfNeeded()
            XCTAssertEqual(r.currentModel?.columnSlotCount, 1)
            let remaining = try rect(r, 2)
            XCTAssertEqual(horizontal ? remaining.height : remaining.width, 12, accuracy: 0.001)
        }
        try verify(ColumnChartRenderer.self); try verify(BarChartRenderer.self); try verify(CombinedChartRenderer.self)
    }
    func testMixedRenderingLegendHitsAndAxesUseOneContext() throws {
        var theme = CartesianChartTheme(); theme.legend.isEnabled = true
        let v = chart(CombinedChartRenderer.self, model(), theme: theme); let r = v.rendererForTesting
        XCTAssertEqual(r.legendItems.count, 5); XCTAssertTrue(r.columns.legendItems.isEmpty); XCTAssertTrue(r.lines.legendItems.isEmpty)
        XCTAssertEqual(r.lines.renderedIndices.keys.sorted(), [4])
        XCTAssertEqual(r.currentModel?.columnSlotCount, 2)
        XCTAssertEqual(r.columns.currentPlotFrame, r.lines.currentPlotFrame)
        let p = try rect(r, 4)
        let line = try XCTUnwrap(r.seriesHitTest(.init(x: p.midX, y: p.midY)) as? LineHitTarget)
        XCTAssertEqual(line.seriesID, "target"); XCTAssertEqual(line.rawValue, 90)
        XCTAssertNotNil(r.tooltipAnchor(for: line))
        let shared = try XCTUnwrap(r.sharedHit(at: .init(x: p.midX, y: p.midY))?.target as? CartesianHitDataSource)
        XCTAssertEqual(shared.chartData.map(\.seriesID), ["a1", "a2", "b1", "b2", "target"])
        XCTAssertEqual(shared.chartData[1].stackID, "A"); XCTAssertEqual(shared.chartData[1].stackBase, 60)
        let snap = try XCTUnwrap(r.snapHit(at: .init(x: p.midX, y: p.midY)) as? CartesianHitDataSource)
        XCTAssertEqual(snap.chartData.first?.seriesID, "target")
    }
    func testStyleOverridesGradientMarkersAndResetAreIndependent() throws {
        var first = CartesianSeriesStyle(); first.lineWidth = 7; first.showsPoints = false
        first.fillOpacity = 0.5; first.areaGradientColors = [.red.withAlphaComponent(0.8)]
        let m = CartesianChartModel(series: [
            .init(name: "Area", data: [10, 20, 10], color: .red, id: "area", kind: .areaspline, style: first),
            .init(name: "Line", data: [30, 40, 30], color: .blue, id: "line", kind: .line)
        ])
        var theme = CartesianChartTheme(); theme.lineWidth = 2; theme.showsPoints = true
        let v = chart(CombinedChartRenderer.self, m, theme: theme); let r = v.rendererForTesting
        let shapes = r.lines.seriesLayer.sublayers!.compactMap { $0 as? CAShapeLayer }
        XCTAssertTrue(shapes.contains { $0.lineWidth == 7 }); XCTAssertTrue(shapes.contains { $0.lineWidth == 2 })
        XCTAssertEqual(shapes.filter { $0.fillColor != nil }.count, 3)
        let gradient = try XCTUnwrap(r.lines.seriesLayer.sublayers!.compactMap { $0 as? CAGradientLayer }.first)
        XCTAssertEqual((gradient.colors as? [CGColor])?.first?.alpha ?? 0, 0.4, accuracy: 0.00001)
        XCTAssertEqual((gradient.colors as? [CGColor])?.count, 2)
        var updated = m; updated.series[0].style = .init(); updated.series[0].kind = .line
        v.update(model: updated); v.layoutIfNeeded()
        XCTAssertFalse(r.lines.seriesLayer.sublayers!.contains { $0 is CAGradientLayer })
        XCTAssertEqual(r.lines.seriesLayer.sublayers!.compactMap { $0 as? CAShapeLayer }.filter { $0.fillColor != nil }.count, 6)
    }
    func testSwitchingKindsVisibilityAndEmptyRemovesStalePasses() {
        var m = model(); let v = chart(CombinedChartRenderer.self, m); let r = v.rendererForTesting
        m.series[4].kind = .column; v.update(model: m); v.layoutIfNeeded()
        XCTAssertTrue(r.lines.renderedIndices.isEmpty); XCTAssertTrue(r.lines.seriesLayer.sublayers?.isEmpty ?? true)
        XCTAssertEqual(r.currentModel?.columnSlotCount, 3)
        for row in m.series { v.setSeriesVisible(false, for: row.id) }; v.layoutIfNeeded()
        XCTAssertTrue(r.columns.seriesLayer.sublayers?.isEmpty ?? true)
        XCTAssertNil(r.sharedHit(at: .init(x: r.currentPlotFrame.midX, y: r.currentPlotFrame.midY)))
        m.series = []; v.update(model: m); v.layoutIfNeeded()
        XCTAssertTrue(r.lines.renderedIndices.isEmpty); XCTAssertTrue(r.columns.seriesLayer.sublayers?.isEmpty ?? true)
    }
    func testTotalsArePerGroupAndAnimationDoesNotDuplicate() {
        var theme = CartesianChartTheme(); theme.showsStackTotalLabels = true
        theme.stackTotalLabelFormatter = { "sum:\($0)" }
        let v = chart(CombinedChartRenderer.self, model(count: 1), theme: theme); let r = v.rendererForTesting
        for progress in [0.2, 0.5, 1] {
            r.updateSeriesAnimation(progress: progress)
            let texts = layers(v.layer).compactMap { ($0 as? CATextLayer)?.string as? String }.filter { $0.hasPrefix("sum:") }.sorted()
            XCTAssertEqual(texts, ["sum:40.0", "sum:80.0"])
        }
    }
    func testFixedMixedScrollUsesColumnGroupsAndPreservesOrigin() throws {
        let t = CartesianChartTheme(columnSpacing: .init(columnWidth: 12, inner: 4, group: 16))
        let v = chart(CombinedChartRenderer.self, model(count: 2000), theme: t); let r = v.rendererForTesting
        XCTAssertEqual(r.currentViewport.xMin, -0.5); XCTAssertEqual(r.automaticCategoryScrollAxis, .x)
        XCTAssertEqual(try rect(r, 0).width, 12, accuracy: 0.001)
        v.showCategoryRange(100..<120); v.layoutIfNeeded()
        XCTAssertEqual(r.currentViewport.xMin, 99.5, accuracy: 0.001)
        v.update(theme: t); v.layoutIfNeeded()
        XCTAssertEqual(r.currentViewport.xMin, 99.5, accuracy: 0.001)
        XCTAssertEqual(try rect(r, 0, 100).width, 12, accuracy: 0.001)
    }
    func testGroupedAggregationBudgetsGroupsAndPreservesKeys() {
        var m = model(count: 288); m.series.removeLast()
        for i in m.series.indices { m.series[i].aggregation = .sum }
        m.timeAxis = .init(start: .init(timeIntervalSince1970: 0), interval: 300); m.timeGrouping = .init()
        let grouped = CartesianTimeGrouper.group(model: m, theme: .init(), plotWidth: 200, visibleRange: -0.5...287.5)
        XCTAssertGreaterThan(grouped.samplesPerBucket, 1)
        XCTAssertEqual(grouped.model.series[0].stackID, "A"); XCTAssertEqual(grouped.model.columnSlotCount, 2)
        let width = Double(grouped.samplesPerBucket)
        XCTAssertEqual(grouped.model.stackedDrawValues[1][0], 80 * width)
        XCTAssertEqual(grouped.model.stackedDrawValues[3][0], 40 * width)
    }
    func testOCCombinedCopiesTypesStylesAndStackIDs() throws {
        let m = HYMCartesianModel(); m.stacking = .normal
        let column = HYMCartesianSeries(); column.identifier = "column"; column.data = [60, 80]; column.stackID = "A"
        let line = HYMCartesianSeries(); line.identifier = "line"; line.data = [30, 40]
        line.kind = .areaspline; line.style = .init(); line.style?.fillOpacity = 0.4
        line.style?.showsPoints = false; line.style?.lineWidth = 6; line.marker = .diamond; line.participatesInStack = false
        m.series = [column, line]
        let bridge = HYMCartesianChartViewBridge(kind: .combined, frame: .init(x: 0, y: 0, width: 390, height: 340))
        try bridge.configure(model: m); bridge.chartView.layoutIfNeeded()
        let v = try XCTUnwrap(bridge.chartView as? HYMChartView<CombinedChartRenderer>); let r = v.rendererForTesting
        XCTAssertEqual(r.currentModel?.series[1].style.fillOpacity, 0.4)
        XCTAssertEqual(r.currentModel?.series[1].pointSymbol, .diamond)
        XCTAssertEqual(r.datum(series: 1, category: 0)?.rawValue, 30)
        XCTAssertEqual(HYMCartesianDatum(try XCTUnwrap(r.datum(series: 0, category: 0))).stackID, "A")
    }
    func testSeriesStylePanelWritesAndRestoresActualModelFields() {
        var settings = DemoSeriesSettings(name: "test", color: nil)
        let binding = Binding(get: { settings }, set: { settings = $0 })
        var items = DemoSeriesSettings.items(binding, kind: .combined)
        guard case .picker(_, let kind, _) = items.first(where: { $0.label == "系列图形 kind" }),
              case .toggle(_, let width) = items.first(where: { $0.label == "自定义系列线宽" }) else { return XCTFail() }
        kind.wrappedValue = "areaspline"; width.wrappedValue = true
        XCTAssertEqual(settings.kind, .areaspline); XCTAssertEqual(settings.style.lineWidth, 2)
        items = DemoSeriesSettings.items(binding, kind: .combined)
        guard case .button(_, let action) = items.first(where: { $0.label == "重置当前系列样式覆盖" }) else { return XCTFail() }
        action(); XCTAssertNil(settings.style.lineWidth)
    }
    func testPlainRendererNormalizesMixedKindsToItsOwnFamily() {
        var m = model(); m.series = [m.series[0], m.series[1]]
        m.series[1].kind = .area
        let line = chart(LineChartRenderer.self, m)
        let column = chart(ColumnChartRenderer.self, m)
        XCTAssertEqual(line.rendererForTesting.datum(series: 1, category: 0)?.drawValue, 80)
        XCTAssertEqual(column.rendererForTesting.currentModel?.columnSlotCount, 1)
        let combined = chart(CombinedChartRenderer.self, m)
        XCTAssertEqual(combined.rendererForTesting.datum(series: 1, category: 0)?.drawValue, 20)
    }
    func testStackedAreaUsesLowerSeriesConnectionAndIndependentGroups() throws {
        var style = CartesianSeriesStyle(); style.showsPoints = false
        let m = CartesianChartModel(series: [
            .init(name: "Lower", data: [10, 30, 10], id: "low", kind: .area, stackID: "A", style: style),
            .init(name: "Upper", data: [20, 10, 20], id: "high", kind: .areaspline, stackID: "A", style: style),
            .init(name: "Other", data: [-10, -30, -10], id: "other", kind: .area, stackID: "B", style: style)
        ], stacking: .normal)
        let v = chart(CombinedChartRenderer.self, m); let r = v.rendererForTesting
        let gradients = r.lines.seriesLayer.sublayers!.compactMap { $0 as? CAGradientLayer }
        XCTAssertEqual(gradients.count, 3)
        let mask = try XCTUnwrap((gradients[1].mask as? CAShapeLayer)?.path)
        var curves = 0
        mask.applyWithBlock { if $0.pointee.type == .addCurveToPoint { curves += 1 } }
        XCTAssertEqual(curves, 2, "Upper smooth has two curves; lower straight boundary must not add curves")
        XCTAssertEqual(r.datum(series: 1, category: 1)?.stackBase, 30)
        XCTAssertEqual(r.datum(series: 2, category: 1)?.stackBase, 0)
        XCTAssertEqual(r.datum(series: 2, category: 1)?.drawValue, -30)
    }
    func testGroupSeparatorsStayOnTheirOwnSegmentBoundary() throws {
        var m = model(count: 1); m.series.removeLast(); m.secondaryYAxis = nil
        var t = CartesianChartTheme(columnSpacing: .init(columnWidth: 12, inner: 4, group: 16))
        t.stackSeparatorColor = .magenta
        let v = chart(ColumnChartRenderer.self, m, theme: t); let r = v.rendererForTesting
        let seams = r.seriesLayer.sublayers!.compactMap { $0 as? CAShapeLayer }.filter { $0.strokeColor == UIColor.magenta.cgColor }
        XCTAssertEqual(seams.count, 2)
        for (series, seam) in zip([0, 2], seams) {
            let rectangle = try rect(r, series)
            let bound = try XCTUnwrap(seam.path).boundingBoxOfPath
            XCTAssertEqual(bound.minX, rectangle.minX, accuracy: 0.001)
            XCTAssertEqual(bound.width, rectangle.width, accuracy: 0.001)
            XCTAssertEqual(bound.minY, rectangle.minY, accuracy: 0.001)
        }
    }

    func testTwoPointSmoothReverseEndsAtFirstBaselinePoint() {
        let points = [CGPoint(x: 10, y: 30), CGPoint(x: 20, y: 40)]
        let path = UIBezierPath(); path.move(to: points[1])
        CartesianGeometry.appendSmoothCurveReversed(to: path, points: points)
        XCTAssertEqual(path.currentPoint, points[0])
    }
    func testSmoothStackedAreaConnectsToLastBaselineBeforeReversing() throws {
        let m = CartesianChartModel(series: [
            .init(name: "A", data: [10, 30, 10], kind: .areaspline),
            .init(name: "B", data: [20, 10, 20], kind: .areaspline)
        ], stacking: .normal)
        let v = chart(CombinedChartRenderer.self, m); let r = v.rendererForTesting
        let gradients = r.lines.seriesLayer.sublayers!.compactMap { $0 as? CAGradientLayer }
        let path = try XCTUnwrap((gradients[1].mask as? CAShapeLayer)?.path)
        var lines: [CGPoint] = []
        path.applyWithBlock { if $0.pointee.type == .addLineToPoint { lines.append($0.pointee.points[0]) } }
        let baselineEnd = r.lines.testScreenPoint(series: 0, index: 2)
        XCTAssertTrue(lines.contains { abs($0.x - baselineEnd.x) < 0.001 && abs($0.y - baselineEnd.y) < 0.001 })
    }

}
