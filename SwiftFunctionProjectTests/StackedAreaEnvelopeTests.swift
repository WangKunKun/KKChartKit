import XCTest
import UIKit
@testable import SwiftFunctionProject

@MainActor final class StackedAreaEnvelopeTests: XCTestCase {
    private func chart(_ data: [[Double]], styles: [LineConnectionStyle] = [],
                       stacking: StackConfig = .normal) -> HYMChartView<LineChartRenderer> {
        let colors: [UIColor] = [.blue, .orange, .green, .purple, .cyan]
        let model = CartesianChartModel(series: data.enumerated().map { i, values in
            var style = CartesianSeriesStyle(); style.showsArea = true; style.showsPoints = false
            style.lineConnectionStyle = styles.isEmpty ? .straight : styles[i]
            style.areaGradientColors = [colors[i % colors.count].withAlphaComponent(0.6)]
            return .init(name: "S\(i)", data: values, color: colors[i % colors.count], id: "s\(i)", style: style)
        }, stacking: stacking)
        var theme = CartesianChartTheme(); theme.stackedAreaBoundaryMode = .followBaseline
        let view = HYMChartView<LineChartRenderer>(frame: .init(x: 0, y: 0, width: 640, height: 360))
        view.configure(model: model, theme: theme); view.layoutIfNeeded(); return view
    }
    private func area(_ r: LineChartRenderer, _ series: Int) throws -> CGPath {
        let layers = (r.seriesLayer.sublayers ?? []).compactMap { $0 as? CAGradientLayer }
        let layer = try XCTUnwrap(layers.indices.contains(series) ? layers[series] : nil)
        return try XCTUnwrap((layer.mask as? CAShapeLayer)?.path)
    }
    private func attach(_ view: UIView, _ name: String) {
        let format = UIGraphicsImageRendererFormat(); format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { c in
            UIColor.white.setFill(); c.fill(view.bounds); view.layer.render(in: c.cgContext)
        }
        let attachment = XCTAttachment(image: image); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }

    func testPositiveUpperAreaFollowsCrossingSourceInsteadOfBridgingItsEndpoints() throws {
        let view = chart([[20, 20, 20], [30, -30, 30], [5, 5, 5]])
        let r = view.rendererForTesting, upper = try area(r, 2)
        attach(view, "native-source-switch")
        // At x=.5 the orange layer reaches its own zero; positive baseline is now blue=20.
        XCTAssertTrue(upper.contains(r.screenPoint(x: 0.5, y: 22)))
        XCTAssertFalse(upper.contains(r.screenPoint(x: 0.5, y: 37)))
        XCTAssertTrue(upper.contains(r.screenPoint(x: 0.75, y: 22)))
        XCTAssertFalse(upper.contains(r.screenPoint(x: 0.75, y: 30)))
    }

