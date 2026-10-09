import XCTest
import UIKit
@testable import SwiftFunctionProject

@MainActor final class StackedAreaStrokeTests: XCTestCase {
    private let size = CGSize(width: 640, height: 360)
    private func model(_ connection: LineConnectionStyle = .straight) -> CartesianChartModel {
        .init(series: [[40.0, 40, 40], [-30, -30, -30], [10, -10, 10]].enumerated().map { i, data in
            var style = CartesianSeriesStyle()
            style.lineConnectionStyle = connection; style.showsArea = true
            style.areaGradientColors = [[UIColor.blue], [.orange], [.green]][i]
            return .init(name: "S\(i)", data: data, color: [.blue, .orange, .green][i],
                         id: "s\(i)", kind: .area, style: style)
        }, stacking: .normal)
    }
    private func theme() -> CartesianChartTheme {
        var t = CartesianChartTheme()
        t.stackedAreaBoundaryMode = .followBaseline; t.showsPoints = false
        return t
    }
    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
        _ model: CartesianChartModel, _ theme: CartesianChartTheme) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: CGRect(origin: .zero, size: size))
        view.configure(model: model, theme: theme); view.layoutIfNeeded()
        return view
    }
    private func image(_ layer: CALayer, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { layer.render(in: $0.cgContext) }
    }
    private func rgba(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return bytes
    }
    private func layers(_ root: CALayer) -> [CALayer] { [root] + (root.sublayers ?? []).flatMap(layers) }
    private func strokes(_ root: CALayer) -> [CAShapeLayer] {
        layers(root).compactMap { $0 as? CAShapeLayer }.filter { $0.path != nil && $0.fillColor == nil }
    }

    func testActualPixelsHaveNoGreenTipsInsideBasesOrColoredCapsOutsideEndpoints() throws {
        let view = chart(LineChartRenderer.self, model(), theme()), r = view.rendererForTesting
        let attachment = XCTAttachment(image: image(view.layer, scale: 3))
        attachment.name = "crossing-stroke-boundaries"; attachment.lifetime = .keepAlways; add(attachment)
        func violations(scale: CGFloat) throws -> (green: Int, ends: Int) {
            // Measure the same full-view composite as the user screenshot, including its coordinate system.
            let pixels = try rgba(image(view.layer, scale: scale)), width = Int(size.width * scale)
            let left = r.screenPoint(x: 0, y: 0).x * scale, right = r.screenPoint(x: 2, y: 0).x * scale
            let positive = r.screenPoint(x: 0, y: 40).y * scale
            let negative = r.screenPoint(x: 0, y: -30).y * scale
            var greenInBase = 0, outsideEnds = 0
            for y in 0..<Int(size.height * scale) {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    // Entire physical pixel is inside the two base bands / outside the endpoint plane.
                    // Pixels straddling the mathematical boundary may legitimately be antialiased.
                    if CGFloat(x) >= left, CGFloat(x + 1) <= right,
                       CGFloat(y) >= positive, CGFloat(y + 1) <= negative,
                       Int(pixels[offset + 1]) > Int(max(pixels[offset], pixels[offset + 2])) + 16 {
                        greenInBase += 1
                    }
                    if CGFloat(x + 1) <= left || CGFloat(x) >= right {
                        let rgb = Array(pixels[offset..<(offset + 3)])
                        if Int(rgb.max()!) - Int(rgb.min()!) > 32 { outsideEnds += 1 }
                    }
                }
            }
            return (greenInBase, outsideEnds)
        }
        for scale: CGFloat in [1, 2, 3] {
            let result = try violations(scale: scale)
            XCTAssertEqual(result.green, 0, "\(scale)x: green stroke leaks into blue/orange")
            XCTAssertEqual(result.ends, 0, "\(scale)x: stroke protrudes beyond left/right area ends")
        }
        // Positive control: on exactly the same geometry, reproduce the former centered stroke.
        // These checks ensure the raster assertions can actually detect both reported defects.
        for line in strokes(r.seriesLayer) { line.mask = nil; line.lineWidth = theme().lineWidth }
        let old = try violations(scale: 3)
        XCTAssertGreaterThan(old.green, 0); XCTAssertGreaterThan(old.ends, 0)
        let centered = XCTAttachment(image: image(view.layer, scale: 3))
        centered.name = "crossing-centered-stroke-control"; centered.lifetime = .keepAlways; add(centered)
    }

    func testStrokePixelsStayWithinFillForEveryConnectionWidthAndScale() throws {
        for mode: StackedAreaBoundaryMode in [.followBaseline, .diverging] {
            for connection in LineConnectionStyle.allCases {
                for lineWidth: CGFloat in [2, 8] {
                    var t = theme(); t.lineWidth = lineWidth; t.stackedAreaBoundaryMode = mode
                    let view = chart(LineChartRenderer.self, model(connection), t), r = view.rendererForTesting
                    let lines = strokes(r.seriesLayer)
                    let areas = layers(r.seriesLayer).compactMap { $0 as? CAGradientLayer }
                    XCTAssertEqual(lines.count, 3); XCTAssertEqual(areas.count, 3)
                    for (line, area) in zip(lines, areas) {
                        let path = try XCTUnwrap((area.mask as? CAShapeLayer)?.path)
                        // The fill plus one physical pixel of fringe defines the antialias allowance.
                        // Compare actual raster output, not just whether two CGPaths are equal.
                        for scale: CGFloat in [1, 2, 3] {
                            let allowed = CAShapeLayer(); allowed.path = path
                            allowed.fillColor = UIColor.black.cgColor; allowed.strokeColor = UIColor.black.cgColor
                            allowed.lineWidth = 2 / scale
                            let coverage = try rgba(image(allowed, scale: scale))
                            let rendered = try rgba(image(line, scale: scale))
                            var painted = 0, leaked = 0
                            for alpha in stride(from: 3, to: rendered.count, by: 4) where rendered[alpha] > 16 {
                                painted += 1
                                if coverage[alpha] == 0 { leaked += 1 }
                            }
                            XCTAssertGreaterThan(painted, 0, "Stroke must not disappear")
                            XCTAssertEqual(leaked, 0, "\(mode) \(connection) width=\(lineWidth) scale=\(scale)")
                        }
                    }
                }
            }
        }
    }

    func testClippingKeepsConfiguredInsideWidthAndZeroAreaHasNoStroke() throws {
        var t = theme(); t.lineWidth = 8
        var m = model(); m.series = Array(m.series.prefix(1))
        let view = chart(LineChartRenderer.self, m, t), r = view.rendererForTesting
        let line = try XCTUnwrap(strokes(r.seriesLayer).first)
        let pixels = try rgba(image(line, scale: 3)), width = Int(size.width * 3)
        let top = r.screenPoint(x: 1, y: 40)
        func alpha(_ dy: CGFloat) -> UInt8 {
            pixels[(Int((top.y + dy) * 3) * width + Int(top.x * 3)) * 4 + 3]
        }
        XCTAssertEqual(alpha(-2), 0); XCTAssertGreaterThan(alpha(6), 240); XCTAssertEqual(alpha(10), 0)
        m.series[0].data = [0, 0, 0]; view.update(model: m); view.layoutIfNeeded()
        let zero = try rgba(image(try XCTUnwrap(strokes(r.seriesLayer).first), scale: 3))
        XCTAssertTrue(stride(from: 3, to: zero.count, by: 4).allSatisfy { zero[$0] == 0 })
        // Real markers and hits remain available for zero-area / isolated samples.
        m.series[0].data = [.nan, 0, .nan]; t.showsPoints = true
        view.update(model: m, theme: t); view.layoutIfNeeded()
        XCTAssertNotNil(r.seriesHitTest(r.testScreenPoint(series: 0, index: 1)))
        XCTAssertTrue(layers(r.seriesLayer).compactMap { $0 as? CAShapeLayer }.contains {
            $0.fillColor == UIColor.blue.cgColor && $0.mask == nil
        })
    }

    func testReuseModeChangesZonesAndAnimationMatchFreshRendering() throws {
        var m = model(.smooth), t = theme()
        let reused = chart(LineChartRenderer.self, m, t)
        for step in 0..<9 {
            switch step {
            case 1:
                m.series[2].colorZones = .init(axis: .x, zones: [
                    .init(upperBound: 1, color: .purple, areaGradientColors: [.purple]), .init(color: .green)])
                m.series[2].lineDashStyle = .dash
            case 2: m.series[0].isVisible = false; m.series[2].data = [10, .nan, -10]
            case 3: t.stackedAreaBoundaryMode = .independent
            case 4:
                t.stackedAreaBoundaryMode = .followBaseline; m = model(.stepBefore)
                m.stacking = .percent
            case 5:
                m.stacking = .normal; m.series[2].style.showsArea = false
                t.showsPoints = true; t.pointHoleRadius = 1
            case 6: m = .init(series: [])
            case 7: m = model(.stepCenter)
            default: break
            }
            t.reusesRenderingObjects = true
            reused.update(model: m, theme: t); reused.layoutIfNeeded()
            t.reusesRenderingObjects = false
            let fresh = chart(LineChartRenderer.self, m, t)
            if step == 8 {
                reused.showCategoryRange(0..<2); fresh.showCategoryRange(0..<2)
                reused.layoutIfNeeded(); fresh.layoutIfNeeded()
            }
            for progress in [0.35, 1.0] {
                reused.rendererForTesting.updateSeriesAnimation(progress: progress)
                fresh.rendererForTesting.updateSeriesAnimation(progress: progress)
                XCTAssertEqual(image(reused.layer, scale: 2).pngData(), image(fresh.layer, scale: 2).pngData(),
                               "step=\(step) animation=\(progress)")
            }
            if step == 3 {
                XCTAssertTrue(strokes(reused.rendererForTesting.seriesLayer).allSatisfy { $0.mask == nil })
            } else if step == 4 {
                // G1 now supports auto-percent stacked areas; their strokes must remain clipped.
                XCTAssertEqual(strokes(reused.rendererForTesting.seriesLayer).filter { $0.mask != nil }.count, 3)
            }
        }
    }

    func testLineCombinedAndOCUseSameStrokeContainment() throws {
        let m = model(), t = theme()
        let line = chart(LineChartRenderer.self, m, t), combined = chart(CombinedChartRenderer.self, m, t)
        let expected = strokes(line.rendererForTesting.rootLayer).compactMap { ($0.mask as? CAShapeLayer)?.path }
        let actual = strokes(combined.rendererForTesting.rootLayer).compactMap { ($0.mask as? CAShapeLayer)?.path }
        XCTAssertEqual(expected.count, 3); XCTAssertEqual(expected, actual)
        XCTAssertEqual(image(line.layer, scale: 3).pngData(), image(combined.layer, scale: 3).pngData())
        let source = HYMCartesianModel(); source.stacking = .normal
        source.series = m.series.map { s in
            let result = HYMCartesianSeries(); result.name = s.name; result.kind = .area
            result.data = s.data.map(NSNumber.init(value:)); return result
        }
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: line.bounds)
        bridge.stackedAreaFollowsBaseline = true
        try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        let view = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        XCTAssertEqual(strokes(view.rendererForTesting.seriesLayer).compactMap { $0.mask }.count, 3)
        bridge.stackedAreaFollowsBaseline = false
        try bridge.update(model: source, preserveViewport: true); view.layoutIfNeeded()
        XCTAssertTrue(strokes(view.rendererForTesting.seriesLayer).allSatisfy { $0.mask == nil })
    }
}
