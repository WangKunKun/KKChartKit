import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class ColumnColorZoneTests: XCTestCase {
    private func zones(_ source: CartesianColumnZoneValueSource = .rawValue) -> CartesianColorZones {
        .init(zones: [.init(upperBound: -50, color: .red), .init(upperBound: 0, color: .orange),
                      .init(upperBound: 50, color: .blue), .init(color: .green)], columnValueSource: source)
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
        _ model: CartesianChartModel, theme: CartesianChartTheme = .init()) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 600, height: 360))
        view.backgroundColor = .white
        view.configure(model: model, theme: theme); view.layoutIfNeeded()
        return view
    }
    private func layer(_ renderer: CartesianRendererBase<CartesianChartTheme>) -> CALayer {
        (renderer as? CombinedChartRenderer)?.columns.seriesLayer ?? renderer.seriesLayer
    }
    private func rect(_ renderer: CartesianRendererBase<CartesianChartTheme>, _ series: Int, _ index: Int) throws -> CGRect {
        let hit = try XCTUnwrap(renderer.makeHitTarget(seriesIndex: series, categoryIndex: index,
                                                      value: renderer.currentDrawValues[series][index]))
        return try XCTUnwrap(renderer.hitFrame(for: hit))
    }
    private func color(_ renderer: CartesianRendererBase<CartesianChartTheme>, _ series: Int, _ index: Int,
                       fraction: CGFloat = 0.5) throws -> UIColor {
        let frame = try rect(renderer, series, index)
        let point = renderer.isHorizontalValueAxis
            ? CGPoint(x: frame.minX + frame.width * fraction, y: frame.midY)
            : CGPoint(x: frame.midX, y: frame.minY + frame.height * fraction)
        let shape = try XCTUnwrap(layer(renderer).sublayers?.compactMap { $0 as? CAShapeLayer }.reversed().first {
            $0.fillColor != nil && $0.path?.contains(point) == true
        })
        return UIColor(cgColor: try XCTUnwrap(shape.fillColor))
    }
    private func image(_ view: UIView, scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = scale
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { view.layer.render(in: $0.cgContext) }
    }
    private func stacked(_ source: CartesianColumnZoneValueSource = .rawValue) -> CartesianChartModel {
        .init(series: [
            .init(name: "Base", data: [40, -40], color: .purple, id: "base", kind: .column),
            .init(name: "Segment", data: [20, -20], color: .cyan, id: "segment", kind: .column, colorZones: zones(source))
        ], stacking: .normal)
    }

    func testResolverHalfOpenThresholdsZeroAndTailInheritance() {
        var series = CartesianSeriesElement(name: "A", data: [], color: .purple, negativeColor: .black,
                                           barColors: [.yellow], colorZones: zones())
        let resolved = CartesianColumnColors(series: series, defaultColor: .cyan)
        for (value, expected): (Double, UIColor) in [(-51, .red), (-50, .orange), (-1, .orange),
                                                    (0, .blue), (49, .blue), (50, .green), (51, .green)] {
            XCTAssertEqual(resolved.color(categoryIndex: 0, sourceIndex: 0, rawValue: value, drawValue: 100), expected)
        }
        series.colorZones = .init(zones: [.init(upperBound: 0), .init(upperBound: 10, color: .clear)])
        let inherited = CartesianColumnColors(series: series, defaultColor: .cyan)
        XCTAssertEqual(inherited.color(categoryIndex: 0, sourceIndex: 0, rawValue: -1, drawValue: -1), .purple)
        XCTAssertEqual(inherited.color(categoryIndex: 0, sourceIndex: 0, rawValue: 0, drawValue: 0), .clear)
        XCTAssertEqual(inherited.color(categoryIndex: 0, sourceIndex: 0, rawValue: 10, drawValue: 10), .purple)
    }

    func testInvalidAndAbsentZonesPreserveNegativePaletteAndThemePrecedence() {
        for configuration: CartesianColorZones? in [nil, .init(zones: []), .init(zones: [.init(upperBound: .nan)]),
            .init(zones: [.init(upperBound: 1), .init(upperBound: 1)]), .init(zones: [.init(), .init(upperBound: 1)])] {
            var series = CartesianSeriesElement(name: "A", data: [], color: .blue, negativeColor: .red,
                                               barColors: [.orange, .green], colorZones: configuration)
            var colors = CartesianColumnColors(series: series, defaultColor: .purple)
            XCTAssertEqual(colors.color(categoryIndex: 1, sourceIndex: 20, rawValue: -2, drawValue: -2), .red)
            XCTAssertEqual(colors.color(categoryIndex: 1, sourceIndex: 20, rawValue: 2, drawValue: 2), .green)
            series.negativeColor = .blue
            colors = CartesianColumnColors(series: series, defaultColor: .purple)
            XCTAssertEqual(colors.color(categoryIndex: 0, sourceIndex: 20, rawValue: -2, drawValue: -2), .orange)
            series.barColors = []; series.color = nil; series.negativeColor = nil
            colors = CartesianColumnColors(series: series, defaultColor: .purple)
            XCTAssertEqual(colors.color(categoryIndex: 0, sourceIndex: 20, rawValue: -2, drawValue: -2), .purple)
        }
    }

    func testWholeSegmentsThresholdsMissingAndHitDataAcrossThreeRenderers() throws {
        let values: [Double] = [-51, -50, -49, 49, 50, 51, .nan, .infinity]
        let model = CartesianChartModel(series: [.init(name: "A", data: values, color: .purple,
            negativeColor: .black, barColors: [.yellow], id: "a", kind: .column, colorZones: zones())])
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            let view = chart(type, model), r = view.rendererForTesting
            for (index, expected) in [UIColor.red, .orange, .orange, .blue, .green, .green].enumerated() {
                for fraction: CGFloat in [0.2, 0.5, 0.8] { XCTAssertEqual(try color(r, 0, index, fraction: fraction), expected) }
                let frame = try rect(r, 0, index)
                let hit = try XCTUnwrap(r.seriesHitTest(CGPoint(x: frame.midX, y: frame.midY)) as? CartesianHitDataSource)
                XCTAssertEqual(hit.chartData.first?.rawValue, values[index])
                XCTAssertEqual(hit.chartData.first?.sourceRange, index..<(index + 1))
            }
            XCTAssertNil(r.datum(series: 0, category: 6)); XCTAssertNil(r.datum(series: 0, category: 7))
            XCTAssertEqual(layer(r).sublayers?.count, 4)
        }
        try verify(ColumnChartRenderer.self); try verify(BarChartRenderer.self); try verify(CombinedChartRenderer.self)
    }

    func testRawAndDrawValueForNormalGroupedPercentAndFixedStacks() throws {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            for stacking in [StackConfig.normal, .grouped(groupCount: 1), .percent, .percentFixed(max: 100)] {
                var model = stacked(); model.stacking = stacking
                let view = chart(type, model), r = view.rendererForTesting
                XCTAssertEqual(try color(r, 1, 0), .blue); XCTAssertEqual(try color(r, 1, 1), .orange)
                let before = try XCTUnwrap(r.datum(series: 1, category: 0))
                model.series[1].colorZones?.columnValueSource = .drawValue
                view.update(model: model); view.layoutIfNeeded()
                XCTAssertEqual(try color(r, 1, 0), .green); XCTAssertEqual(try color(r, 1, 1), .red)
                let after = try XCTUnwrap(r.datum(series: 1, category: 0))
                XCTAssertEqual(after.rawValue, 20); XCTAssertEqual(after.drawValue, before.drawValue)
                XCTAssertEqual(after.stackBase, before.stackBase); XCTAssertEqual(after.percentage, before.percentage)
            }
        }
        try verify(ColumnChartRenderer.self); try verify(BarChartRenderer.self); try verify(CombinedChartRenderer.self)
    }

    func testRawColorStaysStableWhileDrawColorFollowsVisibilityAndStackMembership() throws {
        for source in [CartesianColumnZoneValueSource.rawValue, .drawValue] {
            var model = stacked(source)
            let view = chart(ColumnChartRenderer.self, model), r = view.rendererForTesting
            XCTAssertEqual(try color(r, 1, 0), source == .rawValue ? .blue : .green)
            view.setSeriesVisible(false, for: "base"); view.layoutIfNeeded()
            XCTAssertEqual(try color(r, 1, 0), .blue)
            view.setSeriesVisible(true, for: "base"); view.layoutIfNeeded()
            XCTAssertEqual(try color(r, 1, 0), source == .rawValue ? .blue : .green)
            model.series[1].participatesInStack = false
            view.update(model: model); view.layoutIfNeeded()
            XCTAssertEqual(try color(r, 1, 0), .blue)
            XCTAssertEqual(r.datum(series: 1, category: 0)?.stackBase, 0)
        }
    }

    func testSecondaryAxisUsesValuesNotScreenCoordinatesAndDoesNotAffectLineZones() throws {
        var model = stacked(.drawValue)
        for i in model.series.indices { model.series[i].yAxisIndex = 1 }
        model.secondaryYAxis = .init(kind: .value, min: -200, max: 200)
        model.series.append(.init(name: "Line", data: [1, 2], color: .black, id: "line", kind: .line,
                                  colorZones: .init(zones: [.init(upperBound: 1.5, color: .orange)])))
        let view = chart(CombinedChartRenderer.self, model), r = view.rendererForTesting
        XCTAssertEqual(try color(r, 1, 0), .green); XCTAssertEqual(try color(r, 1, 1), .red)
        XCTAssertEqual(r.datum(series: 1, category: 0)?.yAxisIndex, 1)
        let lineImage = image(view).pngData()
        model.series[2].colorZones?.columnValueSource = .drawValue
        view.update(model: model); view.layoutIfNeeded()
        XCTAssertEqual(image(view).pngData(), lineImage)
        let columns = chart(ColumnChartRenderer.self, model)
        XCTAssertEqual(try color(columns.rendererForTesting, 1, 0), .green)
    }

    func testXZonesKeepOriginalIndicesWhenPanningAndIgnoreYSource() throws {
        let configuration = CartesianColorZones(axis: .x, zones: [.init(upperBound: 10.5, color: .red), .init(color: .green)])
        let model = CartesianChartModel(series: [.init(name: "A", data: Array(repeating: -20, count: 30),
                                                       id: "a", kind: .column, colorZones: configuration)])
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
            let view = chart(type, model), r = view.rendererForTesting
            r.showCategoryRange(8..<15)
            XCTAssertEqual(try color(r, 0, 10), .red); XCTAssertEqual(try color(r, 0, 11), .green)
            var changed = model; changed.series[0].colorZones?.columnValueSource = .drawValue
            view.update(model: changed); view.layoutIfNeeded()
            XCTAssertEqual(try color(r, 0, 10), .red); XCTAssertEqual(try color(r, 0, 11), .green)
        }
        try verify(ColumnChartRenderer.self); try verify(BarChartRenderer.self); try verify(CombinedChartRenderer.self)
    }

    func testTimeAggregationColorsByBucketValueAndOriginalBucketStartIndex() throws {
        var model = CartesianChartModel(series: [.init(name: "Sum", data: Array(repeating: 10, count: 60),
            id: "sum", aggregation: .sum, colorZones: zones())],
            timeAxis: .init(start: Date(timeIntervalSince1970: 0), interval: 300), timeGrouping: .init())
        model.timeGrouping?.minimumColumnWidth = 70
        let view = chart(ColumnChartRenderer.self, model), r = view.rendererForTesting
        let secondIndex = try XCTUnwrap(r.currentModel).timeBucketStride
        let datum = try XCTUnwrap(r.datum(series: 0, category: secondIndex))
        XCTAssertNil(datum.rawValue); XCTAssertGreaterThan(datum.sourceRange.lowerBound, 1)
        XCTAssertEqual(try color(r, 0, secondIndex), datum.displayValue < 50 ? .blue : .green)
        model.series[0].colorZones = .init(axis: .x, zones: [.init(upperBound: 1.5, color: .red), .init(color: .green)])
        view.update(model: model); view.layoutIfNeeded()
        XCTAssertEqual(try color(r, 0, 0), .red); XCTAssertEqual(try color(r, 0, secondIndex), .green)
        XCTAssertEqual(r.datum(series: 0, category: secondIndex)?.sourceRange, datum.sourceRange)
    }

    func testAnimationUsesFinalColorAndAreaGradientsDoNotChangeColumns() throws {
        var model = stacked(.drawValue)
        let view = chart(ColumnChartRenderer.self, model), r = view.rendererForTesting
        let original = image(view).pngData()
        model.series[1].colorZones?.zones[3].areaGradientColors = [.yellow, .black]
        view.update(model: model); view.layoutIfNeeded()
        XCTAssertEqual(image(view).pngData(), original)
        r.updateSeriesAnimation(progress: 0.25)
        let colors = layer(r).sublayers?.compactMap { ($0 as? CAShapeLayer)?.fillColor }.map(UIColor.init(cgColor:)) ?? []
        XCTAssertTrue(colors.contains(.green)); XCTAssertTrue(colors.contains(.red)); XCTAssertFalse(colors.contains(.blue))
        r.updateSeriesAnimation(progress: 1)
        XCTAssertEqual(image(view).pngData(), original)
    }

    func testReuseMatchesFreshAfterZoneSourcePaletteEmptyAndVisibilityChanges() {
        func verify<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) {
            var model = stacked()
            var theme = CartesianChartTheme(); theme.columnCornerRadius = 4
            let reused = chart(type, model, theme: theme)
            for step in 0..<9 {
                switch step {
                case 1: model.series[1].colorZones?.columnValueSource = .drawValue
                case 2: model.series[1].colorZones = .init(zones: [.init(upperBound: .nan)])
                case 3: model.series[1].colorZones = nil; model.series[1].barColors = [.orange, .black]
                case 4: model.series[1].isVisible = false
                case 5: model.series[1].isVisible = true; model.series[1].data = []
                case 6: model = stacked(.drawValue); theme.columnBorderColor = .black; theme.columnBorderWidth = 2
                case 7: model.series[1].colorZones = .init(zones: [.init(color: .clear)])
                case 8: model.series = []
                default: break
                }
                theme.reusesRenderingObjects = true
                reused.update(model: model, theme: theme); reused.layoutIfNeeded()
                theme.reusesRenderingObjects = false
                let fresh = chart(type, model, theme: theme)
                for scale: CGFloat in [1, 2, 3] {
                    XCTAssertEqual(image(reused, scale: scale).pngData(), image(fresh, scale: scale).pngData(), "step \(step), scale \(scale)")
                }
            }
            XCTAssertTrue(layer(reused.rendererForTesting).sublayers?.isEmpty ?? true)
        }
        verify(ColumnChartRenderer.self); verify(BarChartRenderer.self); verify(CombinedChartRenderer.self)
    }

    func testCombinedColumnZoneControlsAreEnabledRatherThanMarkedLineOnly() {
        var state = CartesianDemoState(kind: .combined); state.columnColorZonesPreset()
        let controls = CartesianDemoControls.sections(Binding(get: { state }, set: { state = $0 }))
            .flatMap(\.items)
        for label in ["颜色分区 zones", "分区阈值（等于归上段）", "阈值以下柱色", "阈值以上柱色", "柱/条 Y 取色依据"] {
            guard let control = controls.first(where: { $0.label == label }) else { return XCTFail(label) }
            if case .availability(_, let reason, let enabled) = control { XCTAssertTrue(enabled, label + reason) }
        }
    }

    func testObjectiveCValueSourceIsCopiedAndAllColumnKindsConsumeZones() throws {
        let low = HYMCartesianColorZone(); low.upperBound = 50; low.color = .red
        let high = HYMCartesianColorZone(); high.color = .green
        let config = HYMCartesianColorZones(); config.zones = [low, high]
        let base = HYMCartesianSeries(); base.identifier = "base"; base.data = [40]
        let upper = HYMCartesianSeries(); upper.identifier = "upper"; upper.data = [20]; upper.colorZones = config
        let model = HYMCartesianModel(); model.series = [base, upper]; model.stacking = .normal
        for kind in [HYMCartesianChartKind.column, .bar, .combined] {
            config.columnValueSource = .rawValue
            let bridge = HYMCartesianChartViewBridge(kind: kind, frame: CGRect(x: 0, y: 0, width: 600, height: 360))
            try bridge.configure(model: model); bridge.chartView.layoutIfNeeded()
            let r: CartesianRendererBase<CartesianChartTheme>
            switch kind {
            case .column: r = try XCTUnwrap((bridge.chartView as? HYMChartView<ColumnChartRenderer>)?.rendererForTesting)
            case .bar: r = try XCTUnwrap((bridge.chartView as? HYMChartView<BarChartRenderer>)?.rendererForTesting)
            default: r = try XCTUnwrap((bridge.chartView as? HYMChartView<CombinedChartRenderer>)?.rendererForTesting)
            }
            XCTAssertEqual(try color(r, 1, 0), .red)
            config.columnValueSource = .drawValue
            XCTAssertEqual(r.currentModel?.series[1].colorZones?.columnValueSource, .rawValue)
            try bridge.update(model: model, preserveViewport: true); bridge.chartView.layoutIfNeeded()
            XCTAssertEqual(try color(r, 1, 0), .green)
        }
    }

    func testDemoPresetAndBindingsAreIsolatedLiveAndRestorable() throws {
        for kind in [CartesianDemoKind.column, .bar, .combined] {
            var state = CartesianDemoState(kind: kind)
            let binding = Binding(get: { state }, set: { state = $0 })
            func item(_ label: String) throws -> ChartDemoPanel.Item {
                try XCTUnwrap(CartesianDemoControls.sections(binding).flatMap(\.items).first { $0.label == label }, label)
            }
            guard case .button(_, let load) = try item("柱条阈值整段换色场景").control else { return XCTFail() }
            load()
            XCTAssertEqual(state.selectedSeries, 1); XCTAssertEqual(state.model.series[1].colorZones?.columnValueSource, .rawValue)
            guard case .picker(_, let source, _) = try item("柱/条 Y 取色依据").control else { return XCTFail() }
            source.wrappedValue = "累计绘制值"
            XCTAssertEqual(state.model.series[1].colorZones?.columnValueSource, .drawValue)
            XCTAssertNil(state.model.series[0].colorZones)
            guard case .picker(_, let mode, _) = try item("颜色分区 zones").control else { return XCTFail() }
            mode.wrappedValue = "关闭"; XCTAssertNil(state.model.series[1].colorZones)
            mode.wrappedValue = "X 原始索引"; XCTAssertEqual(state.model.series[1].colorZones?.axis, .x)
            mode.wrappedValue = "Y 数值"; XCTAssertEqual(state.model.series[1].colorZones?.axis, .y)
            load(); XCTAssertEqual(state.model.series[1].colorZones?.columnValueSource, .rawValue)
            state.colorZonesPreset(axis: .y)
            XCTAssertEqual(state.model.series[0].colorZones?.columnValueSource, .rawValue)
        }
    }
}
