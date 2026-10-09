import XCTest
@testable import SwiftFunctionProject

final class ChartSpecificationInteractionTests: XCTestCase {
    private func fixture() -> ChartSpecification {
        .init(id: "interaction", domain: .categories([.init(id: "a", label: "A")]), valueAxes: [.init(id: "axis")],
              series: [.init(id: "s", name: "S", mark: .line, valueAxisID: "axis", samples: [])],
              schemaVersion: 6, tooltip: .init(), legend: .init())
    }
    func testV6RoundTripDefaultsEnumsNullAndOlderBytesOmitReservedKeys() throws {
        XCTAssertEqual(ChartSpecification.latestSchemaVersion, 6)
        for layout in ChartTooltipLayout.allCases {
            for position in ChartTooltipPosition.allCases {
                for boundary in ChartTooltipBoundaryPolicy.allCases {
                    for placement in ChartLegendPlacement.allCases {
                        for alignment in ChartLegendRowAlignment.allCases {
                            for overflow in ChartLegendOverflowPolicy.allCases {
                                var s = fixture(); s.tooltip?.layout = layout; s.tooltip?.position = position
                                s.tooltip?.sampleSelection.boundaryPolicy = boundary
                                s.tooltip?.sampleSelection.offset = Int.min
                                s.tooltip?.sampleSelection.offsetsBySeriesID = ["s": Int.max]
                                s.tooltip?.seriesRules = ["s": .init(title: "", isHidden: true, hidesValue: true)]
                                s.legend?.position = placement; s.legend?.alignment = alignment; s.legend?.overflow = overflow
                                s.legend?.titlesBySeriesID = ["s": "图例"]
                                XCTAssertEqual(try ChartSpecification.decodeJSON(s.jsonData()), s)
                            }
                        }
                    }
                }
            }
        }
        var empty = fixture(); empty.tooltip = nil; empty.legend = nil
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: empty.jsonData()) as? [String: Any])
        XCTAssertTrue(object["tooltip"] is NSNull); XCTAssertTrue(object["legend"] is NSNull)
        XCTAssertEqual(try ChartSpecification.decodeJSON(empty.jsonData()), empty)
        for version in 1...5 {
            empty.schemaVersion = version
            let data = try empty.jsonData(), object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertNil(object["tooltip"]); XCTAssertNil(object["legend"])
            XCTAssertEqual(try ChartSpecification.decodeJSON(data), empty)
        }
    }
    func testOldVersionsRejectReservedKeysAndDowngradeEvenDisabledDefaults() throws {
        for version in 1...5 {
            var old = fixture(); old.schemaVersion = version; old.tooltip = nil; old.legend = nil
            for key in ["tooltip", "legend"] {
                for bad in [NSNull(), [:], "bad"] as [Any] {
                    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: old.jsonData()) as? [String: Any]); object[key] = bad
                    let data = try JSONSerialization.data(withJSONObject: object)
                    for decode in [ChartSpecification.decodeJSON, { try JSONDecoder().decode(ChartSpecification.self, from: $0) }] {
                        XCTAssertThrowsError(try decode(data)) { XCTAssertEqual(($0 as? ChartSpecificationError)?.issues.first?.path, key) }
                    }
                }
                var downgraded = old
                if key == "tooltip" { downgraded.tooltip = .init(); downgraded.tooltip?.isEnabled = false }
                else { downgraded.legend = .init(); downgraded.showsLegend = false }
                XCTAssertThrowsError(try downgraded.jsonData()); XCTAssertThrowsError(try JSONEncoder().encode(downgraded))
                XCTAssertTrue(downgraded.validationIssues().contains { $0.path == key })
            }
        }
    }
    func testV6RequiresNullableKeysAndCompleteObjectsAndKnownEnums() throws {
        let data = try fixture().jsonData()
        for key in ["tooltip", "legend"] {
            for bad in [nil, "bad", [:]] as [Any?] {
                var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]); object[key] = bad
                let modified = try JSONSerialization.data(withJSONObject: object)
                XCTAssertThrowsError(try ChartSpecification.decodeJSON(modified))
                XCTAssertThrowsError(try JSONDecoder().decode(ChartSpecification.self, from: modified))
            }
        }
        for word in ["text", "automatic", "omit", "bottom", "center", "scroll"] {
            let bad = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"\(word)\"", with: "\"unknown\"")
            XCTAssertThrowsError(try ChartSpecification.decodeJSON(Data(bad.utf8)))
        }
    }
    func testValidationPathsHiddenReferencesDimensionsAndNumericDomain() {
        func check(_ expected: String, _ modify: (inout ChartSpecification) -> Void) {
            var s = fixture(); modify(&s)
            XCTAssertTrue(s.validationIssues().contains { $0.path == expected }, "\(expected): \(s.validationIssues())")
            XCTAssertThrowsError(try s.jsonData())
        }
        check("tooltip.seriesRules[missing]") { $0.tooltip?.isEnabled = false; $0.tooltip?.seriesRules = ["missing": .init(isHidden: true)] }
        check("tooltip.sampleSelection.offsetsBySeriesID[]") { $0.tooltip?.sampleSelection.offsetsBySeriesID = ["": 0] }
        check("legend.titlesBySeriesID[missing]") { $0.showsLegend = false; $0.legend?.titlesBySeriesID = ["missing": ""] }
        check("legend.maxRows") { $0.legend?.maxRows = 0 }
        for value in [-1, .nan, .infinity, 1e10] {
            check("legend.maxHeight") { $0.legend?.maxHeight = value }
            check("legend.maxWidth") { $0.legend?.maxWidth = value }
        }
        check("tooltip.sampleSelection") { $0.domain = .numeric; $0.tooltip?.sampleSelection.offset = -1 }
        var valid = fixture(); valid.legend?.maxWidth = 0; valid.legend?.maxHeight = 0; valid.legend?.maxRows = Int.max
        XCTAssertTrue(valid.validationIssues().isEmpty)
    }
}
