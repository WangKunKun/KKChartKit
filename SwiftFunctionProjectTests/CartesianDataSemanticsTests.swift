import XCTest
@testable import SwiftFunctionProject

final class CartesianDataSemanticsTests: XCTestCase {
    private func model(_ stack: StackConfig? = .normal) -> CartesianChartModel {
        .init(series: [.init(name: "光伏", data: [100, -100, .nan], id: "solar", unit: "W", groupID: "energy"),
                       .init(name: "电池", data: [50, -50, 0], id: "battery", unit: "W", groupID: "energy")],
              stacking: stack, groups: [.init(id: "energy", name: "能源")])
    }
    private func chart<R: HYMChartRenderer>(_ type: R.Type, _ model: CartesianChartModel) -> HYMChartView<R>
        where R.Model == CartesianChartModel, R.Theme == CartesianChartTheme {
        let view = HYMChartView<R>(frame: CGRect(x: 0, y: 0, width: 390, height: 340))
        view.configure(model: model, theme: CartesianChartTheme()); view.layoutIfNeeded()
        return view
    }
    private func check<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type) throws {
        let view = chart(type, model()); let r = view.rendererForTesting
        let target = try XCTUnwrap(r.makeHitTarget(seriesIndex: 1, categoryIndex: 0, value: 150))
        let datum = try XCTUnwrap((target as? CartesianHitDataSource)?.chartData.first)
        XCTAssertEqual(datum.rawValue, 50); XCTAssertEqual(datum.drawValue, 150)
        XCTAssertEqual(datum.stackBase, 100); XCTAssertNil(datum.percentage)
        XCTAssertEqual(datum.groupID, "energy"); XCTAssertEqual(datum.groupName, "能源")
        XCTAssertEqual(datum.sourceRange, 0..<1)
        XCTAssertTrue(target.tooltipText!.contains("50 W")); XCTAssertFalse(target.tooltipText!.contains("150"))
        let frame = try XCTUnwrap(r.hitFrame(for: target))
        let point = CGPoint(x: frame.midX, y: frame.midY)
        let hit = try XCTUnwrap(r.seriesHitTest(point) as? CartesianHitDataSource)
        XCTAssertEqual(hit.chartData.first?.rawValue, 50)
        let shared = try XCTUnwrap(r.sharedHit(at: point)?.target as? CartesianSharedHitTarget)
        XCTAssertEqual(shared.entries.last?.rawValue, 50)
        XCTAssertEqual(shared.entries.last?.drawValue, 150)
        XCTAssertEqual(shared.entries.last?.stackBase, 100)
        let snap = try XCTUnwrap(r.snapHit(at: point) as? CartesianHitDataSource)
        XCTAssertEqual(snap.chartData.first?.drawValue, r.currentDrawValues[snap.chartData[0].seriesIndex][0])
        view.tooltipTextOptions = .init(header: "{key}", valueSuffix: " W", valueDecimals: 1)
        XCTAssertTrue(view.formattedTooltipText(for: target)!.contains("50.0 W"))
    }
    func testColumnBodySnapAndSharedUseSameValues() throws { try check(ColumnChartRenderer.self) }
    func testBarBodySnapAndSharedUseSameValues() throws { try check(BarChartRenderer.self) }
    func testLineBodySnapAndSharedUseSameValues() throws { try check(LineChartRenderer.self) }

    func testNegativeStackAndMissingVersusZero() throws {
        let view = chart(ColumnChartRenderer.self, model())
        let r = view.rendererForTesting
        let negative = try XCTUnwrap(r.datum(series: 1, category: 1))
        XCTAssertEqual(negative.rawValue, -50); XCTAssertEqual(negative.drawValue, -150)
        XCTAssertEqual(negative.stackBase, -100)
        XCTAssertNil(r.datum(series: 0, category: 2))
        XCTAssertEqual(r.datum(series: 1, category: 2)?.rawValue, 0)
        XCTAssertNil(r.datum(series: -1, category: 0)); XCTAssertNil(r.datum(series: 0, category: -1))
    }
    func testSignedPercentageUsesVisibleSeriesAndIndependentAxis() throws {
        var m = model(.percent)
        let v = chart(ColumnChartRenderer.self, m); let r = v.rendererForTesting
        XCTAssertEqual(try XCTUnwrap(r.datum(series: 1, category: 0)?.percentage), 100.0 / 3, accuracy: 0.00001)
        XCTAssertEqual(try XCTUnwrap(r.datum(series: 1, category: 1)?.percentage), -100.0 / 3, accuracy: 0.00001)
        v.setSeriesVisible(false, for: "solar"); v.layoutIfNeeded()
        XCTAssertNil(r.datum(series: 0, category: 0))
        XCTAssertEqual(r.datum(series: 1, category: 0)?.percentage, 100)
        m.series[1].yAxisIndex = 1; m.secondaryYAxis = .init(kind: .value)
        v.configure(model: m, theme: CartesianChartTheme()); v.layoutIfNeeded()
        XCTAssertEqual(r.datum(series: 1, category: 0)?.percentage, 100)
        XCTAssertEqual(r.datum(series: 1, category: 0)?.yAxisIndex, 1)
        m.stacking = .percentFixed(max: 200)
        v.update(model: m); v.layoutIfNeeded()
        XCTAssertEqual(r.datum(series: 1, category: 0)?.percentage, 25)
        XCTAssertEqual(r.datum(series: 1, category: 0)?.rawValue, 50)
    }
    func testNonStackedAndMetadataUpdateDoNotChangeMath() throws {
        var m = model(nil)
        let v = chart(ColumnChartRenderer.self, m); let r = v.rendererForTesting
        XCTAssertEqual(r.datum(series: 1, category: 0)?.stackBase, 0)
        XCTAssertNil(r.datum(series: 1, category: 0)?.percentage)
        m.groups[0].name = "新组"; m.series[1].valueFormat = CartesianValueFormat()
        m.series[1].valueFormat?.showsAbsoluteValue = true
        v.update(model: m); v.layoutIfNeeded()
        let data = try XCTUnwrap(r.datum(series: 1, category: 1))
        XCTAssertEqual(data.groupName, "新组"); XCTAssertEqual(data.rawValue, -50)
        XCTAssertEqual(data.drawValue, -50); XCTAssertEqual(data.formattedValue, "50 W")
    }
    func testAggregationHasNoSingleRawSampleAndPreservesSourceRange() throws {
        var m = model(.normal)
        m.series[0].data = Array(repeating: 2, count: 300)
        m.series[1].data = Array(repeating: 4, count: 300)
        m.series[0].aggregation = .sum; m.series[1].aggregation = .average
        m.timeAxis = .init(start: Date(timeIntervalSince1970: 0), interval: 300)
        m.timeGrouping = .init(minimumColumnWidth: 20)
        let v = chart(ColumnChartRenderer.self, m); let r = v.rendererForTesting
        let d = try XCTUnwrap(r.datum(series: 1, category: 0))
        XCTAssertNil(d.rawValue); XCTAssertEqual(try XCTUnwrap(d.aggregatedValue), 4, accuracy: 0.000001)
        XCTAssertGreaterThan(d.sourceRange.count, 1)
        XCTAssertEqual(d.drawValue, Double(d.sourceRange.count * 2) + 4)
        XCTAssertEqual(d.stackBase, Double(d.sourceRange.count * 2))
        let t = try XCTUnwrap(r.makeHitTarget(seriesIndex: 1, categoryIndex: 0, value: d.drawValue) as? ColumnHitTarget)
        XCTAssertNil(t.rawValue); XCTAssertTrue(t.tooltipText!.contains("有效"))
        XCTAssertTrue(t.tooltipText!.contains("4 W"))
        v.showCategoryRange(0..<2); v.layoutIfNeeded()
        XCTAssertEqual(r.datum(series: 1, category: 0)?.rawValue, 4)
    }
    func testSampledLineReadsOriginalValue() throws {
        let m = CartesianChartModel(series: [.init(name: "线", data: Array(repeating: 10, count: 3000), id: "line")])
        let v = chart(LineChartRenderer.self, m)
        var theme = CartesianChartTheme(); theme.lineSampling = .init()
        v.update(theme: theme); v.layoutIfNeeded()
        let r = v.rendererForTesting
        let target = try XCTUnwrap(r.seriesHitTest(r.testScreenPoint(series: 0, index: 1200)) as? LineHitTarget)
        XCTAssertEqual(target.rawValue, 10); XCTAssertEqual(target.drawValue, 10)
        XCTAssertEqual(target.datum?.sourceRange.count, 1)
    }
    func testFormatsAreIndependentAndDoNotOverrideExplicitSeriesRules() throws {
        var m = model()
        var f = CartesianValueFormat(); f.localeIdentifier = "en_US"; f.scale = .engineering
        f.maximumFractionDigits = 1
        m.series[0].data = [1250]; m.series[0].valueFormat = f
        m.series[1].data = [50]; m.series[1].unit = "%"
        let v = chart(ColumnChartRenderer.self, m); let r = v.rendererForTesting
        let p = r.currentPlotFrame
        let shared = try XCTUnwrap(r.sharedHit(at: CGPoint(x: p.midX, y: p.midY))?.target)
        v.tooltipTextOptions = .init(header: "{key}", valueSuffix: " global", valueDecimals: 2)
        let text = try XCTUnwrap(v.formattedTooltipText(for: shared))
        XCTAssertTrue(text.contains("1.3 kW")); XCTAssertTrue(text.contains("50.00 global"))
        XCTAssertEqual((shared as? CartesianHitDataSource)?.chartData.first?.rawValue, 1250)
    }
    func testFormattingLocaleCurrencyRoundingAndInvalidValues() {
        var f = CartesianValueFormat(); f.localeIdentifier = "en_US"
        f.maximumFractionDigits = 2; f.rounding = .towardZero
        XCTAssertEqual(f.string(from: -12.349), "-12.34")
        f.currencySymbol = "$"
        XCTAssertEqual(f.string(from: -12.349), "-$12.34")
        f.showsAbsoluteValue = true
        XCTAssertEqual(f.string(from: -12.349), "$12.34")
        f.currencySymbol = ""; f.scale = .engineering
        XCTAssertEqual(f.string(from: 1_250_000, unit: "Wh"), "1.25 MWh")
        f.localeIdentifier = "de_DE"
        XCTAssertEqual(f.string(from: 1250, unit: "W"), "1,25 kW")
        XCTAssertEqual(f.string(from: .nan), "无数据"); XCTAssertEqual(f.string(from: .infinity), "无数据")
        XCTAssertEqual(f.string(from: nil), "无数据"); XCTAssertEqual(f.string(from: 0, unit: "%"), "0 %")
    }
    func testOCParsingRetainsMissingSlotsAndRejectsInvalidConfiguration() throws {
        let s = HYMCartesianSeries(); s.identifier = "s"; s.name = "OC"
        s.data = [NSNumber(value: 0), " 12.5 ", NSNull(), "wrong", "inf", NSNumber(value: Double.nan)]
        let m = HYMCartesianModel(); m.series = [s]
        let data = m.build().series[0].data
        XCTAssertEqual(data.count, 6); XCTAssertEqual(data[0], 0); XCTAssertEqual(data[1], 12.5)
        XCTAssertTrue(data.dropFirst(2).allSatisfy(\.isNaN))
        let bridge = HYMCartesianChartViewBridge(kind: .column, frame: .init(x: 0, y: 0, width: 390, height: 300))
        try bridge.configure(model: m); bridge.chartView.layoutIfNeeded()
        m.series = [s, s]
        XCTAssertThrowsError(try bridge.configure(model: m)) { error in
            XCTAssertEqual((error as NSError).domain, HYMCartesianConfigurationError.errorDomain)
            XCTAssertEqual((error as NSError).code, HYMCartesianConfigurationError.invalidIdentifiers.rawValue)
        }
        let current = try XCTUnwrap(bridge.chartView as? HYMChartView<ColumnChartRenderer>)
        XCTAssertEqual(current.rendererForTesting.datum(series: 0, category: 1)?.rawValue, 12.5)
        m.series = [s]; m.stacking = .percentFixed; m.percentageBase = 0
        XCTAssertThrowsError(try bridge.configure(model: m))
        m.stacking = .none; m.usesSecondaryAxis = true
        let bar = HYMCartesianChartViewBridge(kind: .bar, frame: .zero)
        XCTAssertThrowsError(try bar.configure(model: m))
    }
    func testOCBridgeSnapshotsFormatVisibilityRangeAndLifetime() throws {
        var retainedView: UIView?
        weak var released: HYMCartesianChartViewBridge?
        do {
            let b = HYMCartesianChartViewBridge(kind: .column, frame: .init(x: 0, y: 0, width: 390, height: 300))
            released = b; retainedView = b.chartView
            let m = HYMCartesianModel(); let s = HYMCartesianSeries(); s.identifier = "s"
            s.data = Array(repeating: -1250, count: 60); s.unit = "W"
            s.valueFormat = HYMCartesianValueFormat(); s.valueFormat?.engineeringScale = true
            s.valueFormat?.showsAbsoluteValue = true; s.valueFormat?.localeIdentifier = "en_US"
            let g = HYMCartesianGroup(); g.identifier = "g"; g.name = "组"; s.groupID = "g"
            m.series = [s]; m.groups = [g]
            try b.configure(model: m); b.chartView.layoutIfNeeded()
            let chart = try XCTUnwrap(b.chartView as? HYMChartView<ColumnChartRenderer>)
            let original = HYMCartesianDatum(try XCTUnwrap(chart.rendererForTesting.datum(series: 0, category: 0)))
            XCTAssertEqual(original.rawValue, -1250); XCTAssertEqual(original.formattedValue, "1.25 kW")
            XCTAssertEqual(original.groupName, "组"); XCTAssertEqual(original.sourceRange, NSRange(location: 0, length: 1))
            s.data = Array(repeating: 50, count: 60)
            XCTAssertEqual(chart.rendererForTesting.datum(series: 0, category: 0)?.rawValue, -1250)
            b.showCategoryRange(NSRange(location: 20, length: 15))
            let before = chart.rendererForTesting.xAxisViewport
            try b.update(model: m, preserveViewport: true); chart.layoutIfNeeded()
            XCTAssertEqual(chart.rendererForTesting.xAxisViewport, before)
            XCTAssertEqual(chart.rendererForTesting.datum(series: 0, category: 0)?.rawValue, 50)
            XCTAssertEqual(original.rawValue, -1250)
            b.setSeriesVisible(false, forID: "s"); chart.layoutIfNeeded()
            XCTAssertNil(chart.rendererForTesting.datum(series: 0, category: 0))
            b.resetViewport(); chart.layoutIfNeeded()
        }
        XCTAssertNotNil(retainedView); XCTAssertNil(released, "bridge must not cycle through chart closures")
    }
    func testLegacyManuallyConstructedTargetDoesNotInventRawValue() {
        let column = ColumnHitTarget(seriesIndex: 0, categoryIndex: 0, value: 150)
        let bar = BarHitTarget(seriesIndex: 0, categoryIndex: 0, value: 150)
        let line = LineHitTarget(seriesIndex: 0, index: 0, value: 150, label: "legacy")
        XCTAssertEqual(column.value, 150); XCTAssertEqual(bar.value, 150); XCTAssertEqual(line.value, 150)
        XCTAssertNil(column.rawValue); XCTAssertNil(bar.rawValue); XCTAssertNil(line.rawValue)
        XCTAssertTrue(column.chartData.isEmpty)
    }

}
