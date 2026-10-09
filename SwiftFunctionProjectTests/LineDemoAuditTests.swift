import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class LineDemoAuditTests: XCTestCase {
    private final class Editor {
        var state = CartesianDemoState(kind: .line)
        var binding: Binding<CartesianDemoState> { Binding(get: { self.state }, set: { self.state = $0 }) }
        var sections: [ChartDemoPanel.DemoSection] { CartesianDemoControls.sections(binding) }
        func item(_ label: String, section: String? = nil) throws -> ChartDemoPanel.Item {
            try XCTUnwrap(sections.filter { section == nil || $0.title == section }.flatMap(\.items).first { $0.label == label }, label)
        }
        func tap(_ label: String) throws {
            guard case .button(_, let action) = try item(label).control else { return XCTFail(label) }
            action()
        }
    }
    private func chart(_ state: CartesianDemoState) -> HYMChartView<LineChartRenderer> {
        let view = HYMChartView<LineChartRenderer>(frame: CGRect(x: 0, y: 0, width: 390, height: 320))
        view.maximumZoomScale = state.interaction.maxZoom
        view.minimumVisibleCategories = state.interaction.minimumVisible
        view.configure(model: state.model, theme: state.builtTheme)
        view.layoutIfNeeded()
        return view
    }
    private func richState() -> CartesianDemoState {
        var s = CartesianDemoState(kind: .line)
        s.seriesCount = 6 // 覆盖动态系列选择器的全部 0...5 选项。
        s.dualAxis = true; s.stacking = "普通"
        s.theme.legend.isEnabled = true; s.theme.showsArea = true; s.theme.showsDataLabels = true
        s.theme.pointHoleRadius = 1; s.theme.pointColor = .red; s.theme.dataLabelColor = .blue
        s.theme.backgroundColor = .white; s.theme.seriesShadow = .init()
        s.theme.lineSampling = .init(); s.theme.lineSampling?.targetPointCount = 200; s.gradient = true
        s.lineEnabled = true; s.bandEnabled = true
        s.primaryAxis.manualRange = true; s.primaryAxis.intervalOn = true; s.primaryAxis.countOn = true
        s.primaryAxis.style = .init(labelColor: .red, labelFont: .boldSystemFont(ofSize: 15), lineColor: .blue, lineWidth: 2)
        s.secondaryAxis = s.primaryAxis; s.categoryAxis.manualRange = true
        s.categoryAxis.style = s.primaryAxis.style; s.categoryAxis.categoryLabelInterval = 2
        s.plotLine.labelStyle = .init(color: .blue, font: .boldSystemFont(ofSize: 14), backgroundColor: .white)
        s.plotBand.labelStyle = s.plotLine.labelStyle
        s.theme.dataLabelBackgroundColor = .white
        s.series[0].negativeColor = .red; s.series[0].shadow = .init()
        s.series[0].legendBackground = .gray; s.series[0].legendColor = .blue; s.series[0].legendSymbol = "标记"
        s.series[0].valueFormat = .init(); s.series[0].groupID = "test"
        s.series[0].style.lineWidth = 3; s.series[0].style.pointRadius = 5
        s.series[0].style.fillOpacity = 0.45; s.series[0].style.areaGradientColors = [.red, .clear]
        s.series[0].zoneMode = "Y 绘制值"; s.series[0].zoneFill = true
        s.series[0].gapMode = "按空点数量"
        return s
    }

    func testAllRegisteredControlsBindAndNumericRangesContainInitialValues() throws {
        let editor = Editor()
        var duration = richState(); duration.series[0].gapMode = "按缺测时长"
        var emptyGradient = richState(); emptyGradient.series[0].style.areaGradientColors = []
        var identifiers = Set<String>()
        var inventoryRows: [String: [String: String]] = [:]
        var mutations = 0
        // 分别访问默认、可选项全开、时长策略、空渐变四种面板形态。
        for original in [CartesianDemoState(kind: .line), richState(), duration, emptyGradient] {
            editor.state = original
            let inventory = editor.sections
            for section in inventory {
                for registered in section.items {
                    editor.state = original
                    let item = try editor.item(registered.label, section: section.title).control
                    let id = section.title + "/" + item.label
                    var description: String
                    switch item {
                    case .integerInput(_, _, let range): description = "整数输入：\(range.lowerBound)...\(range.upperBound)，完成编辑时生效"
                    case .slider(_, _, let range, let step): description = "滑块：\(range.lowerBound)...\(range.upperBound)，步长 \(step)"
                    case .toggle: description = "开关"
                    case .picker(_, _, let options): description = "选择：" + options.joined(separator: " / ")
                    case .textField: description = "文本"
                    case .color: description = "颜色（含透明度）"
                    case .date: description = "日期/时间"
                    case .button: description = "动作"
                    default: description = "说明"
                    }
                    if description != "说明" {
                        inventoryRows[id] = ["section": section.title, "label": item.label, "type": description]
                    }
                    switch item {
                    case .integerInput(_, let value, let range):
                        identifiers.insert(id)
                        XCTAssertTrue(range.contains(value.wrappedValue), id)
                        for number in [range.lowerBound, range.upperBound, 123] {
                            value.wrappedValue = number; XCTAssertEqual(value.wrappedValue, number, id); mutations += 1
                        }
                    case .slider(_, let value, let range, let step):
                        identifiers.insert(id)
                        XCTAssertTrue(range.contains(value.wrappedValue), id + " initial=\(value.wrappedValue)")
                        for number in [range.lowerBound, range.upperBound, range.lowerBound + step] {
                            value.wrappedValue = number
                            XCTAssertEqual(value.wrappedValue, number, accuracy: 0.00001, id)
                            let view = chart(editor.state)
                            let plot = view.rendererForTesting.currentPlotFrame
                            XCTAssertTrue([plot.minX, plot.minY, plot.width, plot.height].allSatisfy(\.isFinite), id)
                            XCTAssertGreaterThanOrEqual(plot.width, 0, id)
                            XCTAssertGreaterThanOrEqual(plot.height, 0, id)
                            mutations += 1
                        }
                    case .toggle(_, let value):
                        identifiers.insert(id)
                        let previous = value.wrappedValue
                        value.wrappedValue = !previous; XCTAssertEqual(value.wrappedValue, !previous, id)
                        value.wrappedValue = previous; XCTAssertEqual(value.wrappedValue, previous, id)
                        mutations += 2
                    case .picker(_, let value, let options):
                        identifiers.insert(id)
                        XCTAssertTrue(options.contains(value.wrappedValue), id + " initial=" + value.wrappedValue)
                        for option in options { value.wrappedValue = option; XCTAssertEqual(value.wrappedValue, option, id); mutations += 1 }
                    case .textField(_, let value):
                        identifiers.insert(id)
                        for text in ["", "3,nan,7", "测试", " "] { value.wrappedValue = text; XCTAssertEqual(value.wrappedValue, text, id); mutations += 1 }
                    case .color(_, let value):
                        identifiers.insert(id)
                        value.wrappedValue = .magenta; XCTAssertEqual(value.wrappedValue, .magenta, id); mutations += 1
                    case .date(_, let value):
                        identifiers.insert(id)
                        let date = Date(timeIntervalSince1970: 1790208000)
                        value.wrappedValue = date; XCTAssertEqual(value.wrappedValue, date, id); mutations += 1
                    case .button, .note: break // 场景动作由串行组合测试覆盖。
                    case .stepper, .availability: XCTFail("Uncovered control: " + id)
                    }
                }
            }
        }
        XCTAssertEqual(identifiers.count, 327, "面板清单变化时同步更新审计文档及条件状态覆盖。")
        let json = try JSONSerialization.data(withJSONObject: inventoryRows.keys.sorted().compactMap { inventoryRows[$0] }, options: [.sortedKeys])
        let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        attachment.name = "line-demo-control-inventory"; attachment.lifetime = .keepAlways; add(attachment)
        print("LINE_DEMO_INVENTORY_JSON=" + String(decoding: json, as: UTF8.self))
        print("LINE_DEMO_AUDIT editable controls=\(identifiers.count), binding mutations=\(mutations)")
    }

    func testTargetSamplingControlsOverrideWidthAndThresholdWithoutClearingThem() throws {
        let e = Editor(); e.state.densityPreset(peaks: true); e.state.missing = false
        e.state.theme.lineSampling?.bucketWidth = 8
        e.state.theme.lineSampling?.minimumVisiblePoints = 1200
        guard case .toggle(_, let enabled) = try e.item("按目标点数采样 targetPointCount").control else {
            return XCTFail("Missing target toggle")
        }
        enabled.wrappedValue = true
        XCTAssertEqual(e.state.builtTheme.lineSampling?.targetPointCount, 200)
        XCTAssertFalse(try e.item("分组宽度 bucketWidth（pt）").isEnabled)
        XCTAssertFalse(try e.item("启动门槛 minimumVisiblePoints（非保留点数）").isEnabled)
        guard case .integerInput(_, let count, _) = try e.item("每系列目标绘制点数 targetPointCount").control else {
            return XCTFail("Missing target count")
        }
        count.wrappedValue = 123
        XCTAssertEqual(e.state.builtTheme.lineSampling?.targetPointCount, 123)
        XCTAssertTrue(e.state.samplingStatus.contains("目标 123 点"))
        XCTAssertTrue(chart(e.state).rendererForTesting.samplingStatistics.allSatisfy { $0.renderedPointCount == 123 })
        enabled.wrappedValue = false
        XCTAssertNil(e.state.builtTheme.lineSampling?.targetPointCount)
        XCTAssertEqual(e.state.builtTheme.lineSampling?.bucketWidth, 8)
        XCTAssertEqual(e.state.builtTheme.lineSampling?.minimumVisiblePoints, 1200)
        XCTAssertTrue(try e.item("分组宽度 bucketWidth（pt）").isEnabled)
        XCTAssertTrue(try e.item("启动门槛 minimumVisiblePoints（非保留点数）").isEnabled)
    }

    func testNonPresetActionsOnlyChangeTheirOwnConfiguration() throws {
        let e = Editor(); e.state = richState()
        e.state.series[0].dataText = "10,20,30"
        let before = e.state.model.series[1].data
        let resetID = e.state.resetID
        try e.tap("更新样本数据")
        XCTAssertEqual(e.state.model.series[0].data, [10, 20, 30])
        XCTAssertNotEqual(e.state.model.series[1].data, before)
        XCTAssertEqual(e.state.resetID, resetID)
        try e.tap("恢复系列默认渐变（忽略主题渐变）")
        XCTAssertEqual(e.state.series[0].style.areaGradientColors?.count, 0)
        XCTAssertTrue(e.state.gradient)
        try e.tap("重置当前系列样式覆盖")
        XCTAssertNil(e.state.series[0].style.lineWidth)
        XCTAssertNil(e.state.series[0].style.showsArea)
        XCTAssertNil(e.state.series[0].style.areaGradientColors)
        XCTAssertEqual(e.state.series[0].dataText, "10,20,30")
        XCTAssertEqual(e.state.series[0].zoneMode, "Y 绘制值") // 非 style 字段不能被误清空。
        XCTAssertTrue(e.state.dualAxis)
        e.state.query = "任意搜索"; e.state.reset()
        XCTAssertTrue(e.state.query.isEmpty)
        XCTAssertNotEqual(e.state.resetID, resetID)
        XCTAssertEqual(e.state.pointCount, 24)
        XCTAssertEqual(e.state.seriesCount, 3)
        XCTAssertFalse(e.state.dualAxis)
    }

    func testStackedAreaKnownLimitationIsDisclosedOnlyWhenRelevant() {
        let e = Editor()
        func warning() -> Bool { e.sections.flatMap(\.items).contains { $0.label.contains("复杂堆叠面积") } }
        XCTAssertFalse(warning())
        e.state.stacking = "普通"; e.state.theme.showsArea = true
        XCTAssertFalse(warning())
        e.state.series[0].dataText = "10,nan,-20"
        XCTAssertTrue(warning())
        e.state.theme.showsArea = false
        XCTAssertFalse(warning())
    }

    func testAxisDependenciesNormalizeInputAndRestoreLowerPrioritySettings() throws {
        let e = Editor()
        XCTAssertFalse(try e.item("下界", section: "主值轴").isEnabled)
        e.state.primaryAxis.manualRange = true
        e.state.primaryAxis.lower = 100; e.state.primaryAxis.upper = -20
        XCTAssertEqual(e.state.model.yAxis.min, -20); XCTAssertEqual(e.state.model.yAxis.max, 100)
        e.state.primaryAxis.countOn = true
        e.state.primaryAxis.intervalOn = true
        XCTAssertFalse(try e.item("刻度数", section: "主值轴").isEnabled)
        e.state.primaryAxis.positions = "40,invalid,nan,0,40,inf,20"
        XCTAssertEqual(e.state.model.yAxis.tickPositions, [0, 20, 40])
        XCTAssertFalse(try e.item("刻度间隔", section: "主值轴").isEnabled)
        e.state.primaryAxis.positions = "invalid, nan, inf"
        XCTAssertNil(e.state.model.yAxis.tickPositions)
        XCTAssertTrue(try e.item("刻度间隔", section: "主值轴").isEnabled)
        e.state.primaryAxis.manualRange = false
        XCTAssertNil(e.state.model.yAxis.tickInterval)
        XCTAssertTrue(try e.item("刻度数", section: "主值轴").isEnabled)
        XCTAssertEqual(e.state.model.yAxis.tickCount, 6)
    }

    func testDataOverridesAndDayIntervalUseActualLongestSeries() throws {
        let e = Editor()
        for i in 0..<3 { e.state.series[i].dataText = "1,2,3" }
        XCTAssertEqual(e.state.model.maxPointCount, 3)
        XCTAssertEqual(e.state.model.timeAxis?.interval, 28800)
        XCTAssertFalse(try e.item("数据点数").isEnabled)
        XCTAssertFalse(try e.item("包含缺测").isEnabled)
        e.state.series[1].dataText = ""
        XCTAssertEqual(e.state.model.maxPointCount, 24)
        XCTAssertEqual(e.state.model.timeAxis?.interval, 3600)
        XCTAssertTrue(try e.item("数据点数").isEnabled)
        e.state.daily = false; e.state.interval = 300
        XCTAssertEqual(e.state.model.timeAxis?.interval, 300)
        e.state.customLabels = "甲,乙"
        XCTAssertEqual(e.state.model.categoryLabels, ["甲", "乙"])
        XCTAssertFalse(try e.item("日期格式").isEnabled)
        XCTAssertNotNil(e.state.model.timeAxis)
    }

    func testGapZonesAndAreaPrecedenceCanBeRestoredWithoutLosingValues() throws {
        let e = Editor()
        e.state.series[0].connectNulls = true
        e.state.series[0].gapMode = "按缺测时长"; e.state.timeEnabled = false
        XCTAssertFalse(try e.item("跨空值连线").isEnabled)
        XCTAssertFalse(try e.item("缺测时长上限秒（需时间轴）").isEnabled)
        e.state.timeEnabled = true
        XCTAssertTrue(try e.item("缺测时长上限秒（需时间轴）").isEnabled)
        e.state.series[0].gapMode = "跟随跨空值连线"
        XCTAssertTrue(try e.item("跨空值连线").isEnabled)
        XCTAssertTrue(e.state.model.series[0].connectNulls)
        e.state.series[0].zoneMode = "Y 绘制值"; e.state.series[0].negativeColor = .red
        XCTAssertFalse(try e.item("自定义 负值颜色").isEnabled)
        XCTAssertFalse(try e.item("分区面积渐变").isEnabled)
        e.state.series[0].style.showsArea = true
        XCTAssertTrue(try e.item("分区面积渐变").isEnabled)
        e.state.series[0].zoneFill = true
        XCTAssertFalse(try e.item("自定义系列填充颜色").isEnabled)
        e.state.series[0].zoneMode = "关闭"
        XCTAssertTrue(try e.item("自定义 负值颜色").isEnabled)
        XCTAssertTrue(try e.item("自定义系列填充颜色").isEnabled)
        XCTAssertEqual(e.state.model.series[0].negativeColor, .red)
    }

    func testSeriesOverridesVisibilityAndGlobalDependencies() throws {
        let e = Editor()
        XCTAssertFalse(try e.item("seriesColor").isEnabled) // 默认各系列已指定颜色。
        e.state.series[0].color = nil
        XCTAssertTrue(try e.item("seriesColor").isEnabled)
        for i in 0..<3 { e.state.series[i].style.showsPoints = false }
        XCTAssertFalse(try e.item("showsPoints").isEnabled)
        XCTAssertFalse(try e.item("pointRadius").isEnabled)
        e.state.series[0].style.showsPoints = true
        XCTAssertTrue(try e.item("pointRadius").isEnabled)
        e.state.series[0].style = .init()
        XCTAssertTrue(try e.item("showsPoints").isEnabled)
        XCTAssertFalse(try e.item("最大缩放倍率").reason?.isEmpty ?? false)
        e.state.interaction.zoom = false
        XCTAssertFalse(try e.item("最大缩放倍率").isEnabled)
        e.state.interaction.crosshair = false
        XCTAssertFalse(try e.item("准线颜色").isEnabled)
        e.state.theme.legend.isEnabled = true; e.state.expandLegend = true
        XCTAssertFalse(try e.item("maxRows").isEnabled)
        XCTAssertFalse(try e.item("maxWidth", section: "图例布局").isEnabled)
        e.state.theme.legend.position = .left
        XCTAssertTrue(try e.item("maxWidth", section: "图例布局").isEnabled)
        XCTAssertFalse(try e.item("测量并追加图例高度").isEnabled)
    }

    func testStackedAreaBoundaryAvailabilityAndDefaultRestoration() throws {
        let e = Editor(), label = "stackedAreaBoundaryMode 堆叠面积边界"
        XCTAssertFalse(try e.item(label).isEnabled)
        try e.tap("薄层混合线型面积对照场景")
        XCTAssertTrue(try e.item(label).isEnabled)
        XCTAssertEqual(e.state.builtTheme.stackedAreaBoundaryMode, .followBaseline)
        e.state.stacking = "百分比"
        XCTAssertTrue(try e.item(label).isEnabled)
        e.state.stacking = "固定基准百分比"
        XCTAssertTrue(try e.item(label).isEnabled)
        XCTAssertEqual(e.state.builtTheme.stackedAreaBoundaryMode, .followBaseline)
        e.state.resetForPreset()
        XCTAssertEqual(e.state.builtTheme.stackedAreaBoundaryMode, .independent)
    }

    func testReferenceAxesFallBackAndRestoreWithSecondaryAxis() throws {
        let e = Editor()
        e.state.lineEnabled = true; e.state.bandEnabled = true
        e.state.plotLine.yAxisIndex = 1; e.state.plotBand.yAxisIndex = 1; e.state.series[0].axis = 1
        XCTAssertEqual(e.state.model.plotLines[0].yAxisIndex, 0)
        XCTAssertEqual(e.state.model.plotBands[0].yAxisIndex, 0)
        XCTAssertEqual(e.state.model.series[0].yAxisIndex, 0)
        e.state.dualAxis = true
        XCTAssertEqual(e.state.model.plotLines[0].yAxisIndex, 1)
        XCTAssertEqual(e.state.model.plotBands[0].yAxisIndex, 1)
        XCTAssertEqual(e.state.model.series[0].yAxisIndex, 1)
    }

    func testAllSceneButtonsWorkAfterEveryOtherSceneAndDirtyConfiguration() throws {
        let e = Editor()
        let presets = ["288 点（5 分钟/点）", "1440 点（1 分钟/点）", "3000 点压力场景", "数据语义：100 + 50 堆叠", "11/12/13 空点 autoGap 场景", "X 分区曲线面积 zones 场景", "Y 分区曲线面积 zones 场景", "曲线负值换色 zones 场景", "两组堆叠与目标线", "3000 点尖峰降采样场景", "3000 点目标点数采样场景", "正负与缺测堆叠面积接缝场景", "薄层混合线型面积对照场景", "跨零正负基线面积对照场景", "前层换链面积对照场景", "缺测底边分段面积对照场景", "自动百分比面积对照场景", "分组提示与图片图例场景", "富内容提示与逐点规则场景", "前值与置顶提示场景"]
        for first in presets {
            for second in presets {
                try e.tap(first)
                e.state.primaryAxis.manualRange = true; e.state.primaryAxis.lower = 900; e.state.primaryAxis.upper = 1000
                e.state.theme.pointColor = .purple; e.state.interaction.popupMode = "位置回调"
                e.state.series[0].style.showsPoints = false; e.state.series[0].dataText = "nan"
                e.state.query = "场景"
                try e.tap(second)
                XCTAssertEqual(e.state.query, "场景")
                XCTAssertNil(e.state.model.yAxis.min, first + " -> " + second)
                XCTAssertNil(e.state.builtTheme.pointColor)
                XCTAssertEqual(e.state.interaction.popupMode, "内置")
                XCTAssertTrue(e.state.model.series[0].data.contains(where: \.isFinite))
                XCTAssertTrue(e.state.model.series.allSatisfy { $0.data.count == e.state.pointCount })
                if second.contains("3000") {
                    XCTAssertEqual(e.state.model.maxPointCount, 3000)
                    XCTAssertTrue(e.state.model.series.allSatisfy { $0.lineTheme(e.state.builtTheme).lineConnectionStyle == .straight })
                }
                if second.contains("分钟/点") { XCTAssertEqual(e.state.model.timeAxis?.interval, second.hasPrefix("288") ? 300 : 60) }
            }
        }
        e.state.reset()
        XCTAssertEqual(e.state.model.maxPointCount, 24); XCTAssertEqual(e.state.query, "")
    }

    func testSamplingStatusMatchesActualSeriesOverridesAndVisibility() {
        var s = CartesianDemoState(kind: .line)
        s.densityPreset()
        for connection in LineConnectionStyle.allCases {
            s.series[0].style.lineConnectionStyle = connection
            XCTAssertEqual(s.samplingEligible, connection == .straight)
            XCTAssertEqual(chart(s).rendererForTesting.usesSampling, s.samplingEligible)
        }
        s.series[0].visible = false
        XCTAssertTrue(s.samplingEligible)
        s.stacking = "序号分组"
        XCTAssertFalse(s.samplingEligible)
        XCTAssertFalse(chart(s).rendererForTesting.usesSampling)
    }

    func testRenderingMatrixForConnectionStackGapZonesAndDualAxes() {
        var count = 0
        let view = chart(CartesianDemoState(kind: .line))
        for connection in LineConnectionStyle.allCases {
            for stack in ["无", "普通", "百分比", "固定基准百分比", "序号分组"] {
                for gap in ["跟随跨空值连线", "全部断开", "全部连接", "按空点数量", "按缺测时长"] {
                    for zone in ["关闭", "X 原始索引", "Y 绘制值"] {
                        for dual in [false, true] {
                            var s = CartesianDemoState(kind: .line)
                            s.stacking = stack; s.dualAxis = dual
                            s.timeEnabled = count.isMultiple(of: 2); s.daily = false; s.interval = 300
                            s.theme.lineConnectionStyle = connection; s.theme.lineSampling = .init()
                            s.theme.showsArea = true; s.theme.showsDataLabels = true
                            s.gradient = count.isMultiple(of: 3)
                            for i in 0..<3 {
                                s.series[i].dataText = i == 1 ? "5,-10,nan,20,-5,30" : "10,-20,nan,40,-10,20"
                                s.series[i].gapMode = gap; s.series[i].zoneMode = zone; s.series[i].zoneFill = true
                                s.series[i].zoneThreshold = zone == "X 原始索引" ? 2.5 : 0
                                s.series[i].axis = i == 1 ? 1 : 0
                                s.series[i].style.fillOpacity = 0.45
                            }
                            view.update(model: s.model, theme: s.builtTheme, viewportPolicy: .reset)
                            view.layoutIfNeeded()
                            let r = view.rendererForTesting
                            XCTAssertEqual(r.usesSampling, s.samplingEligible)
                            func checkPaths(_ layer: CALayer) {
                                if let path = (layer as? CAShapeLayer)?.path, !path.isEmpty {
                                    let box = path.boundingBoxOfPath
                                    XCTAssertTrue([box.minX, box.minY, box.width, box.height].allSatisfy(\.isFinite), "配置 \(count) 路径非有限")
                                }
                                layer.sublayers?.forEach(checkPaths)
                            }
                            r.seriesLayerSublayersForTesting().forEach(checkPaths)
                            for i in 0..<3 {
                                let expected = CartesianGapSegmenter.segments(values: r.currentDrawValues[i], policy: s.series[i].gapPolicy ?? .breakAll, sampleInterval: s.timeEnabled ? 300 : nil)
                                XCTAssertEqual(r.renderedIndices[i], expected)
                                XCTAssertTrue(r.currentDrawValues[i].enumerated().allSatisfy { $0.offset == 2 ? !$0.element.isFinite : $0.element.isFinite })
                            }
                            count += 1
                        }
                    }
                }
            }
        }
        XCTAssertEqual(count, 750)
        print("LINE_DEMO_AUDIT rendered configuration matrix=\(count)")
    }

    func testLineTooltipHeaderWorksForDirectSnapAndSampledHits() throws {
        for sampled in [false, true] {
            var s = CartesianDemoState(kind: .line)
            s.seriesCount = 1; s.pointCount = sampled ? 3000 : 24
            if sampled { s.theme.lineSampling = .init() }
            let view = chart(s), renderer = view.rendererForTesting
            let target = try XCTUnwrap(renderer.makeHitTarget(seriesIndex: 0, categoryIndex: 1, value: 50) as? LineHitTarget)
            XCTAssertEqual(target.tooltipHeaderKey, s.model.categoryLabels[1])
            view.tooltipTextOptions = .init(header: "时刻 {key}")
            XCTAssertTrue(try XCTUnwrap(view.formattedTooltipText(for: target)).hasPrefix("时刻 " + s.model.categoryLabels[1]))
            let frame = try XCTUnwrap(renderer.hitFrame(for: target))
            let direct = try XCTUnwrap(renderer.hitTest(CGPoint(x: frame.midX, y: frame.midY)) as? LineHitTarget)
            XCTAssertNotNil(direct.tooltipHeaderKey)
        }
    }

    func testSinglePopupSwitchAndCustomContentModesInActualHost() throws {
        var s = CartesianDemoState(kind: .line)
        let report = DemoChartReport()
        let host = UIHostingController(rootView: DemoChartHost<LineChartRenderer>(model: s.model, theme: s.builtTheme, interaction: s.interaction, report: report))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 400))
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        func views(_ v: UIView) -> [UIView] { [v] + v.subviews.flatMap(views) }
        for mode in ["内置", "自定义内容", "位置回调"] {
            for enabled in [true, false, true] {
                s.interaction.popupMode = mode; s.interaction.tooltip = enabled; s.interaction.shared = true
                var tooltip = HYMChartTooltipTheme(); tooltip.showsAnimation = false
                host.rootView = DemoChartHost<LineChartRenderer>(model: s.model, theme: s.builtTheme, interaction: s.interaction, tooltipTheme: tooltip, report: report)
                host.view.layoutIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                let chart = try XCTUnwrap(views(host.view).compactMap { $0 as? HYMChartView<LineChartRenderer> }.first)
                chart.layoutIfNeeded() // SwiftUI 已应用 update，显式提交待处理的 renderer 布局。
                XCTAssertEqual(chart.showsTooltipOnHit, enabled)
                XCTAssertEqual(chart.rendererForTesting.currentTheme?.showsTooltipOnHit, enabled)
                XCTAssertEqual(chart.isSharedTooltipOnTapEnabled, mode == "内置")
                chart.performTap(at: CGPoint(x: 195, y: 150))
                let visible = chart.subviews.contains { $0 is HYMChartTooltip && !$0.isHidden }
                XCTAssertEqual(visible, enabled && mode != "位置回调", "\(mode) / \(enabled)")
                if mode == "位置回调" { XCTAssertTrue(report.text.contains("位置")) }
            }
        }
    }

    func testSharedTooltipRespectsBothSwitchesAndDoesNotSwallowExternalCallbacks() {
        var s = CartesianDemoState(kind: .line)
        let view = chart(s)
        view.isSharedTooltipOnTapEnabled = true
        view.tooltipTheme.showsAnimation = false
        for container in [true, false] {
            for theme in [true, false] {
                s.interaction.tooltip = theme
                view.update(theme: s.builtTheme)
                view.showsTooltipOnHit = container
                view.performTap(at: CGPoint(x: 195, y: 150))
                XCTAssertEqual(view.subviews.contains { $0 is HYMChartTooltip && !$0.isHidden }, container && theme)
            }
        }
        s.interaction.tooltip = true; view.update(theme: s.builtTheme); view.showsTooltipOnHit = true
        var located = false
        view.onHitLocated = { context, _ in located = context != nil }
        view.performTap(at: CGPoint(x: 195, y: 150))
        XCTAssertTrue(located)
        XCTAssertFalse(view.subviews.contains { $0 is HYMChartTooltip && !$0.isHidden })
        view.onHitLocated = nil
        var custom = false
        view.popupContentProvider = { _ in custom = true; return UILabel() }
        view.performTap(at: CGPoint(x: 195, y: 150))
        XCTAssertTrue(custom)
    }

}
