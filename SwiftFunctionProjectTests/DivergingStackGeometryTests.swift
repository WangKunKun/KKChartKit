import XCTest
import UIKit
@testable import SwiftFunctionProject

@MainActor final class DivergingStackGeometryTests: XCTestCase {
    typealias G = LineStackedAreaGeometry
    private func model(_ data: [[Double]], styles: [LineConnectionStyle] = [.straight],
                       stacking: StackConfig = .normal) -> CartesianChartModel {
        .init(series: data.enumerated().map { s, values in
            var style = CartesianSeriesStyle(); style.showsArea = true
            style.lineConnectionStyle = styles[s % styles.count]
            return CartesianSeriesElement(name: "S\(s)", data: values, connectNulls: true, id: "s\(s)", style: style)
        }, stacking: stacking)
    }
    private func build(_ model: CartesianChartModel, budget: Int = 16_384) -> LineDivergingStackGeometry.Result {
        var theme = CartesianChartTheme(); theme.stackedAreaBoundaryMode = .diverging
        return LineDivergingStackGeometry.contours(model: model, theme: theme,
            drawValues: model.stackedDrawValues, baseValues: model.allBaseValues,
            maximumPieces: budget, includes: { _ in true }, point: { CGPoint(x: $0, y: $1 + Double($2) * 1000) })
    }
    private func value(_ edge: G.Edge, _ x: CGFloat) -> CGFloat {
        let t = (x - edge.start.x) / (edge.end.x - edge.start.x), u = 1 - t
        guard let c = edge.controls else { return edge.start.y * u + edge.end.y * t }
        return u*u*u*edge.start.y + 3*u*u*t*c.0.y + 3*u*t*t*c.1.y + t*t*t*edge.end.y
    }
    private func bounds(_ contour: G.Contour, _ x: CGFloat) throws -> (CGFloat, CGFloat) {
        let piece = try XCTUnwrap(contour.segments.flatMap { $0.areaPieces ?? [] }.first {
            $0.top[0].start.x <= x && $0.top[0].end.x >= x
        })
        return (value(piece.baseline[0], x), value(piece.top[0], x))
    }
    private func interpolate(_ data: [Double], _ style: LineConnectionStyle, _ x: CGFloat) -> Double {
        let segment = G.Segment(indices: Array(data.indices),
            points: data.enumerated().map { CGPoint(x: Double($0), y: $1) }, style: style)
        return Double(value(segment.edges.first { $0.start.x < x && $0.end.x > x }!, x))
    }

    func testActualZeroCutNotEndpointOnlyCopies() throws {
        let m = model([[20,20], [-30,-30], [10,-10], [2,2]])
        let result = build(m); XCTAssertTrue(result.linearFallbackSeries.isEmpty)
        let crossing = try XCTUnwrap(result.contours[2])
        let left = try bounds(crossing, 0.25), right = try bounds(crossing, 0.75)
        XCTAssertEqual(left.0, 20); XCTAssertEqual(left.1, 25)
        XCTAssertEqual(right.0, -30); XCTAssertEqual(right.1, -35)
        let pieces = crossing.segments[0].areaPieces!
        XCTAssertEqual(pieces[0].top[0].end, pieces[0].baseline[0].end)
        XCTAssertEqual(pieces[1].top[0].start, pieces[1].baseline[0].start)
        XCTAssertEqual(pieces[0].top[0].end.x, 0.5)
        XCTAssertTrue(crossing.segments[0].edges.contains(where: \.startsSubpath))
        XCTAssertEqual(try bounds(result.contours[3]!, 0.75).0, 20)
        XCTAssertEqual(m.series[2].data, [10,-10])
    }

    func testAll125MixedStylesReuseExactSignBoundariesAndMatchContributionOracle() throws {
        let data = [[10.0,80,-20,60], [6,-5,8,-4], [0.2,0.2,0.2,0.2]]
        for a in LineConnectionStyle.allCases {
            for b in LineConnectionStyle.allCases {
                for c in LineConnectionStyle.allCases {
                    let styles = [a,b,c], result = build(model(data, styles: styles))
                    XCTAssertTrue(result.linearFallbackSeries.isEmpty)
                    for i in 0..<3 {
                        for fraction in [0.11,0.29,0.47,0.63,0.87] {
                            let x = CGFloat(i) + fraction
                            var positive: CGFloat = 0, negative: CGFloat = 0
                            for s in data.indices {
                                let expected = CGFloat(interpolate(data[s], styles[s], x))
                                let actual = try bounds(result.contours[s]!, x)
                                let base = expected >= 0 ? positive : negative
                                XCTAssertEqual(actual.0, base, accuracy: 1e-8, "\(styles), s=\(s), x=\(x)")
                                XCTAssertEqual(actual.1, base + expected, accuracy: 1e-8)
                                if expected >= 0 { positive += expected } else { negative += expected }
                            }
                        }
                    }
                    // All contributors share identical partitions; adjacent same-sign boundaries
                    // are bit-for-bit identical, not merely close at selected pixel samples.
                    let pieces = data.indices.map { result.contours[$0]!.segments[0].areaPieces! }
                    for i in pieces[0].indices {
                        var positive: G.Edge?, negative: G.Edge?
                        for s in data.indices {
                            let piece = pieces[s][i], x = (piece.top[0].start.x + piece.top[0].end.x) / 2
                            let isPositive = value(piece.top[0], x) >= value(piece.baseline[0], x)
                            if let previous = isPositive ? positive : negative {
                                XCTAssertEqual(previous.start, piece.baseline[0].start)
                                XCTAssertEqual(previous.end, piece.baseline[0].end)
                                XCTAssertEqual(previous.controls?.0, piece.baseline[0].controls?.0)
                                XCTAssertEqual(previous.controls?.1, piece.baseline[0].controls?.1)
                            }
                            if isPositive { positive = piece.top[0] } else { negative = piece.top[0] }
                        }
                    }
                }
            }
        }
    }

