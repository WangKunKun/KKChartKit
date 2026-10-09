import XCTest

final class LegacyChartDemoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func open(_ identifier: String) {
        let cell = app.cells["scenario.\(identifier)"]
        for _ in 0..<5 where !cell.isHittable { app.tables.firstMatch.swipeUp() }
        XCTAssertTrue(cell.waitForExistence(timeout: 5), identifier)
        cell.tap()
        waitForRender()
    }

    private func waitForRender() {
        let status = app.staticTexts["renderStatus"]
        let ready = NSPredicate(format: "label BEGINSWITH %@", "已渲染")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: status)], timeout: 20), .completed, status.label)
    }

    private func snapshots() throws -> [[String: Any]] {
        let label = app.staticTexts["runtimeDetails"].label
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(label.utf8)) as? [[String: Any]])
    }

    private func firstValue() throws -> Double {
        let chart = try XCTUnwrap(try snapshots().first)
        let series = try XCTUnwrap(chart["series"] as? [[String: Any]])
        return try XCTUnwrap(series.first?["first"] as? NSNumber).doubleValue
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachSnapshot(_ name: String) throws {
        let data = try JSONSerialization.data(withJSONObject: snapshots(), options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func captureJSON(_ name: String) throws -> [String: Any] {
        let text = app.staticTexts["nativeTooltipCapture"].label
        let data = Data(text.utf8)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        return object
    }

    func testSharedAreaAndMixedTypeStackFixtures() throws {
        open("signed")
        for (title, identifier, count) in [("柱", "signed-column", 2), ("面积单组", "area-single", 5),
                                           ("面积多组", "area-multi", 3), ("混合类型", "mixed-types", 2)] {
            app.navigationBars.buttons["配置"].tap()
            app.segmentedControls["auditPreset"].buttons[title].tap()
            waitForRender()
            let series = try XCTUnwrap(try snapshots().first?["series"] as? [[String: Any]])
            XCTAssertEqual(series.count, count)
            if identifier == "area-single" || identifier == "area-multi" {
                XCTAssertEqual(series.filter { ($0["name"] as? String) == "" }.count, 1)
            }
            if identifier == "mixed-types" {
                XCTAssertEqual(series.compactMap { $0["type"] as? String }, ["spline", "area"])
                XCTAssertNotEqual(series[0]["stackKey"] as? String, series[1]["stackKey"] as? String)
                for entry in series {
                    for point in try XCTUnwrap(entry["samples"] as? [[String: Any]]) {
                        XCTAssertEqual(try XCTUnwrap(point["stackY"] as? Double), try XCTUnwrap(point["raw"] as? Double), accuracy: 1e-8)
                    }
                }
            }
            app.navigationBars.buttons["配置"].tap()
            try attachSnapshot("audit-" + identifier); attach("audit-" + identifier)
            if identifier == "area-single" {
                app.navigationBars.buttons["配置"].tap(); app.buttons["reverse"].tap(); waitForRender()
                let reversed = try XCTUnwrap(try snapshots().first?["series"] as? [[String: Any]])
                XCTAssertEqual(reversed.first?["name"] as? String, "辅助功率")
                app.navigationBars.buttons["配置"].tap()
                try attachSnapshot("audit-area-single-reversed"); attach("audit-area-single-reversed")
            }
        }
    }

    func testLegacySplitNullAndCopiedFieldsAreRecorded() throws {
        open("signed")
        app.navigationBars.buttons["配置"].tap(); app.buttons["auditInputs"].tap()
        let result = try captureJSON("audit-input-boundaries")
        for key in ["positive", "negative"] {
            let failure = try XCTUnwrap(result[key] as? [String: Any])
            XCTAssertEqual(failure["exception"] as? String, "NSInvalidArgumentException")
            XCTAssertTrue((failure["reason"] as? String)?.contains("doubleValue") == true)
        }
        let copy = try XCTUnwrap(result["positiveCopy"] as? [String: Any])
        for key in ["hideInTooltip", "hideNameInTooltip", "showPrev", "markerHidden"] { XCTAssertEqual(copy[key] as? Bool, false) }
        XCTAssertTrue(copy["negativeColor"] is NSNull)
    }

    func testBoundaryCrossingAndSourceSwitchSharedInputs() throws {
        open("signed")
        for (button, name) in [("auditCrossing", "boundary-crossing"), ("auditSourceSwitch", "boundary-source-switch")] {
            app.navigationBars.buttons["配置"].tap(); app.buttons[button].tap(); waitForRender()
            let chart = try XCTUnwrap(try snapshots().first)
            XCTAssertEqual(chart["categories"] as? Int, 3)
            let series = try XCTUnwrap(chart["series"] as? [[String: Any]])
            XCTAssertEqual(series.count, 7, "Three inputs split into positive/negative copies plus the legacy helper")
            XCTAssertEqual(series.filter { ($0["name"] as? String) == "" }.count, 1)
            XCTAssertTrue(series.allSatisfy { ($0["count"] as? Int) == 3 })
            app.navigationBars.buttons["配置"].tap()
            try attachSnapshot("legacy-" + name); attach("legacy-" + name)
        }
    }

    func testForcedEmptyMutatesSameModelLegendAndDenseWindowSurvivesFullscreen() throws {
        open("empty"); app.buttons["restoreData"].tap(); waitForRender()
        XCTAssertEqual(try snapshots().first?["modelShowLegend"] as? Bool, true)
        app.buttons["forceEmpty"].tap(); waitForRender()
        app.buttons["forceEmpty"].tap(); waitForRender()
        XCTAssertEqual(try snapshots().first?["modelShowNoData"] as? Bool, false)
        XCTAssertEqual(try snapshots().first?["modelShowLegend"] as? Bool, false)
        try attachSnapshot("audit-empty-toggle-same-model"); attach("audit-empty-toggle-same-model")

        app.terminate(); app.launch(); open("dense")
        XCTAssertEqual(try snapshots().first?["min"] as? Double, 0)
        XCTAssertEqual(try snapshots().first?["max"] as? Double, 96)
        try attachSnapshot("audit-dense-before-fullscreen")
        app.buttons["Enlarge"].tap(); XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 10))
        app.buttons["Restore"].tap()
        app.navigationBars.buttons["配置"].tap(); app.buttons["inspect"].tap(); waitForRender()
        XCTAssertEqual(try snapshots().first?["min"] as? Double, 0)
        XCTAssertEqual(try snapshots().first?["max"] as? Double, 96)
        try attachSnapshot("audit-dense-after-fullscreen")
    }

    func testNativeTooltipContentsDuringHeldGesture() throws {
        open("power")
        for title in ["v1 原生", "v2 原生"] {
            app.segmentedControls["presentation"].buttons[title].tap(); waitForRender()
            app.buttons["captureTooltip"].tap()
            let web = app.webViews.firstMatch
            let start = web.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
            let end = web.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
            start.press(forDuration: 0.3, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 1.5)
            let completed = NSPredicate(format: "label CONTAINS %@", "\"complete\"")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: completed, object: app.staticTexts["nativeTooltipCapture"])], timeout: 15), .completed)
            let snapshot = try captureJSON("audit-held-" + title)
            let frames = try XCTUnwrap(snapshot["frames"] as? [[[String: Any]]])
            XCTAssertFalse(frames.isEmpty, "No visible native tooltip was sampled during the gesture")
            let labels = frames.flatMap { $0 }.flatMap { ($0["labels"] as? [[String: Any]]) ?? [] }.compactMap { $0["text"] as? String }
            XCTAssertTrue(labels.contains { $0.contains("屋顶光伏") })
            XCTAssertTrue(labels.contains { $0.contains("电网功率") })
            // Record the bundled old behavior rather than requiring it to match the new target contract.
            XCTAssertEqual(labels.contains { $0.contains("家庭负载") }, title == "v1 原生")
            XCTAssertEqual((snapshot["after"] as? [Any])?.count, 0)
        }
    }

    // Collect original engine values for the migration comparison; do not impose new engine semantics here.
    func testComparisonCapturesStackValuesGapOptionsAndJSTooltip() throws {
        open("signed")
        try attachSnapshot("comparison-signed-normal")
        app.navigationBars.buttons["配置"].tap()
        app.segmentedControls["stacking"].buttons["百分比"].tap()
        waitForRender()
        XCTAssertEqual(try snapshots().first?["stacking"] as? String, "percent")
        try attachSnapshot("comparison-signed-percent")

        app.terminate(); app.launch()
        open("gaps")
        let series = try XCTUnwrap(try snapshots().first?["series"] as? [[String: Any]])
        XCTAssertEqual((series.first?["nulls"] as? NSNumber)?.intValue, 17)
        try attachSnapshot("comparison-gaps-options")

        app.terminate(); app.launch()
        open("format")
        app.segmentedControls["presentation"].buttons["v1 JS"].tap()
        waitForRender()
        app.buttons["selectPoint"].tap()
        waitForRender()
        try attachSnapshot("comparison-format-programmatic-js")
        attach("comparison-format-programmatic-js")
    }

    func testAllReferenceScenariosRenderRealHighcharts() throws {
        for identifier in ["power", "line", "column", "signed", "legendGroups", "mixed", "gaps", "format", "dense", "empty", "multi"] {
            if identifier != "power" { app.terminate(); app.launch() }
            open(identifier)
            let charts = try snapshots()
            XCTAssertEqual(charts.count, identifier == "multi" ? 3 : 1)
            for chart in charts {
                XCTAssertEqual(chart["version"] as? String, "11.4.3")
                XCTAssertEqual((chart["categories"] as? NSNumber)?.intValue, identifier == "dense" ? 288 : 48)
                XCTAssertGreaterThan((chart["plotHeight"] as? NSNumber)?.doubleValue ?? 0, 0)
            }
            attach("baseline-\(identifier)")
            if identifier == "multi" {
                app.scrollViews.firstMatch.swipeUp()
                attach("baseline-multi-lower-charts")
            }
        }
    }

    func testTooltipVersionsAndLegacyLegendInteraction() throws {
        open("power")
        for title in ["v1 JS", "v1 原生", "v2 JS", "v2 原生"] {
            app.segmentedControls["presentation"].buttons[title].tap()
            waitForRender()
            let container = app.otherElements["chartContainer"]
            container.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.62)).tap()
            attach("tooltip-\(title)")
        }
        // Hittability is evaluated on elements; it is not a supported query predicate key.
        // The bottommost visible name is the old legend, rather than a tooltip row with the same text.
        let matchingNames = app.staticTexts.matching(NSPredicate(format: "label == %@", "屋顶光伏")).allElementsBoundByIndex
        let legend = try XCTUnwrap(matchingNames.filter { $0.isHittable }.max { $0.frame.minY < $1.frame.minY })
        legend.tap()
        XCTAssertTrue(app.staticTexts["eventStatus"].label.contains("隐藏"))
        let reduced = NSPredicate(format: "label CONTAINS %@", "2 系列")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: reduced, object: app.staticTexts["renderStatus"])], timeout: 10), .completed)
        attach("legend-hidden")
    }

    func testFullReloadAndDataOnlyRefreshUseDifferentLegacyPaths() throws {
        open("line")
        let before = try firstValue()
        app.buttons["reload"].tap()
        waitForRender()
        XCTAssertEqual(try firstValue(), before + 125, accuracy: 0.001)
        app.buttons["dataOnly"].tap()
        XCTAssertTrue(app.staticTexts["eventStatus"].label.contains("输入版本 2"))
        // This audits the bundled old implementation: its data-only path retains the manager's packed data.
        app.navigationBars.buttons["配置"].tap()
        app.buttons["inspect"].tap()
        waitForRender()
        XCTAssertEqual(try firstValue(), before + 125, accuracy: 0.001)
        attach("legacy-data-only-retains-packed-data")
    }

    func testEmptyStateRestoresAndZeroValuesRemainData() throws {
        open("empty")
        XCTAssertTrue(app.staticTexts["暂无数据"].exists)
        app.buttons["restoreData"].tap()
        waitForRender()
        XCTAssertEqual((try snapshots().first?["series"] as? [[String: Any]])?.count, 3)
        XCTAssertFalse(app.staticTexts["暂无数据"].isHittable)
        app.buttons["zeroData"].tap()
        waitForRender()
        XCTAssertEqual(try firstValue(), 0)
        XCTAssertFalse(app.staticTexts["暂无数据"].isHittable)
        attach("all-zero-data")
        app.buttons["forceEmpty"].tap()
        waitForRender()
        XCTAssertTrue(app.staticTexts["暂无数据"].isHittable)
        attach("forced-empty-state")
    }

    func testDensityControlsAndOriginalFullscreen() throws {
        open("dense")
        app.navigationBars.buttons["配置"].tap()
        app.segmentedControls["pointCounts"].buttons["1440"].tap()
        waitForRender()
        XCTAssertEqual((try snapshots().first?["categories"] as? NSNumber)?.intValue, 1440)
        app.segmentedControls["pointCounts"].buttons["3000"].tap()
        waitForRender()
        XCTAssertEqual((try snapshots().first?["categories"] as? NSNumber)?.intValue, 3000)
        app.navigationBars.buttons["配置"].tap()
        app.buttons["Enlarge"].tap()
        XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 10))
        attach("legacy-fullscreen")
        app.buttons["Restore"].tap()
        XCTAssertTrue(app.segmentedControls["presentation"].waitForExistence(timeout: 5))
    }

    func testStackingAndThemeControlsUseTheOriginalComponent() throws {
        open("signed")
        app.navigationBars.buttons["配置"].tap()
        app.segmentedControls["stacking"].buttons["百分比"].tap()
        waitForRender()
        XCTAssertEqual(try snapshots().first?["stacking"] as? String, "percent")
        app.buttons["theme"].tap()
        waitForRender()
        attach("signed-percent-theme-change")
        app.segmentedControls["stacking"].buttons["普通堆叠"].tap()
        waitForRender()
        XCTAssertEqual(try snapshots().first?["stacking"] as? String, "normal")
        app.navigationBars.buttons["配置"].tap()
        attach("signed-normal")
    }
}
