import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class CartesianColorZoneTests: XCTestCase {
    private let samples: [Double] = [-30, 25, 60, 15, -40, -10, 45, .nan, 30]
    private func config(_ axis: CartesianZoneAxis = .y, _ limit: Double = 0,
                        fill: Bool = false) -> CartesianColorZones {
        .init(axis: axis, zones: [
            .init(upperBound: limit, color: .red, areaGradientColors: fill ? [.red] : nil),
            .init(color: .green, areaGradientColors: fill ? [.green] : nil)])
    }
    private func model(_ zones: CartesianColorZones? = nil) -> CartesianChartModel {
        .init(series: [.init(name: "Power", data: samples, color: .blue, negativeColor: .red,
                            id: "power", colorZones: zones)])
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
        _ model: CartesianChartModel, theme: CartesianChartTheme = .init()) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: .init(x: 0, y: 0, width: 600, height: 360))
        view.backgroundColor = .white
        view.configure(model: model, theme: theme); view.layoutIfNeeded()
        return view
    }
    private func layers(_ root: CALayer) -> [CALayer] { [root] + (root.sublayers ?? []).flatMap(layers) }
    private func lines(_ root: CALayer) -> [CAShapeLayer] {
        layers(root).compactMap { $0 as? CAShapeLayer }.filter { $0.fillColor == nil && $0.path != nil }
    }
    private func gradients(_ root: CALayer) -> [CAGradientLayer] { layers(root).compactMap { $0 as? CAGradientLayer } }
    private func image(_ view: UIView) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { view.layer.render(in: $0.cgContext) }
    }
    private func rgb(_ image: UIImage, at point: CGPoint) throws -> [UInt8] {
        let crop = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: floor(point.x), y: floor(point.y), width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return bytes
    }
    private func resolve(_ zones: CartesianColorZones?, negative: UIColor? = .red) throws -> CartesianResolvedColorZones {
        try XCTUnwrap(.init(configuration: zones, negativeColor: negative, baseColor: .blue))
    }

    func testValidationRejectsNonFiniteDuplicateReversedAndOpenMiddleBounds() {
        XCTAssertTrue(config().isValid)
        XCTAssertTrue(CartesianColorZones(zones: [.init(color: .red)]).isValid)
        XCTAssertTrue(CartesianColorZones(zones: [.init(upperBound: -3), .init(upperBound: 3)]).isValid)
        for zones: [CartesianColorZone] in [[], [.init(upperBound: .nan)], [.init(upperBound: .infinity)],
            [.init(upperBound: -.infinity)], [.init(upperBound: 1), .init(upperBound: 1)],
            [.init(upperBound: 2), .init(upperBound: 1)], [.init(), .init(upperBound: 3)]] {
            XCTAssertFalse(CartesianColorZones(zones: zones).isValid)
        }
    }

    func testHalfOpenBoundariesTailInheritanceAndExplicitPrecedence() throws {
        let zones = try resolve(.init(axis: .x, zones: [.init(upperBound: 2.5, color: .green)]))
        XCTAssertEqual(zones.color(x: 2.49, y: -10), .green)
        XCTAssertEqual(zones.color(x: 2.5, y: -10), .blue)
        XCTAssertEqual(zones.color(x: 200, y: -10), .blue)
        let inherit = try resolve(.init(zones: [.init(upperBound: 0), .init(color: .clear)]))
        XCTAssertEqual(inherit.color(x: 0, y: -1), .blue)
        XCTAssertEqual(inherit.color(x: 0, y: 0), .clear)
    }

    func testInvalidConfigurationFallsBackToNegativeColorWithoutChangingData() throws {
        let invalid = CartesianColorZones(zones: [.init(upperBound: .nan, color: .green)])
        let zones = try resolve(invalid)
        XCTAssertEqual(zones.color(x: 0, y: -1), .red)
        XCTAssertEqual(zones.color(x: 0, y: 0), .blue)
        XCTAssertNil(CartesianResolvedColorZones(configuration: invalid, negativeColor: nil, baseColor: .blue))
        let plain = chart(LineChartRenderer.self, model())
        let fallback = chart(LineChartRenderer.self, model(invalid))
        XCTAssertEqual(image(plain).pngData(), image(fallback).pngData())
    }

    func testXClipsUseOriginalFractionalIndicesAndVisibleIntersection() throws {
        let zones = try resolve(config(.x, 3.5))
        let plot = CGRect(x: 40, y: 30, width: 400, height: 200)
        let viewport = CartesianViewport(xMin: 1.5, xMax: 5.5, yMin: -1, yMax: 1)
        let regions = zones.regions(viewport: viewport, yDomain: nil, plot: plot)
        XCTAssertEqual(regions.map(\.clip), [CGRect(x: 40, y: 30, width: 200, height: 200),
                                             CGRect(x: 240, y: 30, width: 200, height: 200)])
        for threshold in [-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude] {
            let outside = try resolve(config(.x, threshold)).regions(viewport: viewport, yDomain: nil, plot: plot)
            XCTAssertEqual(outside.count, 1); XCTAssertEqual(outside.first?.clip, plot)
        }
    }

    func testYClipsUseSecondaryAxisAndDoNotChangeAtXPan() throws {
        let zones = try resolve(config(.y, 50))
        let plot = CGRect(x: 40, y: 30, width: 400, height: 200)
        let viewport = CartesianViewport(xMin: 0, xMax: 10, yMin: -1, yMax: 1)
        let regions = zones.regions(viewport: viewport, yDomain: 0...200, plot: plot)
        XCTAssertEqual(regions.map(\.clip), [CGRect(x: 40, y: 180, width: 400, height: 50),
                                             CGRect(x: 40, y: 30, width: 400, height: 150)])
        let panned = CartesianViewport(xMin: 10, xMax: 20, yMin: -1, yMax: 1)
        XCTAssertEqual(zones.regions(viewport: panned, yDomain: 0...200, plot: plot).map(\.clip), regions.map(\.clip))
        XCTAssertTrue(zones.regions(viewport: viewport, yDomain: nil, plot: .zero).isEmpty)
    }

    func testEveryConnectionKeepsExactOriginalPathAndDashWithZones() throws {
        for connection in LineConnectionStyle.allCases {
            var theme = CartesianChartTheme(); theme.showsPoints = false
            theme.lineConnectionStyle = connection; theme.lineDashStyle = .dash
            var source = model(); source.series[0].negativeColor = nil
            let plain = chart(LineChartRenderer.self, source, theme: theme)
            source.series[0].colorZones = config(.x, 3.5)
            let colored = chart(LineChartRenderer.self, source, theme: theme)
            let original = try XCTUnwrap(lines(plain.rendererForTesting.seriesLayer).first?.path)
            let copies = lines(colored.rendererForTesting.seriesLayer)
            XCTAssertEqual(copies.count, 2)
            for copy in copies {
                XCTAssertEqual(copy.path, original)
                XCTAssertEqual(copy.lineDashPattern, theme.lineDashStyle.dashPattern)
                XCTAssertTrue(copy.superlayer?.masksToBounds == true)
            }
            colored.rendererForTesting.updateSeriesAnimation(progress: 0.4)
            XCTAssertTrue(copies.allSatisfy { abs($0.strokeEnd - 0.4) < 0.001 })
        }
    }

    func testSmoothNegativeColorUsesUnmodifiedCubicAndActuallyPaintsRed() throws {
        var theme = CartesianChartTheme(); theme.lineConnectionStyle = .smooth
        theme.showsPoints = false; theme.lineWidth = 6
        let view = chart(LineChartRenderer.self, model(), theme: theme)
        let renderer = view.rendererForTesting, copies = lines(renderer.seriesLayer)
        XCTAssertEqual(copies.count, 2)
        XCTAssertEqual(copies.map(\.strokeColor), [UIColor.red.cgColor, UIColor.blue.cgColor])
        XCTAssertEqual(copies[0].path, copies[1].path)
        var curves = 0
        copies[0].path?.applyWithBlock { if $0.pointee.type == .addCurveToPoint { curves += 1 } }
        XCTAssertGreaterThan(curves, 0)
        let screenshot = image(view)
        // 避开值域极值处的 plot 裁剪边缘，读取曲线内部的真实负值采样位置。
        let red = try rgb(screenshot, at: renderer.testScreenPoint(series: 0, index: 5))
        let blue = try rgb(screenshot, at: renderer.testScreenPoint(series: 0, index: 2))
        XCTAssertGreaterThan(Int(red[0]), Int(red[2]) + 100)
        XCTAssertGreaterThan(Int(blue[2]), Int(blue[0]) + 100)
    }

    func testFractionalXAndYCrossingsHaveCorrectVisibleColors() throws {
        for axis in [CartesianZoneAxis.x, .y] {
            var source = model(config(axis, axis == .x ? 1.5 : 20))
            source.series[0].data = axis == .x ? [20, 20, 20, 20] : [5, 15, 25, 35]
            var theme = CartesianChartTheme(); theme.showsPoints = false; theme.lineWidth = 6
            let view = chart(LineChartRenderer.self, source, theme: theme), renderer = view.rendererForTesting
            let screenshot = image(view)
            let low = renderer.screenPoint(x: 1.4, y: axis == .x ? 20 : 19)
            let high = renderer.screenPoint(x: 1.6, y: axis == .x ? 20 : 21)
            let red = try rgb(screenshot, at: low), green = try rgb(screenshot, at: high)
            XCTAssertGreaterThan(Int(red[0]), Int(red[1]) + 100)
            XCTAssertGreaterThan(Int(green[1]), Int(green[0]) + 100)
            XCTAssertEqual(renderer.renderedIndices[0], [[0, 1, 2, 3]])
            XCTAssertEqual(renderer.currentModel?.series[0].data.count, 4)
        }
    }

    func testAllNegativeAreaIsNotLostAndLegacyGradientIsNotRecolored() throws {
        var source = model(); source.series[0].data = [-20, -40, -10]
        var theme = CartesianChartTheme(); theme.showsArea = true; theme.lineConnectionStyle = .smooth
        theme.areaGradientColors = [.cyan, .clear]
        let view = chart(LineChartRenderer.self, source, theme: theme)
        let fills = gradients(view.rendererForTesting.seriesLayer)
        XCTAssertEqual(fills.count, 1)
        XCTAssertEqual(fills[0].colors as? [CGColor], [UIColor.cyan.cgColor, UIColor.clear.cgColor])
        XCTAssertFalse(try XCTUnwrap((fills[0].mask as? CAShapeLayer)?.path).isEmpty)
    }

    func testAreaRegionsShareMaskAndGlobalGradientCoordinatesWithOpacity() throws {
        var source = model(config(.x, 3.5, fill: true)); source.series[0].style.fillOpacity = 0.4
        var theme = CartesianChartTheme(); theme.showsArea = true; theme.lineConnectionStyle = .smooth
        let view = chart(LineChartRenderer.self, source, theme: theme), renderer = view.rendererForTesting
        let fills = gradients(renderer.seriesLayer)
        XCTAssertEqual(fills.count, 2)
        XCTAssertEqual((fills[0].mask as? CAShapeLayer)?.path, (fills[1].mask as? CAShapeLayer)?.path)
        for fill in fills {
            XCTAssertEqual(fill.frame, renderer.currentPlotFrame)
            XCTAssertEqual(fill.bounds.origin, renderer.currentPlotFrame.origin)
            XCTAssertEqual(fill.startPoint, CGPoint(x: 0.5, y: 0))
            XCTAssertEqual(fill.endPoint, CGPoint(x: 0.5, y: 1))
            for color in try XCTUnwrap(fill.colors as? [CGColor]) { XCTAssertEqual(color.alpha, 0.4, accuracy: 0.001) }
        }
        let screenshot = image(view)
        let red = try rgb(screenshot, at: renderer.screenPoint(x: 2, y: 30))
        let green = try rgb(screenshot, at: renderer.screenPoint(x: 4, y: -20))
        XCTAssertGreaterThan(red[0], red[1]); XCTAssertGreaterThan(green[1], green[0])
    }

    func testZoneFillNilInheritsAndEmptyRestoresZoneDefaultGradient() {
        var source = model(.init(axis: .x, zones: [.init(upperBound: 3.5, color: .red, areaGradientColors: []),
                                                 .init(color: .green)]))
        source.series[0].style.areaGradientColors = [.purple]
        var theme = CartesianChartTheme(); theme.showsArea = true
        let view = chart(LineChartRenderer.self, source, theme: theme)
        let fills = gradients(view.rendererForTesting.seriesLayer)
        XCTAssertEqual(fills.count, 2)
        XCTAssertEqual(fills[0].colors as? [CGColor], [UIColor.red.withAlphaComponent(0.35).cgColor, UIColor.red.withAlphaComponent(0.04).cgColor])
        XCTAssertEqual(fills[1].colors as? [CGColor], [UIColor.purple.cgColor, UIColor.purple.cgColor])
    }

    func testMarkersUseBoundaryZoneUnlessPointColorIsExplicit() {
        var source = model(config(.x, 1)); source.series[0].data = [-1, -2, -3]
        var theme = CartesianChartTheme(); theme.showsPoints = true
        let view = chart(LineChartRenderer.self, source, theme: theme)
        func markerColors() -> [CGColor?] {
            (view.rendererForTesting.seriesLayer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }.map(\.fillColor)
        }
        XCTAssertEqual(markerColors(), [UIColor.red.cgColor, UIColor.green.cgColor, UIColor.green.cgColor])
        theme.pointColor = .magenta; view.update(theme: theme); view.layoutIfNeeded()
        XCTAssertEqual(markerColors(), Array(repeating: UIColor.magenta.cgColor, count: 3))
    }

    func testZonesDoNotFillMissingDataOrChangeHitDomainAndGapPolicy() {
        var source = model(config(.x, 3.5, fill: true))
        source.series[0].data = [10, .nan, .nan, 40, .nan, .nan, .nan, 20]
        source.series[0].gapPolicy = .autoGap(maximumMissingPoints: 2)
        var theme = CartesianChartTheme(); theme.showsArea = true
        let view = chart(LineChartRenderer.self, source, theme: theme), renderer = view.rendererForTesting
        XCTAssertEqual(renderer.renderedIndices[0], [[0, 3], [7]])
        let domain = renderer.currentViewport.yDomain
        XCTAssertNil(renderer.datum(series: 0, category: 1))
        XCTAssertNil(renderer.seriesHitTest(renderer.screenPoint(x: 1, y: 20)))
        source.series[0].colorZones = nil; view.update(model: source); view.layoutIfNeeded()
        XCTAssertEqual(renderer.currentViewport.yDomain, domain)
        XCTAssertEqual(renderer.renderedIndices[0], [[0, 3], [7]])
        XCTAssertEqual(renderer.currentModel?.series[0].data.count, 8)
    }

    func testSamplingAndViewportKeepOriginalXThresholdAndOriginalHits() throws {
        var source = model(config(.x, 1200.5))
        source.series[0].data = (0..<3000).map { 50 + sin(Double($0) / 10) * 30 }
        var theme = CartesianChartTheme(); theme.lineSampling = .init(); theme.showsPoints = false
        let view = chart(LineChartRenderer.self, source, theme: theme), renderer = view.rendererForTesting
        XCTAssertTrue(renderer.denseSeries.contains(0))
        view.showCategoryRange(1000..<1500); view.layoutIfNeeded()
        let boundary = renderer.screenPoint(x: 1200.5, y: 0).x
        let copies = lines(renderer.seriesLayer)
        XCTAssertEqual(copies.count, 2)
        XCTAssertEqual(try XCTUnwrap(copies[0].superlayer).frame.maxX, boundary, accuracy: 0.001)
        XCTAssertEqual(renderer.datum(series: 0, category: 1200)?.rawValue, source.series[0].data[1200])
        let range = renderer.currentViewport.xDomain
        source.series[0].colorZones = config(.x, 1250.5)
        view.update(model: source); view.layoutIfNeeded()
        XCTAssertEqual(renderer.currentViewport.xDomain, range)
    }

    func testStackAndPercentUseDrawValueButKeepRawDatum() throws {
        for stack in [StackConfig.normal, .percent, .percentFixed(max: 100)] {
            var source = model(config(.y, 30, fill: true)); source.series[0].data = [10, 20, 30]
            source.series.insert(.init(name: "Base", data: [40, 40, 40], id: "base"), at: 0)
            source.stacking = stack
            var theme = CartesianChartTheme(); theme.showsArea = true; theme.lineConnectionStyle = .smooth
            let view = chart(LineChartRenderer.self, source, theme: theme), renderer = view.rendererForTesting
            let datum = try XCTUnwrap(renderer.datum(series: 1, category: 0))
            XCTAssertEqual(datum.rawValue, 10)
            XCTAssertGreaterThan(datum.drawValue, 30)
            let marker = renderer.seriesLayer.sublayers?.compactMap { $0 as? CAShapeLayer }.first { layer in
                layer.fillColor == UIColor.green.cgColor
            }
            XCTAssertNotNil(marker)
        }
    }

    func testCombinedSecondaryAxisUsesItsDomainAndColumnsIgnoreZones() throws {
        var source = model(config(.y, 150, fill: true))
        source.series[0].data = [100, 200, 300]; source.series[0].kind = .areaspline
        source.series[0].yAxisIndex = 1
        source.secondaryYAxis = .init(kind: .value, min: 0, max: 400)
        source.series.insert(.init(name: "Bars", data: [1, 2, 3], color: .purple,
                                  id: "bars", kind: .column, colorZones: config(.x, 1)), at: 0)
        let view = chart(CombinedChartRenderer.self, source), renderer = view.rendererForTesting
        let copies = lines(renderer.lines.seriesLayer)
        let boundary = renderer.screenPoint(x: 0, y: 150, yAxisIndex: 1).y
        XCTAssertEqual(try XCTUnwrap(copies.first?.superlayer).frame.minY, boundary, accuracy: 0.001)
        let before = image(view).pngData()
        source.series[0].colorZones = nil; view.update(model: source); view.layoutIfNeeded()
        XCTAssertEqual(image(view).pngData(), before)
        view.setSeriesVisible(false, for: "power"); view.layoutIfNeeded()
        XCTAssertTrue(renderer.lines.seriesLayer.sublayers?.isEmpty ?? true)
        view.setSeriesVisible(true, for: "power"); view.layoutIfNeeded()
        XCTAssertEqual(lines(renderer.lines.seriesLayer).count, 2)
    }

    func testReuseMatchesFreshAfterAxisFillCountVisibilityAndEmptyTransitions() {
        var source = model(config(.x, 3.5, fill: true))
        var theme = CartesianChartTheme(); theme.showsArea = true; theme.lineConnectionStyle = .smooth
        let reused = chart(LineChartRenderer.self, source, theme: theme)
        theme.reusesRenderingObjects = false
        let fresh = chart(LineChartRenderer.self, source, theme: theme)
        for step in 0..<8 {
            switch step {
            case 1: source.series[0].colorZones = config(.y, 20, fill: true)
            case 2: source.series[0].colorZones = .init(axis: .x, zones: [.init(upperBound: 2, color: .purple),
                .init(upperBound: 4, color: .cyan), .init(upperBound: 6, color: .yellow)])
            case 3: source.series[0].colorZones = nil
            case 4: source.series[0].negativeColor = nil; theme.showsArea = false
            case 5: source.series[0].data = []
            case 6: source = model(config(.x, 3.5, fill: true)); theme.showsArea = true
            case 7: source.series[0].isVisible = false
            default: break
            }
            theme.reusesRenderingObjects = true; reused.update(model: source, theme: theme); reused.layoutIfNeeded()
            theme.reusesRenderingObjects = false; fresh.update(model: source, theme: theme); fresh.layoutIfNeeded()
            XCTAssertEqual(image(reused).pngData(), image(fresh).pngData(), "transition \(step)")
        }
        XCTAssertEqual(reused.rendererForTesting.seriesObjects.retainedCount, 0)
    }

    func testRepeatedZonesReuseContainersWithoutGrowth() {
        var theme = CartesianChartTheme(); theme.showsArea = true
        let view = chart(LineChartRenderer.self, model(config(.x, 3.5, fill: true)), theme: theme)
        let renderer = view.rendererForTesting
        let count = renderer.seriesObjects.retainedCount
        let first = renderer.seriesLayer.sublayers?.first
        for _ in 0..<20 {
            view.update(theme: theme); view.layoutIfNeeded()
            XCTAssertEqual(renderer.seriesObjects.createdCount, 0)
            XCTAssertEqual(renderer.seriesObjects.retainedCount, count)
            XCTAssertTrue(first === renderer.seriesLayer.sublayers?.first)
        }
    }

    func testObjectiveCZonesAreValueSnapshotsAndResetToLegacy() throws {
        let low = HYMCartesianColorZone(); low.upperBound = 0; low.color = .red; low.areaGradientColors = [.red]
        let high = HYMCartesianColorZone(); high.color = .green
        let zones = HYMCartesianColorZones(); zones.zones = [low, high]
        XCTAssertTrue(zones.isValid)
        let series = HYMCartesianSeries(); series.data = [-10, 20, NSNull(), 30]; series.colorZones = zones
        let source = HYMCartesianModel(); source.series = [series]
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: CGRect(x: 0, y: 0, width: 600, height: 360))
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        let renderer = try XCTUnwrap((bridge.chartView as? HYMChartView<LineChartRenderer>)?.rendererForTesting)
        low.upperBound = 1; zones.axis = .x; low.areaGradientColors = [.blue]
        XCTAssertEqual(renderer.currentModel?.series[0].colorZones?.axis, .y)
        XCTAssertEqual(renderer.currentModel?.series[0].colorZones?.zones[0].upperBound, 0)
        XCTAssertEqual(renderer.currentModel?.series[0].colorZones?.zones[0].areaGradientColors, [.red])
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        XCTAssertEqual(renderer.currentModel?.series[0].colorZones?.axis, .x)
        XCTAssertTrue(renderer.currentModel!.series[0].data[2].isNaN)
        series.colorZones = nil; try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        XCTAssertNil(renderer.currentModel?.series[0].colorZones)
    }

    func testDemoBindingsCoverThresholdColorsFillAndOff() throws {
        var settings = DemoSeriesSettings(name: "Zones")
        let binding = Binding(get: { settings }, set: { settings = $0 })
        for kind in [CartesianDemoKind.line, .combined] {
            let items = DemoSeriesSettings.items(binding, kind: kind)
            guard case .picker(_, let mode, _) = items.first(where: { $0.label == "颜色分区 zones" }) else { return XCTFail() }
            mode.wrappedValue = "X 原始索引"
            let updated = DemoSeriesSettings.items(binding, kind: kind)
            guard case .slider(_, let limit, _, _) = updated.first(where: { $0.label == "分区阈值（等于归上段）" }) else { return XCTFail() }
            limit.wrappedValue = 3.5
            XCTAssertEqual(settings.colorZones?.axis, .x); XCTAssertEqual(settings.colorZones?.zones[0].upperBound, 3.5)
            guard case .toggle(_, let fill) = updated.first(where: { $0.label == "分区面积渐变" }) else { return XCTFail() }
            fill.wrappedValue = true; XCTAssertNotNil(settings.colorZones?.zones[0].areaGradientColors)
            mode.wrappedValue = "Y 绘制值"; XCTAssertEqual(settings.colorZones?.axis, .y)
            mode.wrappedValue = "关闭"; XCTAssertNil(settings.colorZones)
        }
        for kind in [CartesianDemoKind.column, .bar] {
            XCTAssertFalse(DemoSeriesSettings.items(binding, kind: kind).contains { $0.label == "颜色分区 zones" })
        }
    }
}