    func testMissingAndRaggedTailsCutWholeChainRegardlessOfConnectPolicy() throws {
        var m = model([[10,20,.nan,40,50,60], [1,2,3,4,5]])
        m.series[0].gapPolicy = .connectAll; m.series[1].connectNulls = true
        let result = build(m)
        for s in 0..<2 {
            XCTAssertEqual(result.contours[s]?.segments.map(\.indices), [[0,1],[3,4]])
            let path = result.contours[s]!.path
            XCTAssertFalse(path.contains(CGPoint(x: 2.5, y: 25)))
        }
        XCTAssertTrue(m.series[0].data[2].isNaN)
        XCTAssertEqual(m.series[1].data.count, 5)
    }

    func testHiddenIndependentAxesAndStackIDsDoNotPoisonOtherChains() throws {
        var m = model([[10,20,30], [1,.nan,1], [3,.nan,3], [5,.nan,5], [7,.nan,7]])
        m.series[1].isVisible = false
        m.series[2].participatesInStack = false
        m.series[3].stackID = "separate"
        m.series[4].yAxisIndex = 1
        let result = build(m)
        XCTAssertEqual(Set(result.contours.keys), [0,3,4])
        XCTAssertEqual(result.contours[0]?.segments.map(\.indices), [[0,1,2]])
        XCTAssertEqual(result.contours[3]?.segments.map(\.indices), [[0],[2]])
        XCTAssertEqual(result.contours[4]?.segments.map(\.indices), [[0],[2]])
    }

    func testPercentageUsesRawInterpolationAndIncludesNonAreaLines() throws {
        var m = model([[10,100], [10,1]], stacking: .percent)
        m.series[1].style.showsArea = false
        let result = build(m)
        XCTAssertEqual(Set(result.contours.keys), [0,1]); XCTAssertTrue(result.linearFallbackSeries.isEmpty)
        let first = try bounds(result.contours[0]!, 0.5), second = try bounds(result.contours[1]!, 0.5)
        XCTAssertEqual(first.1, 55 / 60.5 * 100, accuracy: 0.05)
        XCTAssertEqual(second.0, first.1)
        XCTAssertEqual(second.1, 100, accuracy: 1e-10)
    }

    func testPercentSimultaneousZeroCrossingUsesFiniteOneSidedLimits() throws {
        for style in LineConnectionStyle.allCases {
            let m = model([[10,-10],[20,-20]], styles: [style], stacking: .percent)
            let result = build(m)
            XCTAssertTrue(result.linearFallbackSeries.isEmpty, "\(style)")
            for x: CGFloat in [0.1,0.49,0.51,0.9] {
                let expectedSign = interpolate([10,-10], style, x) >= 0 ? 1.0 : -1.0
                XCTAssertEqual(try bounds(result.contours[1]!, x).1, expectedSign * 100, accuracy: 1e-8)
            }
        }
    }

    func testZeroDenominatorSamplesBreakInsteadOfInventingContinuousPercent() throws {
        let result = build(model([[10,20,0,-20,-10], [5,10,0,-10,-5]], stacking: .percent))
        XCTAssertEqual(result.contours[0]?.segments.map(\.indices), [[0,1],[3,4]])
        XCTAssertEqual(result.contours[1]?.segments.map(\.indices), [[0,1],[3,4]])
        XCTAssertTrue(result.linearFallbackSeries.isEmpty)
    }

    func testBudgetFallbackIsAtomicStillSharedAndAlwaysHundredPercent() throws {
        let m = model([[10,90,-10], [3,-5,8], [1,1,1]], styles: [.smooth,.stepBefore,.stepCenter], stacking: .percent)
        let result = build(m, budget: 0)
        XCTAssertEqual(result.linearFallbackSeries, [0,1,2])
        for x: CGFloat in [0.13,0.4,0.71,1.17,1.51,1.93] {
            var extent: CGFloat = 0, positive: CGFloat = 0, negative: CGFloat = 0
            for s in 0..<3 {
                let b = try bounds(result.contours[s]!, x), weight = b.1 - b.0
                XCTAssertEqual(b.0, weight >= 0 ? positive : negative, accuracy: 1e-8)
                extent += abs(weight)
                if weight >= 0 { positive = b.1 } else { negative = b.1 }
            }
            XCTAssertEqual(extent, 100, accuracy: 1e-8)
        }
        for s in 0..<3 { XCTAssertEqual(result.contours[s]?.segments[0].points.map(\.y), m.stackedDrawValues[s].map { CGFloat($0) }) }
    }

