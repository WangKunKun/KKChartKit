import XCTest

final class ChartDemoUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func revealSpecificationControl(_ element: XCUIElement, in app: XCUIApplication) {
        // The preview is fixed above a short Form. A hittable, clipped row is
        // not enough: keep the complete switch/button inside the Form.
        let height = app.frame.height
        for attempt in 0..<16 {
            let exists = element.exists
            let frame = exists ? element.frame : .zero
            if exists && element.isHittable && frame.minY > height * 0.55 && frame.maxY < height * 0.95 { return }
            let down = exists && frame != .zero ? frame.minY < height * 0.55 : attempt >= 8
            let start = app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: down ? 0.62 : 0.87))
            let end = app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: down ? 0.87 : 0.62))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("Could not fully reveal \(element.identifier)")
    }

    @MainActor func testNeutralSpecificationPreviewAndUnsupportedCapabilityRecovery() {
        let app = XCUIApplication(); app.launch()
        for name in ["折线图", "混合图"] {
            app.buttons[name].tap()
            let entry = app.buttons["demo.specification"]
            XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
            XCTAssertTrue(app.staticTexts["specification.success"].waitForExistence(timeout: 5))
            let before = XCTAttachment(screenshot: app.screenshot())
            before.name = "specification-\(name)"; before.lifetime = .keepAlways; add(before)
            let numeric = app.switches["specification.numeric"]
            for _ in 0..<8 where !numeric.isHittable { app.swipeUp() }
            XCTAssertTrue(numeric.isHittable)
            numeric.coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.5)).tap()
            XCTAssertFalse(app.staticTexts["specification.success"].exists)
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "真实数值/时间坐标尚未接入")).firstMatch.waitForExistence(timeout: 5))
            numeric.coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.5)).tap()
            XCTAssertTrue(app.staticTexts["specification.success"].waitForExistence(timeout: 5))
            entry.tap()
            XCTAssertTrue(app.textFields["demo.search"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    @MainActor func testNeutralG1BoundarySwitchAndResetInExistingPages() {
        let app = XCUIApplication(); app.launch()
        for name in ["折线图", "混合图"] {
            app.buttons[name].tap()
            let entry = app.buttons["demo.specification"]
            XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
            let status = app.staticTexts["specification.boundaryStatus"]
            XCTAssertTrue(status.waitForExistence(timeout: 5))
            XCTAssertTrue(status.label.contains("v1 · independent"))
            let picker = app.segmentedControls["specification.boundary"]
            for _ in 0..<5 where !picker.isHittable { app.swipeUp() }
            XCTAssertTrue(picker.isHittable)
            for (label, mode) in [("正负分链", "diverging"), ("沿基线", "followBaseline"), ("独立插值", "independent")] {
                picker.buttons[label].tap()
                XCTAssertTrue(status.label.contains(mode), status.label)
                XCTAssertTrue(app.staticTexts["specification.success"].exists)
                if mode == "diverging" {
                    let image = XCTAttachment(screenshot: app.screenshot())
                    image.name = "neutral-g1-v2-\(name)"; image.lifetime = .keepAlways; add(image)
                }
            }
            picker.buttons["正负分链"].tap()
            let reset = app.buttons["specification.reset"]
            for _ in 0..<5 where !reset.isHittable { app.swipeUp() }
            XCTAssertTrue(reset.isHittable); reset.tap()
            XCTAssertTrue(status.label.contains("v1 · independent"), status.label)
            entry.tap(); app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    @MainActor func testNeutralValueColorZonesPerSeriesSourceAndResetOnFourPages() {
        let app = XCUIApplication()
        for name in ["折线图", "柱状图", "条形图", "混合图"] {
            app.launch(); app.buttons[name].tap(); app.buttons["demo.specification"].tap()
            let schema = app.staticTexts["specification.boundaryStatus"]
            let status = app.staticTexts["specification.zoneStatus"]
            XCTAssertTrue(schema.waitForExistence(timeout: 5)); XCTAssertTrue(schema.label.contains("v1"))
            if name == "折线图" || name == "混合图" {
                let boundary = app.segmentedControls["specification.boundary"]
                revealSpecificationControl(boundary, in: app)
                boundary.buttons["正负分链"].tap()
            }
            let enabled = app.switches["specification.zones"]
            revealSpecificationControl(enabled, in: app)
            XCTAssertTrue(enabled.isHittable)
            enabled.coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.5)).tap()
            XCTAssertTrue(schema.label.contains("v3")); XCTAssertTrue(status.label.contains("source-0 · drawValue"))
            let series = app.buttons["specification.zoneSeries"]
            revealSpecificationControl(series, in: app)
            series.tap(); app.buttons["source-1"].tap()
            XCTAssertTrue(status.label.contains("source-1 · 关闭"))
            series.tap(); app.buttons["source-0"].tap()
            XCTAssertTrue(status.label.contains("source-0 · drawValue"))
            if name != "折线图" {
                let source = app.segmentedControls["specification.zoneSource"]
                revealSpecificationControl(source, in: app)
                XCTAssertTrue(source.isHittable); source.buttons["原始值"].tap()
                XCTAssertTrue(status.label.contains("rawValue"))
                auditEvidence("neutral-v3-raw-" + name, in: app)
                source.buttons["绘制值"].tap(); XCTAssertTrue(status.label.contains("drawValue"))
            }
            XCTAssertTrue(app.staticTexts["specification.success"].exists)
            auditEvidence("neutral-v3-draw-" + name, in: app)
            let reset = app.buttons["specification.reset"]
            revealSpecificationControl(reset, in: app)
            XCTAssertTrue(reset.isHittable); reset.tap()
            XCTAssertTrue(schema.label.contains("v1 · independent"))
            XCTAssertTrue(status.label.contains("source-0 · 关闭"))
            XCTAssertTrue(app.staticTexts["specification.success"].exists)
            app.terminate()
        }
    }

    @MainActor func testNeutralAxisPresentationPerAxisAndResetOnFourPages() {
        let app = XCUIApplication()
        func reveal(_ element: XCUIElement) { revealSpecificationControl(element, in: app) }
        func toggle(_ identifier: String) {
            let element = app.switches[identifier]; reveal(element)
            let before = element.value as? String ?? ""
            element.coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.5)).tap()
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", before), object: element)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed, identifier)
        }
        func select(_ identifier: String, _ value: String) {
            let element = app.buttons[identifier]; reveal(element); element.tap()
            app.buttons[value].firstMatch.tap()
        }
        for name in ["折线图", "柱状图", "条形图", "混合图"] {
            app.launch(); app.buttons[name].tap(); app.buttons["demo.specification"].tap()
            let schema = app.staticTexts["specification.boundaryStatus"]
            let status = app.staticTexts["specification.axisStatus"]
            XCTAssertTrue(schema.waitForExistence(timeout: 5)); XCTAssertTrue(schema.label.contains("v1"))
            XCTAssertTrue(status.label.contains("power · ticks=自动 · format=默认 · font=默认"))
            toggle("specification.axisTicks"); toggle("specification.axisFormat")
            select("specification.axisWeight", "bold")
            XCTAssertTrue(schema.label.contains("v4"))
            XCTAssertTrue(status.label.contains("power · ticks=显式 · format=单位 · font=bold"), status.label)
            if name != "条形图" {
                toggle("specification.secondaryAxis")
                select("specification.axisSelection", "temperature")
                XCTAssertTrue(status.label.contains("temperature · ticks=自动 · format=默认 · font=默认"))
                toggle("specification.axisTicks"); toggle("specification.axisFormat")
                select("specification.axisWeight", "light")
                XCTAssertTrue(status.label.contains("temperature · ticks=显式 · format=单位 · font=light"), status.label)
            }
            select("specification.axisSelection", "domain")
            toggle("specification.categoryInterval"); select("specification.axisWeight", "medium")
            select("specification.axisSelection", "power")
            XCTAssertTrue(status.label.contains("power · ticks=显式 · format=单位 · font=bold"), status.label)
            XCTAssertTrue(app.staticTexts["specification.success"].exists)
            auditEvidence("neutral-v4-axes-" + name, in: app)
            let reset = app.buttons["specification.reset"]; reveal(reset); reset.tap()
            XCTAssertTrue(schema.label.contains("v1 · independent"))
            XCTAssertTrue(status.label.contains("power · ticks=自动 · format=默认 · font=默认"))
            XCTAssertTrue(app.staticTexts["specification.success"].exists)
            app.terminate()
        }
    }

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

    @MainActor func testLineTargetPointCountInputLiveCountsAndModePriority() {
        let app = XCUIApplication(); app.launch(); app.buttons["折线图"].tap()
        auditSearch("3000 点目标", in: app)
        let preset = app.buttons["3000 点目标点数采样场景"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
        let counts = app.staticTexts["demo.lineSamplingCounts"]
        func expectCounts(_ text: String) {
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: counts)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, text)
        }
        expectCounts("可见 3000 → 绘制 200")
        auditSearch("每系列目标绘制点数", in: app)
        let input = app.textFields["demo.input.每系列目标绘制点数 targetPointCount"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "50\n")
        expectCounts("可见 3000 → 绘制 50")
        XCTAssertEqual(input.value as? String, "50")
        auditEvidence("line-target-exact-50", in: app)
        app.buttons["最近24点"].tap(); expectCounts("不足目标，不补点")
        app.buttons["总览"].tap(); expectCounts("可见 3000 → 绘制 50")
        auditSearch("bucketWidth", in: app)
        XCTAssertFalse(app.sliders.firstMatch.isEnabled)
        auditSearch("minimumVisiblePoints", in: app)
        XCTAssertFalse(app.sliders.firstMatch.isEnabled)
        auditSearch("按目标点数采样", in: app); auditToggle("按目标点数采样 targetPointCount", in: app)
        auditSearch("bucketWidth", in: app)
        XCTAssertTrue(app.sliders.firstMatch.isEnabled)
        // 原尖峰场景每 13 点缺测一次；目标 200 小于分段保护点数，必须说明超额而非静默失效。
        auditSearch("3000 点尖峰", in: app); app.buttons["3000 点尖峰降采样场景"].tap()
        auditSearch("按目标点数采样", in: app); auditToggle("按目标点数采样 targetPointCount", in: app)
        expectCounts("已超目标")
        auditEvidence("line-target-gap-protection-overflow", in: app)
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
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); XCTAssertTrue(toggle.isEnabled)
        let initial = toggle.value as? String
        XCTAssertTrue(initial == "0" || initial == "1")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, initial == "1" ? "0" : "1")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, initial)
    }

    @MainActor func testAutoGapPresetAndPolicyPickerOnLineAndCombined() {
        let app = XCUIApplication()
        for page in ["折线图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            let search = app.textFields["搜索属性名或分组"]
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap(); search.typeText("autoGap\n")
            let preset = app.buttons["11/12/13 空点 autoGap 场景"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "缺测策略 autoGap")).firstMatch
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            XCTAssertTrue(picker.label.contains("按空点数量"), picker.label)
            for mode in ["全部断开", "全部连接", "按缺测时长", "跟随跨空值连线"] {
                picker.tap(); app.buttons[mode].tap()
                XCTAssertTrue(picker.label.contains(mode), picker.label)
            }
            picker.tap(); app.buttons["按空点数量"].tap()
            let evidence = XCTAttachment(screenshot: app.screenshot())
            evidence.name = "auto-gap-11-12-13-" + page
            evidence.lifetime = .keepAlways; add(evidence)
        }
    }

    @MainActor func testColorZonesAndSmoothNegativePresetsOnLineAndCombined() {
        let app = XCUIApplication()
        for page in ["折线图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            let field = app.textFields["搜索属性名或分组"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            func search(_ query: String) {
                if !field.isHittable { app.collectionViews.firstMatch.swipeDown() }
                let current = field.value as? String ?? ""
                // 使用短关键词，避免长文本点中间时将光标放在词中。
                field.tap()
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                      count: current == "搜索属性名或分组" ? 0 : current.count) + query + "\n")
                XCTAssertEqual(field.value as? String, query)
            }
            for (query, preset) in [("X 分区", "X 分区曲线面积 zones 场景"),
                                    ("Y 分区", "Y 分区曲线面积 zones 场景"),
                                    ("曲线负值", "曲线负值换色 zones 场景")] {
                search(query)
                let button = app.buttons[preset]
                XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
                let evidence = XCTAttachment(screenshot: app.screenshot())
                evidence.name = page + "-" + preset; evidence.lifetime = .keepAlways; add(evidence)
            }
            search("颜色分区")
            let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "颜色分区 zones")).firstMatch
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            XCTAssertTrue(picker.label.contains("关闭"))
            for mode in ["X 原始索引", "Y 绘制值", "关闭"] {
                picker.tap(); app.buttons[mode].tap()
                XCTAssertTrue(picker.label.contains(mode), picker.label)
            }
            picker.tap(); app.buttons["X 原始索引"].tap()
            search("分区面积")
            let fill = app.switches["分区面积渐变"].firstMatch
            XCTAssertTrue(fill.waitForExistence(timeout: 5))
            fill.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertEqual(fill.value as? String, "1")
            fill.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertEqual(fill.value as? String, "0")
        }
    }


    @MainActor func testColumnColorZonesPresetValueSourceAndDisableOnThreePages() {
        let app = XCUIApplication()
        for page in ["柱状图", "条形图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch("柱条阈值", in: app)
            let preset = app.buttons["柱条阈值整段换色场景"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            auditEvidence("g2-raw-" + page, in: app)
            auditSearch("取色依据", in: app)
            let source = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "柱/条 Y 取色依据")).firstMatch
            XCTAssertTrue(source.waitForExistence(timeout: 5)); XCTAssertTrue(source.label.contains("原值（聚合后）"))
            source.tap(); app.buttons["累计绘制值"].tap()
            XCTAssertTrue(source.label.contains("累计绘制值"))
            auditEvidence("g2-draw-" + page, in: app)
            auditSearch("颜色分区 zones", in: app)
            let mode = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "颜色分区 zones")).firstMatch
            XCTAssertTrue(mode.waitForExistence(timeout: 5))
            for option in ["关闭", "X 原始索引", "Y 数值"] {
                mode.tap(); app.buttons[option].tap()
                let updated = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "颜色分区 zones", option)).firstMatch
                XCTAssertTrue(updated.waitForExistence(timeout: 5))
            }
            auditEvidence("g2-restored-" + page, in: app)
        }
    }

    @MainActor func testAnnotationPresetBoundsAndLabelAvoidanceOnFourPages() {
        let app = XCUIApplication()
        for page in ["折线图", "柱状图", "条形图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch("参考线色带", in: app)
            let preset = app.buttons["参考线色带与标签避让场景"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            auditEvidence("g4-annotations-" + page, in: app)
            auditSearch("参考线标签越界策略", in: app)
            let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "参考线标签越界策略")).firstMatch
            XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.tap(); app.buttons["越界隐藏"].tap()
            XCTAssertTrue(picker.label.contains("越界隐藏"))
            auditSearch("dataLabelAvoidsOverlap", in: app)
            auditToggle("dataLabelAvoidsOverlap 标签避让", in: app)
            XCTAssertEqual(app.switches["dataLabelAvoidsOverlap 标签避让"].firstMatch.value as? String, "0")
            auditEvidence("g4-without-avoidance-" + page, in: app)
        }
    }

    @MainActor func testBodySelectionPresetSharedHitAndDisableOnFourPages() {
        let app = XCUIApplication()
        for page in ["折线图", "柱状图", "条形图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch("点柱条与共享", in: app)
            let preset = app.buttons["点柱条与共享选中高亮场景"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.4)).tap()
            XCTAssertTrue(app.staticTexts["demo.hit"].label.contains("原值"))
            auditEvidence("g5-selected-" + page, in: app)
            auditSearch("selection 主体选中高亮", in: app)
            auditToggle("selection 主体选中高亮", in: app)
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.4)).tap()
            XCTAssertTrue(app.staticTexts["demo.hit"].label.contains("原值"))
            XCTAssertEqual(app.switches["selection 主体选中高亮"].firstMatch.value as? String, "0")
            auditEvidence("g5-disabled-" + page, in: app)
        }
    }

    @MainActor func testIndependentAxesPresetVisibilityAndRotationOnFourPages() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        for page in ["折线图", "柱状图", "条形图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch("独立轴", in: app)
            let preset = app.buttons["独立轴颜色字体与标签步长场景"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            auditEvidence("g3-styled-" + page, in: app)
            auditSearch("轴标签显示", in: app)
            auditToggle("轴标签显示", in: app)
            auditEvidence("g3-hidden-category-" + page, in: app)
            auditToggle("轴标签显示", in: app)
            XCUIDevice.shared.orientation = .landscapeLeft
            auditStableChartLayout(in: app, landscape: true)
            // A device screenshot includes the final oriented surface; app snapshots can
            // capture a cropped portrait window while the rotation transaction commits.
            let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            landscape.name = "g3-landscape-" + page
            landscape.lifetime = .keepAlways; add(landscape)
            XCUIDevice.shared.orientation = .portrait
            auditStableChartLayout(in: app, landscape: false)
            app.terminate()
        }
    }

    @MainActor private func auditStableChartLayout(in app: XCUIApplication, landscape: Bool) {
        let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
        var previousWindow = CGRect.zero
        var previousChart = CGRect.zero
        var stableReadings = 0
        let settled = NSPredicate { _, _ in
            guard chart.exists else { return false }
            let window = app.windows.firstMatch.frame
            let frame = chart.frame
            guard (window.width > window.height) == landscape,
                  frame.width > window.width * 0.75, frame.height > 40,
                  window.insetBy(dx: -1, dy: -1).contains(frame) else { return false }
            stableReadings = window == previousWindow && frame == previousChart ? stableReadings + 1 : 0
            previousWindow = window; previousChart = frame
            return stableReadings >= 2
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 10)
        XCTAssertEqual(result, .completed, "Chart must settle inside the full oriented window: window=\(app.windows.firstMatch.frame), chart=\(chart.frame)")
    }

    @MainActor private func auditSearch(_ query: String, in app: XCUIApplication) {
        let field = app.textFields["demo.search"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let old = field.value as? String ?? ""
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old == "搜索属性名或分组" ? 0 : old.count) + query + "\n")
    }
    @MainActor private func auditToggle(_ label: String, in app: XCUIApplication) {
        let toggle = app.switches[label].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if !toggle.isHittable { app.collectionViews.firstMatch.swipeUp() }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }
    @MainActor private func auditEvidence(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor func testStackedAreaSeamPresetInLineAndCombinedDemos() {
        let app = XCUIApplication()
        for page in ["折线图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch("接缝", in: app)
            let preset = app.buttons["正负与缺测堆叠面积接缝场景"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            auditSearch("当前状态", in: app)
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "实际最长 12 点")).firstMatch.exists)
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "当前边界模式：独立插值（兼容）")).firstMatch.exists)
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "下层仍断开、不补业务点；缺口不保证全域无缝")).firstMatch.exists)
            auditEvidence("stacked-area-seams-" + page, in: app)
            auditSearch("系列线宽", in: app)
            auditToggle("自定义系列线宽", in: app)
            XCTAssertEqual(app.switches["自定义系列线宽"].firstMatch.value as? String, "1")
            app.buttons["恢复默认配置"].tap()
            auditSearch("当前状态", in: app)
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "实际最长 24 点")).firstMatch.exists)
            app.terminate()
        }
    }

    @MainActor func testThinStackedAreaBoundaryComparisonInBothDemos() {
        auditStackedAreaComparison(query: "薄层", preset: "薄层混合线型面积对照场景", evidence: "thin-area")
    }

    @MainActor func testCrossingStackedAreaBoundaryComparisonInBothDemos() {
        auditStackedAreaComparison(query: "跨零正负", preset: "跨零正负基线面积对照场景", evidence: "crossing-area")
    }

    @MainActor func testSourceSwitchStackedAreaBoundaryComparisonInBothDemos() {
        auditStackedAreaComparison(query: "前层换链", preset: "前层换链面积对照场景", evidence: "source-switch-area")
    }

    @MainActor func testGapBoundaryStackedAreaComparisonInBothDemos() {
        auditStackedAreaComparison(query: "缺测底边", preset: "缺测底边分段面积对照场景", evidence: "gap-boundary-area")
    }

    @MainActor func testPercentStackedAreaComparisonInBothDemos() {
        auditStackedAreaComparison(query: "百分比面积", preset: "自动百分比面积对照场景", evidence: "percent-area")
    }

    @MainActor private func auditStackedAreaComparison(query: String, preset: String, evidence: String) {
        let app = XCUIApplication()
        for page in ["折线图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch(query, in: app)
            let button = app.buttons[preset]
            XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
            auditSearch("当前状态", in: app)
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "当前边界模式：沿基线叠加")).firstMatch.exists)
            auditEvidence(evidence + "-follow-baseline-" + page, in: app)
            if evidence == "crossing-area" {
                auditSearch("showsPoints", in: app)
                auditToggle("showsPoints", in: app)
                auditSearch("当前状态", in: app)
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "描边收在各自面积内")).firstMatch.exists)
                auditEvidence(evidence + "-no-markers-" + page, in: app)
            }
            auditSearch("堆叠面积边界", in: app)
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "stackedAreaBoundaryMode")).firstMatch.tap()
            app.buttons["独立插值（兼容）"].tap()
            auditSearch("当前状态", in: app)
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "当前边界模式：独立插值（兼容）")).firstMatch.exists)
            auditEvidence(evidence + "-independent-" + page, in: app)
            let reset = app.buttons["恢复默认配置"]
            for _ in 0..<3 where !reset.isHittable { app.collectionViews.firstMatch.swipeUp() }
            XCTAssertTrue(reset.waitForExistence(timeout: 5)); reset.tap()
            auditSearch("当前状态", in: app)
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "实际最长 24 点")).firstMatch.exists)
            app.terminate()
        }
    }

    @MainActor func testDivergingStackPresetDiagnosticsAndGapControlsRecover() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        for page in ["折线图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch("正负分链", in: app)
            app.buttons["正负分链统一断段场景"].tap()
            let diagnostic = app.staticTexts["demo.stackBoundaryCounts"]
            XCTAssertTrue(diagnostic.waitForExistence(timeout: 5))
            XCTAssertTrue(diagnostic.label.contains("参与 3 个系列"))
            XCTAssertTrue(diagnostic.label.contains("未采用共享直线降级"))
            auditSearch("当前状态", in: app)
            let status = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "当前边界模式：正负分链（统一断段）")).firstMatch
            for _ in 0..<3 where !status.exists { app.collectionViews.firstMatch.swipeUp() }
            XCTAssertTrue(status.exists)
            auditEvidence("G1-diverging-" + page, in: app)
            auditSearch("跨空值连线", in: app)
            XCTAssertFalse(app.switches["跨空值连线"].firstMatch.isEnabled)
            auditSearch("堆叠面积边界", in: app)
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "stackedAreaBoundaryMode")).firstMatch.tap()
            app.buttons["独立插值（兼容）"].tap()
            auditSearch("跨空值连线", in: app)
            XCTAssertTrue(app.switches["跨空值连线"].firstMatch.isEnabled)
            XCTAssertFalse(diagnostic.exists)
            auditEvidence("G1-diverging-restore-" + page, in: app)
            app.terminate()
        }
    }

    @MainActor func testDivergingStackObjectiveCModeAndRawCallback() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launch()
        let entry = app.buttons["Objective-C 接入"]
        for _ in 0..<3 where !entry.exists { app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        app.buttons["轴系验证"].tap()
        let kinds = app.segmentedControls["oc.cartesian.kind"]
        let boundaries = app.segmentedControls["oc.cartesian.boundary"]
        XCTAssertTrue(boundaries.waitForExistence(timeout: 5))
        // UIKit exposes the container separately; the segment buttons carry the disabled trait.
        XCTAssertTrue(kinds.buttons["柱状"].isSelected)
        XCTAssertFalse(boundaries.buttons["正负分链"].isEnabled, boundaries.debugDescription)
        for kind in ["折线", "混合"] {
            kinds.buttons[kind].tap(); XCTAssertTrue(boundaries.buttons["正负分链"].isEnabled)
            boundaries.buttons["正负分链"].tap()
            XCTAssertTrue(boundaries.buttons["正负分链"].isSelected)
            app.segmentedControls.buttons["百分比"].tap()
            let chart = app.descendants(matching: .any)["oc.cartesian.chart"].firstMatch
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.4)).tap()
            let readout = app.staticTexts["oc.cartesian.hit"]
            XCTAssertTrue(readout.label.contains("raw="), readout.label)
            XCTAssertTrue(readout.label.contains("draw="), readout.label)
            auditEvidence("G1-diverging-OC-" + kind, in: app)
            app.segmentedControls.buttons["不堆叠"].tap()
            XCTAssertTrue(app.segmentedControls.buttons["不堆叠"].isSelected)
            XCTAssertFalse(boundaries.buttons["正负分链"].isEnabled, boundaries.debugDescription)
            app.segmentedControls.buttons["普通"].tap(); XCTAssertTrue(boundaries.buttons["正负分链"].isEnabled)
            boundaries.buttons["沿基线"].tap()
            XCTAssertTrue(boundaries.buttons["沿基线"].isSelected)
        }
    }

    @MainActor func testLineAuditGapAndZoneDependenciesRecover() {
        let app = XCUIApplication(); app.launch(); app.buttons["折线图"].tap()
        auditSearch("X 分区", in: app); app.buttons["X 分区曲线面积 zones 场景"].tap()
        auditSearch("负值颜色", in: app)
        XCTAssertFalse(app.switches["自定义 负值颜色"].firstMatch.isEnabled)
        XCTAssertTrue(app.staticTexts["demo.rule.自定义 负值颜色"].exists)
        auditEvidence("line-audit-zone-precedence", in: app)
        auditSearch("11/12", in: app); app.buttons["11/12/13 空点 autoGap 场景"].tap()
        auditSearch("跨空值连线", in: app)
        XCTAssertFalse(app.switches["跨空值连线"].firstMatch.isEnabled)
        auditSearch("缺测策略", in: app)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "缺测策略 autoGap")).firstMatch.tap()
        app.buttons["跟随跨空值连线"].tap()
        auditSearch("跨空值连线", in: app)
        XCTAssertTrue(app.switches["跨空值连线"].firstMatch.isEnabled)
        auditToggle("跨空值连线", in: app)
        XCTAssertEqual(app.switches["跨空值连线"].firstMatch.value as? String, "1")
        auditEvidence("line-audit-gap-restored", in: app)
    }

    @MainActor func testLineAuditAxisPriorityAndDisabledReasons() {
        let app = XCUIApplication(); app.launch(); app.buttons["折线图"].tap()
        auditSearch("固定刻度", in: app)
        XCTAssertFalse(app.switches["固定刻度间隔（需固定值域）"].firstMatch.isEnabled)
        auditSearch("固定值域", in: app); auditToggle("固定值域", in: app)
        auditSearch("固定刻度", in: app)
        XCTAssertTrue(app.switches["固定刻度间隔（需固定值域）"].firstMatch.isEnabled)
        auditToggle("固定刻度间隔（需固定值域）", in: app)
        auditSearch("刻度数", in: app)
        XCTAssertFalse(app.switches["自定义刻度数"].firstMatch.isEnabled)
        XCTAssertTrue(app.staticTexts["demo.rule.自定义刻度数"].exists)
        auditEvidence("line-audit-axis-priority", in: app)
        auditSearch("固定刻度", in: app); auditToggle("固定刻度间隔（需固定值域）", in: app)
        auditSearch("刻度数", in: app)
        XCTAssertTrue(app.switches["自定义刻度数"].firstMatch.isEnabled)
    }

    @MainActor func testLineAuditSceneSwitchClearsOldDataAndStyle() {
        let app = XCUIApplication(); app.launch(); app.buttons["折线图"].tap()
        auditSearch("X 分区", in: app); app.buttons["X 分区曲线面积 zones 场景"].tap()
        auditSearch("3000 点尖峰", in: app); app.buttons["3000 点尖峰降采样场景"].tap()
        XCTAssertTrue(app.staticTexts["demo.lineSamplingStatus"].label.contains("配置可用"))
        auditSearch("当前状态", in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "实际最长 3000 点")).firstMatch.exists)
        auditEvidence("line-audit-preset-isolation-3000", in: app)
        app.buttons["最近24点"].tap()
        let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["demo.hit"].label.contains("原值"))
        auditEvidence("line-audit-detail-original-hit", in: app)
    }

    @MainActor func testLineAuditSystemFontAndPopupControls() {
        let app = XCUIApplication(); app.launch(); app.buttons["折线图"].tap()
        auditSearch("titleFont 字体", in: app)
        let font = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "titleFont 字体")).firstMatch
        font.tap(); app.buttons["系统等宽"].tap()
        XCTAssertTrue(font.label.contains("系统等宽"))
        font.tap(); app.buttons["系统常规"].tap()
        XCTAssertTrue(font.label.contains("系统常规"))
        auditSearch("容器弹窗", in: app); auditToggle("容器弹窗", in: app)
        XCTAssertEqual(app.switches["容器弹窗"].firstMatch.value as? String, "0")
        auditSearch("表头模板", in: app)
        let header = app.textFields["demo.input.表头模板"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertFalse(header.isEnabled)
        auditSearch("容器弹窗", in: app); auditToggle("容器弹窗", in: app)
        auditSearch("弹窗回调", in: app)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "弹窗回调预设")).firstMatch.tap()
        app.buttons["位置回调"].tap()
        auditSearch("共享提示", in: app)
        XCTAssertFalse(app.switches["共享提示"].firstMatch.isEnabled)
        let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["demo.hit"].label.contains("位置"))
        let expand = app.buttons["demo.hit.expand"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5)); expand.tap()
        XCTAssertEqual(expand.label, "收起读数")
        auditEvidence("line-audit-location-popup-mode", in: app)
        expand.tap(); XCTAssertEqual(expand.label, "展开读数")
    }

    @MainActor func testPreviousValuesAndPinnedTooltipOnAllCartesianPages() {
        let app = XCUIApplication()
        for page in ["折线图", "柱状图", "条形图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch("前值与置顶", in: app)
            let preset = app.buttons["前值与置顶提示场景"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.54, dy: 0.35)).tap()
            let popup = app.descendants(matching: .any)["chart.tooltip.fixedTop"].firstMatch
            XCTAssertTrue(popup.waitForExistence(timeout: 5))
            XCTAssertEqual(popup.frame.minY, chart.frame.minY + 8, accuracy: 1)
            let report = app.staticTexts["demo.hit"].label
            XCTAssertTrue(report.contains("08:05"), report)
            XCTAssertTrue(report.contains("取值 08:00"), report)
            XCTAssertTrue(report.contains("原值 120.0"), report)
            XCTAssertTrue(report.contains("100 W"), report)
            XCTAssertTrue(report.contains("60 W"), report)
            auditEvidence("previous-pinned-" + page, in: app)
            auditSearch("fixedTopInset", in: app)
            XCTAssertTrue(app.sliders.firstMatch.isEnabled)
            app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0.5)
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.54, dy: 0.35)).tap()
            XCTAssertTrue(popup.waitForExistence(timeout: 5))
            XCTAssertEqual(popup.frame.minY, chart.frame.minY + 20, accuracy: 1)
            auditEvidence("previous-pinned-inset-" + page, in: app)
            app.terminate()
        }
    }

    @MainActor func testRichTooltipRulesAndScrollingOnAllCartesianPages() {
        let app = XCUIApplication()
        for page in ["折线图", "柱状图", "条形图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch("富内容提示", in: app)
            let preset = app.buttons["富内容提示与逐点规则场景"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.35)).tap()
            let popup = app.scrollViews["chart.tooltip.columns"].firstMatch
            XCTAssertTrue(popup.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["demo.hit"].label.contains("采样"))
            XCTAssertGreaterThan(popup.staticTexts.count, 0)
            auditEvidence("rich-tooltip-" + page, in: app)

            // 增加组内行距并压低图表，让末行只能通过内容区滚动访问。
            auditSearch("提示行间距", in: app)
            app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 1)
            auditSearch("测量并追加图例高度", in: app)
            auditToggle("测量并追加图例高度", in: app)
            auditSearch("基础图表高度", in: app)
            app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0)
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.35)).tap()
            XCTAssertTrue(popup.waitForExistence(timeout: 5))
            let before = app.staticTexts["demo.hit"].label
            let lastRow = popup.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "备用")).firstMatch
            let previousY = lastRow.frame.minY
            popup.swipeUp()
            XCTAssertTrue(popup.exists, "内容滚动不应触发图表拖动或取消选择")
            XCTAssertEqual(app.staticTexts["demo.hit"].label, before)
            XCTAssertLessThan(lastRow.frame.minY, previousY - 1, "确认实际发生内部滚动")
            XCTAssertTrue(lastRow.isHittable)
            auditEvidence("rich-tooltip-scrolled-" + page, in: app)
            app.terminate()
        }
    }

    @MainActor func testGroupedTooltipAndImageLegendPresetOnAllCartesianPages() {
        let app = XCUIApplication()
        for page in ["折线图", "柱状图", "条形图", "混合图"] {
            app.launch(); app.buttons[page].tap()
            auditSearch("分组提示", in: app)
            let preset = app.buttons["分组提示与图片图例场景"]
            XCTAssertTrue(preset.waitForExistence(timeout: 5)); preset.tap()
            let chart = app.descendants(matching: .any)["demo.chart.preview"].firstMatch
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.35)).tap()
            let readout = app.staticTexts["demo.hit"]
            XCTAssertTrue(readout.label.contains("小计"), readout.label)
            XCTAssertTrue(readout.label.contains("环境"), readout.label)
            auditEvidence("grouped-presentation-" + page, in: app)
            let solar = app.buttons["光伏"].firstMatch
            XCTAssertTrue(solar.waitForExistence(timeout: 5)); solar.tap()
            XCTAssertEqual(solar.value as? String, "已隐藏")
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.35)).tap()
            XCTAssertFalse(readout.label.contains("小计"), readout.label)
            solar.tap(); XCTAssertEqual(solar.value as? String, "已显示")
            auditSearch("按业务组显示提示", in: app)
            auditToggle("按业务组显示提示", in: app)
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.35)).tap()
            XCTAssertFalse(readout.label.contains("小计"), readout.label)
            app.terminate()
        }
    }

}
