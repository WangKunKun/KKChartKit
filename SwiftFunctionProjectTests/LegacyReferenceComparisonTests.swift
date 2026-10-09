import XCTest
@testable import SwiftFunctionProject

/// Versioned shared fixture inputs, checked against saved Highcharts 11.4.3 probes where stated.
/// These are renderer comparisons, not a completed HMAA model adapter or business page.
@MainActor final class LegacyReferenceComparisonTests: XCTestCase {
    private let indices = [0, 12, 24, 25, 36, 47]
    private let orange = UIColor(red: 242 / 255, green: 169 / 255, blue: 59 / 255, alpha: 1)
    private let blue = UIColor(red: 67 / 255, green: 168 / 255, blue: 239 / 255, alpha: 1)
    private let purple = UIColor(red: 151 / 255, green: 105 / 255, blue: 232 / 255, alpha: 1)

    private var categories: [String] {
        (0..<48).map { String(format: "%02d:%02d", $0 / 2, ($0 % 2) * 30) }
    }

    private struct Fixture: Decodable {
        struct Sample: Decodable {
            struct Series: Decodable { let id: String; let name: String; let kind: String; let stackID: String; let values: [Double?] }
            let id: String; let groups: [[String]]; let series: [Series]
        }
        let schemaVersion: Int; let domainID: String; let categories: [String]; let cases: [Sample]
    }