    func testGroupedAndFixedPercentKeepTheirNumericPartitions() throws {
        for mode: StackConfig in [.normal,.grouped(groupCount: 2),.percentFixed(max: 200)] {
            let m = model([[20,40],[2,4],[10,-10]], styles: [.smooth,.stepAfter], stacking: mode)
            let result = build(m)
            XCTAssertTrue(result.linearFallbackSeries.isEmpty)
            for s in 0..<3 {
                XCTAssertEqual(result.contours[s]?.segments[0].points.map(\.y), m.stackedDrawValues[s].map { CGFloat($0) })
            }
            let expected = mode == .grouped(groupCount: 2) ? 0 : (mode == .normal ? 30.0 : 15.0)
            XCTAssertEqual(try bounds(result.contours[1]!, 0.5).0, expected, accuracy: 1e-8)
        }
    }
    func testAllMixedPercentStylesMatchRawRationalReferenceAndHundredEnvelope() throws {
        let data = [[10.0,80,-20,60], [6,-5,8,-4], [3,3,3,3]]
        for a in LineConnectionStyle.allCases {
            for b in LineConnectionStyle.allCases {
                for c in LineConnectionStyle.allCases {
                    let styles = [a,b,c], result = build(model(data, styles: styles, stacking: .percent))
                    XCTAssertTrue(result.linearFallbackSeries.isEmpty, "\(styles)")
                    for i in 0..<3 {
                        for f: CGFloat in [0.13,0.39,0.67,0.89] {
                            let x = CGFloat(i) + f
                            let raw = data.indices.map { interpolate(data[$0], styles[$0], x) }
                            let total = raw.reduce(0) { $0 + abs($1) }
                            var positive: CGFloat = 0, negative: CGFloat = 0, extent: CGFloat = 0
                            for s in data.indices {
                                let weight = CGFloat(raw[s] / total * 100), base = weight >= 0 ? positive : negative
                                let actual = try bounds(result.contours[s]!, x)
                                XCTAssertEqual(actual.0, base, accuracy: 0.05)
                                XCTAssertEqual(actual.1, base + weight, accuracy: 0.05)
                                extent += abs(actual.1 - actual.0)
                                if weight >= 0 { positive += weight } else { negative += weight }
                            }
                            XCTAssertEqual(extent, 100, accuracy: 1e-8)
                        }
                    }
                }
            }
        }
    }

    func testEntireZeroDenominatorStepIntervalHasNoAreaOrBridgingStroke() throws {
        let m = model([[1,0], [0,1]], styles: [.stepBefore,.stepAfter], stacking: .percent)
        for budget in [0,16_384] {
            let result = build(m, budget: budget)
            for s in 0..<2 {
                XCTAssertTrue(result.contours[s]!.segments[0].areaPieces!.isEmpty)
                XCTAssertTrue(result.contours[s]!.segments[0].edges.allSatisfy {
                    $0.startsSubpath || $0.start.x == $0.end.x
                })
            }
        }
    }

    func testDeterministicLargeInputKeepsFiniteSharedContoursWithoutSamplingData() {
        let data = (0..<6).map { s in (0..<1500).map { i in sin(Double(i + s * 7) * 0.1) * Double(s + 1) * 10 } }
        let m = model(data, styles: LineConnectionStyle.allCases)
        let result = build(m)
        XCTAssertTrue(result.linearFallbackSeries.isEmpty)
        for s in data.indices {
            let contour = result.contours[s]!
            XCTAssertEqual(contour.segments[0].indices.count, 1500)
            for edge in contour.segments[0].edges {
                for p in [edge.start,edge.end] + (edge.controls.map { [$0.0,$0.1] } ?? []) {
                    XCTAssertTrue(p.x.isFinite && p.y.isFinite)
                }
            }
            XCTAssertEqual(m.series[s].data, data[s])
        }
    }

    func testEmptyParticipatingSeriesIsMissingNotInventedZero() {
        var m = model([[10,20,30], []])
        let strict = build(m)
        XCTAssertEqual(Set(strict.contours.keys), [0,1])
        XCTAssertTrue(strict.contours.values.allSatisfy { $0.segments.isEmpty })
        m.series[1].isVisible = false
        XCTAssertEqual(build(m).contours[0]?.segments.first?.indices, [0,1,2])
    }

    func testTinyNegativePercentContributionNeverChangesSign() throws {
        let m = model([[1,1], [-1e-14,-1e-14]], stacking: .percent)
        let result = build(m)
        XCTAssertTrue(result.linearFallbackSeries.isEmpty)
        let negative = try bounds(XCTUnwrap(result.contours[1]), 0.5)
        XCTAssertEqual(negative.0, 0)
        XCTAssertLessThan(negative.1, 0)
        XCTAssertEqual(negative.1, -1e-12, accuracy: 1e-24)
    }

}
