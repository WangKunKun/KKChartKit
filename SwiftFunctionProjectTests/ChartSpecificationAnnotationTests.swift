import XCTest
import UIKit
@testable import SwiftFunctionProject

final class ChartSpecificationAnnotationTests: XCTestCase {
    private func fixture() -> ChartSpecification {
        .init(id: "annotations", domain: .categories([.init(id: "a", label: "A")]),
              valueAxes: [.init(id: "power")], series: [], schemaVersion: 5,
              plotLines: [.init(id: "limit", valueAxisID: "power", value: 40, label: "上限")],
              plotBands: [.init(id: "range", valueAxisID: "power", from: -20, to: 20, label: "范围")])
    }

    func testV5RoundTripAllLabelEnumsVisibilityAndEmptyArrays() throws {
        XCTAssertGreaterThanOrEqual(ChartSpecification.latestSchemaVersion, 5)
        for weight in ChartFontWeight.allCases {
            for alignment in ChartAnnotationAlignment.allCases {
                for vertical in ChartAnnotationVerticalAlignment.allCases {
                    for bounds in ChartAnnotationBounds.allCases {
                        var value = fixture()
                        value.plotLines[0].isVisible = false
                        value.plotLines[0].labelStyle = .init(fontSize: 17, fontWeight: weight,
                            alignment: alignment, verticalAlignment: vertical, offsetX: -9, offsetY: 8, bounds: bounds)
                        value.plotBands[0].color = .init(red: 0, green: 1, blue: 0, alpha: 0.2)
                        XCTAssertEqual(try ChartSpecification.decodeJSON(value.jsonData()), value)
                    }
                }
            }
        }
        var value = fixture(); value.plotLines = []; value.plotBands = []
        XCTAssertEqual(try ChartSpecification.decodeJSON(value.jsonData()), value)
        for version in 1...4 {
            value.schemaVersion = version
            let data = try value.jsonData()
            XCTAssertEqual(try ChartSpecification.decodeJSON(data), value)
            XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("plotLines"))
            XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("plotBands"))
        }
    }

    func testOlderVersionsRejectReservedKeysEvenEmptyNullOrMalformed() throws {
        for version in 1...4 {
            var value = fixture(); value.plotLines = []; value.plotBands = []; value.schemaVersion = version
            for key in ["plotLines", "plotBands"] {
                for bad in [NSNull(), [], "bad"] as [Any] {
                    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: value.jsonData()) as? [String: Any])
                    object[key] = bad
                    let data = try JSONSerialization.data(withJSONObject: object)
                    for decode in [ChartSpecification.decodeJSON, { try JSONDecoder().decode(ChartSpecification.self, from: $0) }] {
                        XCTAssertThrowsError(try decode(data)) { error in
                            XCTAssertEqual((error as? ChartSpecificationError)?.issues.first?.path, key)
                        }
                    }
                }
            }
            for key in ["plotLines", "plotBands"] {
                var downgraded = fixture(); downgraded.schemaVersion = version
                if key == "plotLines" { downgraded.plotBands = [] } else { downgraded.plotLines = [] }
                XCTAssertTrue(downgraded.validationIssues().contains { $0.path == key })
                XCTAssertThrowsError(try downgraded.jsonData())
                XCTAssertThrowsError(try JSONEncoder().encode(downgraded))
            }
        }
    }

    func testV5RequiresArraysAndRejectsMalformedOrUnknownAnnotationEnums() throws {
        let data = try fixture().jsonData()
        for key in ["plotLines", "plotBands"] {
            for bad in [nil, NSNull(), "bad"] as [Any?] {
                var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                object[key] = bad
                XCTAssertThrowsError(try ChartSpecification.decodeJSON(JSONSerialization.data(withJSONObject: object)))
            }
        }
        for (from, to) in [("automatic", "mysteryAlignment"), ("clamp", "mysteryBounds"), ("solid", "mysteryStroke")] {
            let bad = String(decoding: data, as: UTF8.self).replacingOccurrences(of: from, with: to)
            XCTAssertThrowsError(try ChartSpecification.decodeJSON(Data(bad.utf8)))
        }
    }

    func testInvalidIdentityAxisRangeAndHiddenValuesReportExactPaths() throws {
        let changes: [(String, (inout ChartSpecification) -> Void)] = [
            ("plotLines[0].id", { $0.plotLines[0].id = " " }),
            ("plotBands[0].id", { $0.plotBands[0].id = "limit" }),
            ("plotLines[0].valueAxisID", { $0.plotLines[0].valueAxisID = "domain" }),
            ("plotBands[0].valueAxisID", { $0.plotBands[0].valueAxisID = "missing" }),
            ("plotLines[0].value", { $0.plotLines[0].value = .infinity; $0.plotLines[0].isVisible = false }),
            ("plotBands[0].from", { $0.plotBands[0].from = .nan }),
            ("plotBands[0].to", { $0.plotBands[0].to = -.infinity }),
            ("plotBands[0]", { $0.plotBands[0].from = $0.plotBands[0].to }),
            ("plotBands[0]", { $0.plotBands[0].from = 21 }),
            ("plotLines[0].lineWidth", { $0.plotLines[0].lineWidth = -1 }),
            ("plotLines[0].color", { $0.plotLines[0].color = .init(red: 2, green: 0, blue: 0) }),
            ("plotBands[0].labelStyle.fontSize", { $0.plotBands[0].labelStyle.fontSize = 0 }),
            ("plotBands[0].labelStyle.offsetX", { $0.plotBands[0].labelStyle.offsetX = .nan }),
            ("plotBands[0].labelStyle.offsetY", { $0.plotBands[0].labelStyle.offsetY = 1e10 }),
            ("plotBands[0].labelStyle.backgroundColor", { $0.plotBands[0].labelStyle.backgroundColor = .init(red: 0, green: 0, blue: 0, alpha: -1) })
        ]
        for (path, change) in changes {
            var value = fixture(); change(&value)
            XCTAssertTrue(value.validationIssues().contains { $0.path == path }, path)
            XCTAssertThrowsError(try value.jsonData(), path)
        }
        var value = fixture(); value.plotLines[0].value = 1e100
        value.plotBands[0].from = -1e100; value.plotBands[0].to = 1e100
        XCTAssertNoThrow(try value.validate()) // Outside the domain is valid, not auto-expansion.
    }
}
