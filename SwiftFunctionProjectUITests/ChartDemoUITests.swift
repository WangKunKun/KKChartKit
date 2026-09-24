import XCTest

final class ChartDemoUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testFiveSingleEntryPagesAndLiveThemeControls() {
        let app = XCUIApplication()
        app.launch()
        for (name, search, property) in [
            ("雷达图", "showsGridLines", "showsGridLines"),
            ("热力图", "showsRowLabels", "showsRowLabels"),
            ("折线图", "showsPoints", "showsPoints"),
            ("柱状图", "isEnabled", "isEnabled"),
            ("条形图", "showsDataLabels", "showsDataLabels")
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

}