    private func fixtureModel(_ identifier: String, stacking: StackConfig = .normal,
                              partitionsByType: Bool = false, version: Int = 1) throws -> CartesianChartModel {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "chart-migration-audit-v\(version)", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.schemaVersion, version)
        XCTAssertEqual(fixture.domainID, "reference-day-2026-09-30-48")
        let sample = try XCTUnwrap(fixture.cases.first { $0.id == identifier })
        let series = try sample.series.enumerated().map { offset, input in
            let kind = try XCTUnwrap(CartesianSeriesKind(rawValue: input.kind))
            let groupIndex = try XCTUnwrap(sample.groups.firstIndex { $0.contains(input.id) })
            var format = CartesianValueFormat(); format.showsAbsoluteValue = input.id == "battery"
            return CartesianSeriesElement(name: input.name, data: input.values.map { $0 ?? .nan }, color: offset == 0 ? orange : blue,
                id: input.id, legendOrder: offset, unit: "W", groupID: "g\(groupIndex)", valueFormat: format, kind: kind,
                stackID: partitionsByType ? input.stackID + ":" + input.kind : input.stackID)
        }
        var model = CartesianChartModel(series: series, xAxis: .init(kind: .category(labels: fixture.categories)), stacking: stacking)
        model.groups = sample.groups.indices.map { .init(id: "g\($0)", name: "电池") }
        return model
    }

    private func chart<R: CartesianRendererBase<CartesianChartTheme>>(_ type: R.Type,
            model: CartesianChartModel) -> HYMChartView<R> {
        let view = HYMChartView<R>(frame: .init(x: 0, y: 0, width: 390, height: 330))
        view.backgroundColor = .white
        view.configure(model: model, theme: .init()); view.layoutIfNeeded()
        return view
    }

    private func attach<R: CartesianRendererBase<CartesianChartTheme>>(_ view: HYMChartView<R>, name: String) throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { view.layer.render(in: $0.cgContext) }
        let picture = XCTAttachment(image: image); picture.name = name; picture.lifetime = .keepAlways
        add(picture)
        let renderer = view.rendererForTesting
        let model = try XCTUnwrap(renderer.currentModel)
        let series: [[String: Any]] = model.series.indices.map { s in
            let samples: [[String: Any]] = indices.compactMap { index in
                guard let datum = renderer.datum(series: s, category: index) else { return nil }
                return ["index": index, "raw": datum.rawValue as Any? ?? NSNull(),
                        "percentage": datum.percentage as Any? ?? NSNull(), "stackY": datum.drawValue, "stackBase": datum.stackBase]
            }
            return ["id": model.series[s].id, "name": model.series[s].name, "samples": samples,
                    "type": model.series[s].kind?.rawValue ?? "default", "stack": model.series[s].stackID as Any? ?? NSNull(),
                    "groupID": model.series[s].groupID as Any? ?? NSNull()]
        }
        let snapshot: [String: Any] = ["series": series,
            "axes": [["min": renderer.currentViewport.yMin, "max": renderer.currentViewport.yMax]]]
        let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testCapturedSignedSamplesMatchWhenLegacyStackOrderIsMapped() throws {
        let original = try fixtureModel("signed-column")
        let originalView = chart(ColumnChartRenderer.self, model: original)
        // Existing native order starts with the first series; the bundled legacy engine starts with the last.
        XCTAssertEqual(originalView.rendererForTesting.datum(series: 0, category: 12)?.drawValue, 1800)
        XCTAssertEqual(originalView.rendererForTesting.datum(series: 1, category: 12)?.drawValue, 2920)
        try attach(originalView, name: "hym-signed-default-order")

        let batteryRaw = [0.0, 1800, 0, -235, -1800, -235]
        let auxRaw = [220.0, 1120, 220, 103, -680, 103]
        let legacyBatteryNormal = [220.0, 2920, 220, -235, -2480, -235]
        let legacyAuxNormal = [220.0, 1120, 220, 103, -680, 103]
        let legacyBatteryPercent = [100.0, 100, 100, -69.526627218935, -100, -69.526627218935]
        let legacyAuxPercent = [100.0, 38.356164383562, 100, 30.473372781065, -27.41935483871, 30.473372781065]
        for stacking in [StackConfig.normal, .percent] {
            var model = try fixtureModel("signed-column", stacking: stacking); model.series.reverse()
            let view = chart(ColumnChartRenderer.self, model: model)
            let renderer = view.rendererForTesting
            for (offset, index) in indices.enumerated() {
                let aux = try XCTUnwrap(renderer.datum(series: 0, category: index))
                let battery = try XCTUnwrap(renderer.datum(series: 1, category: index))
                XCTAssertEqual(battery.rawValue, batteryRaw[offset]); XCTAssertEqual(aux.rawValue, auxRaw[offset])
                let isPercent = stacking == .percent
                XCTAssertEqual(battery.drawValue, isPercent ? legacyBatteryPercent[offset] : legacyBatteryNormal[offset], accuracy: 1e-8)
                XCTAssertEqual(aux.drawValue, isPercent ? legacyAuxPercent[offset] : legacyAuxNormal[offset], accuracy: 1e-8)
                if isPercent {
                    let total = abs(batteryRaw[offset]) + abs(auxRaw[offset])
                    XCTAssertEqual(try XCTUnwrap(battery.percentage), batteryRaw[offset] / total * 100, accuracy: 1e-8)
                    XCTAssertEqual(try XCTUnwrap(aux.percentage), auxRaw[offset] / total * 100, accuracy: 1e-8)
                } else { XCTAssertNil(battery.percentage); XCTAssertNil(aux.percentage) }
            }
            if stacking == .percent {
                XCTAssertLessThanOrEqual(renderer.currentViewport.yMin, -100)
                XCTAssertGreaterThanOrEqual(renderer.currentViewport.yMax, 100)
            }
            try attach(view, name: stacking == .percent ? "hym-signed-percent-mapped" : "hym-signed-normal-mapped")
        }
    }

    func testSharedAreaSamplesKeepBusinessValuesWithoutAuxiliarySeries() throws {
        for identifier in ["area-single", "area-multi"] {
            var model = try fixtureModel(identifier); model.series.reverse()
            let view = chart(CombinedChartRenderer.self, model: model)
            XCTAssertEqual(view.rendererForTesting.currentModel?.series.count, 2)
            for series in model.series.indices {
                for index in indices {
                    XCTAssertEqual(view.rendererForTesting.datum(series: series, category: index)?.rawValue,
                                   model.series[series].data[index])
                }
            }
            XCTAssertEqual(view.rendererForTesting.datum(series: 1, category: 12)?.drawValue, 2920)
            XCTAssertEqual(view.rendererForTesting.datum(series: 1, category: 36)?.drawValue, -2480)
            try attach(view, name: "hym-" + identifier + "-business-series")
        }
    }

    func testMixedConcreteTypesNeedCompatibilityStackPartitions() throws {
        let unmapped = chart(CombinedChartRenderer.self, model: try fixtureModel("mixed-types"))
        XCTAssertEqual(unmapped.rendererForTesting.datum(series: 1, category: 12)?.drawValue, 2920)
        try attach(unmapped, name: "hym-mixed-types-unmapped")
        let model = try fixtureModel("mixed-types", partitionsByType: true)
        let mapped = chart(CombinedChartRenderer.self, model: model)
        for series in model.series.indices {
            for index in indices {
                XCTAssertEqual(mapped.rendererForTesting.datum(series: series, category: index)?.drawValue,
                               model.series[series].data[index])
            }
        }
        try attach(mapped, name: "hym-mixed-types-partitioned")
    }

    func testLegacyGapInputKeepsColorZonesAndMissingSamplesIndependent() throws {
        let fixture = try detailFixture()
        let input = try XCTUnwrap(fixture.detailCases.first { $0.id == "gaps" })
        let values = input.series[0].values.map { $0 ?? .nan }
        let policy = CartesianGapPolicy.autoGap(maximumMissingPoints: 11)
        XCTAssertEqual(input.series[0].autoGap, true)
        let zones = CartesianColorZones(axis: input.series[0].zoneAxisX == true ? .x : .y,
            zones: try XCTUnwrap(input.series[0].zones).map {
                .init(upperBound: $0.value, color: try fixtureColor($0.color),
                      areaGradientColors: [try fixtureColor($0.fillColor)])
            })
        let model = CartesianChartModel(series: [
            .init(name: "屋顶光伏", data: values, color: orange, id: "solar", unit: "W",
                  kind: .areaspline, gapPolicy: policy, colorZones: zones),
            .init(name: "家庭负载", data: input.series[1].values.map { $0 ?? .nan },
                  color: blue, negativeColor: .systemPink, id: "load", unit: "W", kind: .areaspline)
        ], xAxis: .init(kind: .category(labels: fixture.categories)))
        let view = chart(LineChartRenderer.self, model: model)
        let renderer = view.rendererForTesting
        XCTAssertEqual(CartesianGapSegmenter.segments(values: values, policy: policy),
                       [Array(0..<8) + Array(13..<25), Array(37..<48)])
        for index in Array(8..<13) + Array(25..<37) { XCTAssertNil(renderer.datum(series: 0, category: index)) }
        XCTAssertEqual(renderer.datum(series: 0, category: 24)?.rawValue, 2747)
        XCTAssertEqual(renderer.currentModel?.series[0].colorZones?.zones.count, 2)
        let resolved = try XCTUnwrap(CartesianResolvedColorZones(configuration: zones, negativeColor: nil, baseColor: orange))
        XCTAssertEqual(resolved.color(x: 19, y: 2747), orange)
        XCTAssertEqual(resolved.color(x: 37, y: 2747), purple)
        try attach(view, name: "hym-gaps-independent-zones")
    }
    private struct DetailFixture: Decodable {
        struct Sample: Decodable {
            struct Series: Decodable {
                struct Zone: Decodable { let value: Double?; let color: String; let fillColor: String }
                let id: String; let name: String; let values: [Double?]; let unit: String
                let names: [String]?; let showPrev: Bool?; let hidePoints: [Int]?
                let hideInTooltip: Bool?; let currencySymbol: String?; let trunc: Bool?
                let autoGap: Bool?; let zoneAxisX: Bool?; let zones: [Zone]?
            }
            struct Group: Decodable {
                let id: String; let name: String; let names: [String]?; let members: [String]
                let onlyNameIntooltip: Bool?
            }
            let id: String; let series: [Series]; let groups: [Group]
        }
        let categories: [String]; let xSeries: [String]; let detailCases: [Sample]
    }
    private func detailFixture() throws -> DetailFixture {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "chart-migration-audit-v2", withExtension: "json"))
        return try JSONDecoder().decode(DetailFixture.self, from: Data(contentsOf: url))
    }
    private func fixtureColor(_ hex: String) throws -> UIColor {
        let digits = String(hex.dropFirst())
        let rgba = try XCTUnwrap(UInt32(digits, radix: 16))
        let hasAlpha = digits.count == 8
        let rgb = hasAlpha ? rgba >> 8 : rgba
        return UIColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
                       blue: CGFloat(rgb & 255) / 255, alpha: hasAlpha ? CGFloat(rgba & 255) / 255 : 1)
    }

    /// HYM's chosen independent-sign policy; no claim that the legacy area percent path is equivalent.
    func testSharedAreaPercentMissingAndVisibilityRecomputeEveryCategory() throws {
        for identifier in ["area-single", "area-multi", "area-missing"] {
            for stacking in [StackConfig.normal, .percent] {
                var model = try fixtureModel(identifier, stacking: stacking, version: 2)
                model.series.reverse()
                let view = chart(CombinedChartRenderer.self, model: model)
                for hidden in [false, true, false] {
                    view.setSeriesVisible(!hidden, for: "aux")
                    let renderer = view.rendererForTesting
                    for category in 0..<48 {
                        let finite = model.series.filter { (!hidden || $0.id != "aux") && $0.data[category].isFinite }
                        let total = finite.reduce(0.0) { $0 + abs($1.data[category]) }
                        var positive = 0.0, negative = 0.0
                        for (index, series) in model.series.enumerated() where !hidden || series.id != "aux" {
                            guard series.data[category].isFinite else {
                                XCTAssertNil(renderer.datum(series: index, category: category)); continue
                            }
                            let datum = try XCTUnwrap(renderer.datum(series: index, category: category))
                            let raw = series.data[category]
                            let expected = stacking == .percent ? (total == 0 ? 0 : raw / total * 100) : raw
                            let base = expected >= 0 ? positive : negative
                            XCTAssertEqual(datum.rawValue, raw)
                            XCTAssertEqual(datum.stackBase, base, accuracy: 1e-8)
                            XCTAssertEqual(datum.drawValue, base + expected, accuracy: 1e-8)
                            if expected >= 0 { positive += expected } else { negative += expected }
                            XCTAssertLessThanOrEqual(renderer.currentViewport.yMin, min(0, datum.drawValue) + 1e-8)
                            XCTAssertGreaterThanOrEqual(renderer.currentViewport.yMax, max(0, datum.drawValue) - 1e-8)
                        }
                    }
                }
                if identifier == "area-missing" { try attach(view, name: "hym-area-missing-\(stacking == .percent ? "percent" : "normal")") }
            }
        }
    }

    /// Shared old inputs exercise the intended new display rules. Exact legacy fractionDigits=100
    /// strings and dynamic group titles still need the production presentation adapter.
    func testSharedTooltipRulesPreserveHitIdentityAndPreviousValueSource() throws {
        let fixture = try detailFixture()
        let sample = try XCTUnwrap(fixture.detailCases.first { $0.id == "format" })
        let series = try sample.series.map { input -> CartesianSeriesElement in
            let group = try XCTUnwrap(sample.groups.first { $0.members.contains(input.id) })
            var format = CartesianValueFormat(); format.localeIdentifier = "en_US_POSIX"
            format.scale = .engineering; format.maximumFractionDigits = 2
            format.currencySymbol = input.currencySymbol ?? ""
            format.rounding = input.trunc == true ? .towardZero : .nearest
            return .init(name: input.name, data: input.values.map { $0 ?? .nan }, id: input.id,
                         unit: input.unit == "MONEY" ? nil : input.unit, groupID: group.id, valueFormat: format, kind: .areaspline)
        }
        var model = CartesianChartModel(series: series, xAxis: .init(kind: .category(labels: fixture.categories)))
        model.groups = sample.groups.map { .init(id: $0.id, name: $0.name) }
        let view = chart(LineChartRenderer.self, model: model)
        var selection = CartesianTooltipSampleSelection(); selection.boundaryPolicy = .clamp
        selection.offsetsBySeriesID = Dictionary(uniqueKeysWithValues: sample.series.map { ($0.id, $0.showPrev == true ? -1 : 0) })
        var options = HYMChartTooltipTextOptions(); options.header = "{key}"
        options.cartesian.groupsByBusinessID = true
        var presentation = CartesianTooltipPresentation(); presentation.layout = .columns
        presentation.rowStyleProvider = { datum in
            guard let input = sample.series.first(where: { $0.id == datum.seriesID }) else { return nil }
            let group = sample.groups.first { $0.members.contains(input.id) }
            let name = input.names.flatMap { $0.indices.contains(datum.categoryIndex) ? $0[datum.categoryIndex] : nil }
            return .init(title: name, isHidden: input.hideInTooltip == true || input.hidePoints?.contains(datum.categoryIndex) == true,
                         hidesValue: group?.onlyNameIntooltip == true)
        }
        for index in [0, 10, 11, 12, 47] {
            let data = model.series.indices.compactMap { view.rendererForTesting.datum(series: $0, category: index) }
            let samples = view.rendererForTesting.tooltipSamples(for: data, selection: selection)
            let content = try XCTUnwrap(CartesianTooltipContent.make(samples: samples, options: options,
                presentation: presentation, header: fixture.xSeries[index]))
            let rows = content.sections.flatMap(\.rows)
            XCTAssertFalse(rows.contains { $0.datum?.seriesID == "status" })
            XCTAssertNil(try XCTUnwrap(rows.first { $0.datum?.seriesID == "load" }).value)
            XCTAssertEqual(rows.first { $0.datum?.seriesID == "solar" }?.title, "逆变器 \(index % 3 + 1)")
            let grid = rows.first { $0.datum?.seriesID == "grid" }
            if [10, 11].contains(index) { XCTAssertNil(grid) }
            else {
                XCTAssertEqual(try XCTUnwrap(grid).datum?.categoryIndex, index)
                XCTAssertEqual(grid?.displayedDatum?.categoryIndex, max(0, index - 1))
                XCTAssertEqual(grid?.displayedDatum?.rawValue, sample.series[3].values[max(0, index - 1)])
            }
            XCTAssertTrue(data.allSatisfy { $0.categoryIndex == index })
            XCTAssertEqual(data.count, 4, "提示过滤不改变图形或回调身份")
            XCTAssertEqual(content.header, fixture.xSeries[index])
        }
    }

}
