import XCTest

final class ChartDemoUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testSingleEntryPagesAndLiveThemeControls() {
        let app = XCUIApplication()
        app.launch()
        for (name, search, property) in [
            ("雷达图", "showsGridLines", "showsGridLines"),
            ("热力图", "showsRowLabels", "showsRowLabels"),
            ("折线图", "showsPoints", "showsPoints"),
            ("柱状图", "isEnabled", "isEnabled"),
            ("条形图", "showsDataLabels", "showsDataLabels"),
            ("混合图", "showsPoints", "showsPoints")
        ] {
            let entry = app.buttons[name]
            XCTAssertTrue(entry.waitForExistence(timeout: 5), name)
            entry.tap()
            let searchField = app.textFields["搜索属性名或分组"]
            XCTAssertTrue(searchField.waitForExistence(timeout: 5))
            searchField.tap(); searchField.typeText(search + "\n")
            let toggle = app.switches[property].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), property)
            if !toggle.isHittable { app.swipeUp() }
            let previous = toggle.value as? String
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertNotEqual(previous, toggle.value as? String)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "demo-\(name)-live-property"; attachment.lifetime = .keepAlways; add(attachment)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        XCTAssertFalse(app.buttons["高密度时间序列（288–3000 点）"].exists)
        XCTAssertFalse(app.buttons["内置图例与布局"].exists)
    }

    @MainActor func testColumnDensityPresetAndReset() {
        let app = XCUIApplication(); app.launch(); app.buttons["柱状图"].tap()
        let field = app.textFields["搜索属性名或分组"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("3000\n")
        let preset = app.buttons["3000 点压力场景"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
        app.buttons["最近24点"].tap()
        let detail = XCTAttachment(screenshot: app.screenshot()); detail.name = "demo-column-density-detail"; detail.lifetime = .keepAlways; add(detail)
        app.buttons["总览"].tap()
        let overview = XCTAttachment(screenshot: app.screenshot()); overview.name = "demo-column-density-overview"; overview.lifetime = .keepAlways; add(overview)
        let reset = app.buttons["demo.reset"]
        if !reset.isHittable { app.swipeUp() }
        reset.tap()
        for _ in 0..<4 where !field.exists { app.collectionViews.firstMatch.swipeDown() }
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "搜索属性名或分组")
    }
    @MainActor func testLineMinMaxPresetToggleAndDetail() {
        let app = XCUIApplication(); app.launch(); app.buttons["折线图"].tap()
        let field = app.textFields["搜索属性名或分组"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("3000 点尖峰\n")
        let preset = app.buttons["3000 点尖峰降采样场景"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
        let overview = XCTAttachment(screenshot: app.screenshot()); overview.name = "demo-line-minmax-overview"; overview.lifetime = .keepAlways; add(overview)
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + "启用 Min/Max\n")
        let toggle = app.switches["启用 Min/Max 降采样（非堆叠直线）"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + "查看尖峰\n")
        let detailButton = app.buttons["查看尖峰附近原始点"]
        XCTAssertTrue(detailButton.waitForExistence(timeout: 5)); detailButton.tap()
        let detail = XCTAttachment(screenshot: app.screenshot()); detail.name = "demo-line-minmax-detail"; detail.lifetime = .keepAlways; add(detail)
        app.buttons["总览"].tap()
    }

    @MainActor func testCartesianReuseToggleIsLiveOnEachPage() {
        let app = XCUIApplication(); app.launch()
        for name in ["折线图", "柱状图", "条形图"] {
            app.buttons[name].tap()
            let field = app.textFields["搜索属性名或分组"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap(); field.typeText("reusesRenderingObjects\n")
            let toggle = app.switches["复用图层与标签 reusesRenderingObjects"].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            XCTAssertEqual(toggle.value as? String, "1")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "1")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "demo-\(name)-render-reuse"; attachment.lifetime = .keepAlways; add(attachment)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    @MainActor func testFixedDimensionsPresetScrollsAndAllowsManualRange() {
        let app = XCUIApplication(); app.launch()
        for name in ["柱状图", "条形图"] {
            app.buttons[name].tap()
            let field = app.textFields["搜索属性名或分组"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap(); field.typeText("固定尺寸滚动示例\n")
            let preset = app.buttons["固定尺寸滚动示例（60点 × 3系列）"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            XCTAssertTrue(app.staticTexts["00:00"].firstMatch.waitForExistence(timeout: 5))
            let before = XCTAttachment(screenshot: app.screenshot())
            before.name = "fixed-\(name)-earliest"; before.lifetime = .keepAlways; add(before)
            let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
            XCTAssertTrue(chart.waitForExistence(timeout: 5))
            let start = chart.coordinate(withNormalizedOffset: name == "柱状图" ? CGVector(dx: 0.8, dy: 0.5) : CGVector(dx: 0.6, dy: 0.8))
            let end = chart.coordinate(withNormalizedOffset: name == "柱状图" ? CGVector(dx: 0.2, dy: 0.5) : CGVector(dx: 0.6, dy: 0.2))
            start.press(forDuration: 0.1, thenDragTo: end)
            let after = XCTAttachment(screenshot: app.screenshot())
            after.name = "fixed-\(name)-scrolled"; after.lifetime = .keepAlways; add(after)
            XCTAssertFalse(app.staticTexts["00:00"].exists)
            app.buttons["最近24点"].tap()
            let located = XCTAttachment(screenshot: app.screenshot())
            located.name = "fixed-\(name)-manual-range"; located.lifetime = .keepAlways; add(located)
            app.buttons["总览"].tap()
            XCTAssertTrue(app.staticTexts["00:00"].firstMatch.waitForExistence(timeout: 5))
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    @MainActor func testSemanticPresetAndFormatPanelAreLive() {
        let app = XCUIApplication(); app.launch(); app.buttons["柱状图"].tap()
        let field = app.textFields["搜索属性名或分组"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("数据语义\n")
        let preset = app.buttons["数据语义：100 + 50 堆叠"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
        let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
        let readout = app.staticTexts["demo.hit"]
        XCTAssertTrue(readout.label.contains("原值"), readout.label)
        XCTAssertTrue(readout.label.contains("能源"), readout.label)
        let evidence = XCTAttachment(screenshot: app.screenshot())
        evidence.name = "semantic-stacked-hit"; evidence.lifetime = .keepAlways; add(evidence)
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + "仅展示绝对值\n")
        let toggle = app.switches["仅展示绝对值"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
    }

    @MainActor func testObjectiveCCartesianCallbackForAllKinds() {
        let app = XCUIApplication(); app.launch(); app.buttons["Objective-C 接入"].tap()
        XCTAssertTrue(app.buttons["轴系验证"].waitForExistence(timeout: 5))
        app.buttons["轴系验证"].tap()
        let selector = app.segmentedControls["oc.cartesian.kind"]
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
        for kind in ["柱状", "折线", "条形", "混合"] {
            selector.buttons[kind].tap()
            let chart = app.descendants(matching: .any)["oc.cartesian.chart"].firstMatch
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.4)).tap()
            let readout = app.staticTexts["oc.cartesian.hit"]
            XCTAssertTrue(readout.label.contains("raw="), readout.label)
            XCTAssertTrue(readout.label.contains("draw="), readout.label)
            let evidence = XCTAttachment(screenshot: app.screenshot())
            evidence.name = "oc-semantic-" + kind; evidence.lifetime = .keepAlways; add(evidence)
        }
    }

    @MainActor func testCombinedGroupsPresetAndIndependentStylePanel() {
        let app = XCUIApplication(); app.launch(); app.buttons["混合图"].tap()
        let field = app.textFields["搜索属性名或分组"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("两组堆叠\n")
        let preset = app.buttons["两组堆叠与目标线"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
        let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4)).tap()
        XCTAssertTrue(app.staticTexts["demo.hit"].label.contains("原值"))
        let grouped = XCTAttachment(screenshot: app.screenshot()); grouped.name = "combined-grouped-dual-axis"
        grouped.lifetime = .keepAlways; add(grouped)
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + "自定义系列线宽\n")
        let toggle = app.switches["自定义系列线宽"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
    }

}