    func testBothNativeFixturesActuallyReadTheSameLegacyInputFile() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "chart-area-boundaries-v1", withExtension: "json"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        for sample in try XCTUnwrap(object["cases"] as? [[String: Any]]) {
            let input = try XCTUnwrap(sample["series"] as? [[String: Any]])
            let data = try input.map { try XCTUnwrap($0["values"] as? [Double]) }
            let styles: [LineConnectionStyle] = input.map { ($0["kind"] as? String) == "areaspline" ? .smooth : .straight }
            let view = chart(data, styles: styles)
            attach(view, "native-" + (try XCTUnwrap(sample["id"] as? String)))
            let values = view.rendererForTesting.currentDrawValues
            let result: [String: Any] = ["id": sample["id"]!, "raw": data, "draw": values]
            let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
            attachment.name = "native-" + (sample["id"] as! String); attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    private func interpolated(_ data: [Double], style: LineConnectionStyle, x: Double) -> Double {
        let i = Int(x), t = x - Double(i), a = data[i], b = data[i + 1]
        switch style {
        case .straight: return a + (b - a) * t
        case .stepBefore: return b
        case .stepAfter: return a
        case .stepCenter: return t < 0.5 ? a : b
        case .smooth:
            // Independently evaluate raw contribution interpolation, then sum its sign parts.
            // No access to the new envelope cache, stacked contour or area polygon.
            let path = UIBezierPath(); path.move(to: CGPoint(x: 0, y: data[0]))
            CartesianGeometry.appendSmoothCurve(to: path, points: data.enumerated().map { CGPoint(x: Double($0), y: $1) })
            var index = 0, result = a
            path.cgPath.applyWithBlock { p in
                let e = p.pointee
                if e.type == .addCurveToPoint {
                    if index == i {
                        let u = 1 - t
                        result = u*u*u*a + 3*u*u*t*e.points[0].y + 3*u*t*t*e.points[1].y + t*t*t*b
                    }
                    index += 1
                }
            }
            return result
        }
    }

    func testMixedStylesSignsAndStackModesFollowPiecewiseSignSums() throws {
        var combinations = 0
        for lowerStyle in LineConnectionStyle.allCases {
            for upperStyle in LineConnectionStyle.allCases {
                for sign in [1.0, -1.0] {
                    for mode: StackConfig in [.normal, .percentFixed(max: 200), .grouped(groupCount: 1)] {
                        let data = [[20.0, 20, 20, 20].map { $0 * sign }, [30, -30, 20, -10],
                                    [5, 7, 4, 6].map { $0 * sign }, [4, -8, 6, -4]]
                        let styles: [LineConnectionStyle] = [.straight, lowerStyle, upperStyle, upperStyle]
                        let view = chart(data, styles: styles, stacking: mode), r = view.rendererForTesting
                        let paths = try data.indices.map { try area(r, $0) }
                        let factor = mode == .percentFixed(max: 200) ? 0.5 : 1.0
                        for interval in 0..<3 {
                            for fraction in [0.11, 0.29, 0.47, 0.63, 0.89] {
                                let x = Double(interval) + fraction
                                let values = data.indices.map { interpolated(data[$0], style: styles[$0], x: x) * factor }
                                for s in 2...3 where abs(values[s]) > 0.01 {
                                    let baseline = values.prefix(s).filter { ($0 >= 0) == (values[s] >= 0) }.reduce(0, +)
                                    let inside = r.screenPoint(x: x, y: baseline + values[s] / 2)
                                    XCTAssertTrue(paths[s].contains(inside), "Missing thickness: \(lowerStyle), \(upperStyle), \(mode), s=\(s), x=\(x)")
                                    let opposite = r.screenPoint(x: x, y: baseline - (values[s] > 0 ? 0.01 : -0.01))
                                    XCTAssertFalse(paths[s].contains(opposite), "Crossed the resolved sign baseline")
                                    for earlier in 0..<s { XCTAssertFalse(paths[earlier].contains(inside), "Covered a lower layer") }
                                }
                            }
                        }
                        for s in data.indices {
                            for i in data[s].indices {
                                XCTAssertEqual(r.datum(series: s, category: i)?.rawValue, data[s][i])
                                XCTAssertEqual(r.renderedIndices[s], [[0, 1, 2, 3]])
                            }
                        }
                        combinations += 1
                    }
                }
            }
        }
        XCTAssertEqual(combinations, 150)
    }

    func testConnectedUpperGapReusesSourceCrossingsAndBridgesOnlyTheBrokenPart() throws {
        let view = chart([[20, 20, 20, 20, 20], [30, -30, 30, -30, 30], [5, .nan, .nan, .nan, 5]])
        let r = view.rendererForTesting
        var m = r.currentModel!; m.series[2].connectNulls = true
        view.update(model: m); view.layoutIfNeeded()
        let upper = try area(r, 2)
        for x in [0.75, 1.0, 1.25, 2.75, 3.0, 3.25] {
            XCTAssertTrue(upper.contains(r.screenPoint(x: x, y: 22)))
            XCTAssertFalse(upper.contains(r.screenPoint(x: x, y: 52)))
        }
        XCTAssertEqual(r.renderedIndices[2], [[0, 4]])
        XCTAssertTrue(m.series[2].data[1].isNaN)
        m.series[1].data[2] = .nan; m.series[1].data[3] = 30
        view.update(model: m); view.layoutIfNeeded()
        // The broken source uses a positive-base bridge 20...50 only over 1...3.
        XCTAssertTrue(try area(r, 2).contains(r.screenPoint(x: 1.5, y: 30)))
        XCTAssertFalse(try area(r, 1).contains(r.screenPoint(x: 1.5, y: 25)))
        m.series[1].connectNulls = true
        view.update(model: m); view.layoutIfNeeded()
        XCTAssertTrue(try area(r, 2).contains(r.screenPoint(x: 1.5, y: 22)))
    }

    private func image(_ layer: CALayer, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = scale
        return UIGraphicsImageRenderer(size: .init(width: 640, height: 360), format: format).image { layer.render(in: $0.cgContext) }
    }
    private func alpha(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let c = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            c.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
    }

    func testSourceSwitchStrokePixelsStayInsideItsAreaAtAllScales() throws {
        for style in LineConnectionStyle.allCases {
            let v = chart([[20, 20, 20], [30, -30, 30], [5, 5, 5]], styles: [.smooth, style, .smooth])
            let r = v.rendererForTesting
            var t = r.currentTheme!; t.lineWidth = 6; v.update(theme: t); v.layoutIfNeeded()
            let strokes = (r.seriesLayer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }.filter { $0.fillColor == nil }
            for (s, stroke) in strokes.enumerated() {
                let path = try area(r, s)
                for scale: CGFloat in [1, 2, 3] {
                    let allowed = CAShapeLayer(); allowed.path = path
                    allowed.fillColor = UIColor.black.cgColor; allowed.strokeColor = UIColor.black.cgColor
                    allowed.lineWidth = 2 / scale
                    let coverage = try alpha(image(allowed, scale: scale)), actual = try alpha(image(stroke, scale: scale))
                    XCTAssertTrue(actual.contains { $0 > 16 })
                    XCTAssertEqual(zip(coverage, actual).filter { $0 == 0 && $1 > 16 }.count, 0,
                                   "\(style) / \(s) / \(scale)x stroke escapes its area")
                }
            }
        }
    }

    func testUpdatesIsolationAndCompatibilityDoNotKeepOldEnvelopes() throws {
        let original = [[20.0, 20, 20], [30, -30, 30], [5, 5, 5]]
        let v = chart(original), r = v.rendererForTesting
        var m = r.currentModel!, t = r.currentTheme!
        for step in 0..<10 {
            switch step {
            case 1: m.series[1].isVisible = false
            case 2: m.series[1].isVisible = true; m.series[1].data = [-30, 30, -30]
            case 3: m.series[1].stackID = "other"
            case 4: m.series[1].stackID = nil; m.secondaryYAxis = .init(kind: .value); m.series[1].yAxisIndex = 1
            case 5: m.series[1].yAxisIndex = 0; m.stacking = .percent
            case 6: m.stacking = .normal; t.stackedAreaBoundaryMode = .independent
            case 7: m.series = []; t.stackedAreaBoundaryMode = .followBaseline
            case 8: m = chart(original).rendererForTesting.currentModel!
            default: break
            }
            v.update(model: m, theme: t, viewportPolicy: .reset); v.layoutIfNeeded()
            let fresh = chart(original)
            var noReuse = t; noReuse.reusesRenderingObjects = false
            fresh.update(model: m, theme: noReuse, viewportPolicy: .reset); fresh.layoutIfNeeded()
            if step == 9 {
                v.showCategoryRange(0..<2); fresh.showCategoryRange(0..<2)
                let domain = r.currentViewport.xDomain
                m.series[0].data = [25, 25, 25]
                v.update(model: m, viewportPolicy: .preserve); fresh.update(model: m, viewportPolicy: .preserve)
                v.layoutIfNeeded(); fresh.layoutIfNeeded()
                XCTAssertEqual(r.currentViewport.xDomain, domain)
            }
            XCTAssertEqual(image(v.layer, scale: 2).pngData(), image(fresh.layer, scale: 2).pngData(), "update \(step)")
            if step == 1 || step == 3 || step == 4 {
                let target = step == 1 ? 1 : 2
                XCTAssertTrue(try area(r, target).contains(r.screenPoint(x: 1, y: 22)))
            }
        }
    }

    func testDemoAndOCSourceSwitchHaveMatchingBoundariesAndOriginalHitValues() throws {
        var lineState = CartesianDemoState(kind: .line), combinedState = CartesianDemoState(kind: .combined)
        lineState.sourceSwitchStackedAreaPreset(); combinedState.sourceSwitchStackedAreaPreset()
        let expectedData = [[20.0, 20, 20], [30, -30, 30], [5, 5, 5]]
        XCTAssertEqual(lineState.model.series.map(\.data), expectedData)
        XCTAssertEqual(combinedState.model.series.map(\.data), expectedData)
        let v = chart(expectedData), r = v.rendererForTesting
        v.configure(model: lineState.model, theme: lineState.builtTheme); v.layoutIfNeeded()
        let combined = HYMChartView<CombinedChartRenderer>(frame: v.frame)
        combined.configure(model: combinedState.model, theme: combinedState.builtTheme); combined.layoutIfNeeded()
        func paths(_ root: CALayer) -> [CGPath] {
            if let fill = root as? CAGradientLayer, let path = (fill.mask as? CAShapeLayer)?.path { return [path] }
            return (root.sublayers ?? []).flatMap(paths)
        }
        XCTAssertEqual(paths(r.rootLayer), paths(combined.rendererForTesting.rootLayer))
        for i in 0..<3 {
            let hit = try XCTUnwrap(r.seriesHitTest(r.testScreenPoint(series: 2, index: i)) as? LineHitTarget)
            XCTAssertEqual(hit.index, i); XCTAssertEqual(hit.rawValue, 5)
        }
        let source = HYMCartesianModel(); source.stacking = .normal
        source.series = expectedData.enumerated().map { i, data in
            let s = HYMCartesianSeries(); s.name = "S\(i)"; s.data = data.map(NSNumber.init(value:)); s.kind = .areaspline
            return s
        }
        let bridge = HYMCartesianChartViewBridge(kind: .line, frame: v.frame)
        bridge.stackedAreaFollowsBaseline = true; try bridge.configure(model: source); bridge.chartView.layoutIfNeeded()
        let oc = try XCTUnwrap(bridge.chartView as? HYMChartView<LineChartRenderer>)
        XCTAssertEqual(paths(oc.rendererForTesting.rootLayer).count, 3)
        let upper = try area(oc.rendererForTesting, 2)
        XCTAssertTrue(upper.contains(oc.rendererForTesting.screenPoint(x: 0.75, y: 22)))
        bridge.stackedAreaFollowsBaseline = false; try bridge.update(model: source, preserveViewport: true); oc.layoutIfNeeded()
        XCTAssertFalse(try area(oc.rendererForTesting, 2).contains(oc.rendererForTesting.screenPoint(x: 0.75, y: 22)))
    }
}
