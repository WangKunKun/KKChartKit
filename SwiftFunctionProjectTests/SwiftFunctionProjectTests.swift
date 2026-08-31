//
//  SwiftFunctionProjectTests.swift
//  SwiftFunctionProjectTests
//
//  Created by wangkun on 2026/7/22.
//

import XCTest
@testable import SwiftFunctionProject

final class SwiftFunctionProjectTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Any test you write for XCTest can be annotated as throws or async.
        // Mark your test async to await the results of assertions afterwards.
    }

    /// 框架级 DEBUG 自检（ChartSelfTest，随 App 启动也会跑一遍；此处供命令行/CI 验证）。

    /// 准线点击链路：demo 默认配置（sharedTooltipOn=true → 单系列也走整列路径）与
    /// 自动档（nil → 单系列逐点）两种 tap 路径都必须点亮准线（fix: 打开开关无效果）。
    func testCrosshairVisibleAfterTap() {
        let chart = HYMChartView<LineChartRenderer>(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        let model = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [20, 40, 60, 30])])
        chart.configure(model: model, theme: CartesianChartTheme())
        chart.layoutIfNeeded()
        XCTAssertFalse(chart.isCrosshairVisibleForTesting, "未点击时准线应隐藏")

        // 路径 1：demo 默认（显式开 shared，单系列仍整列命中）
        chart.isSharedTooltipOnTapEnabled = true
        chart.performTap(at: CGPoint(x: 195, y: 150))
        XCTAssertTrue(chart.isCrosshairAttachedForTesting, "准线层应挂在 layer 树上（诊断 detach）")
        XCTAssertTrue(chart.isCrosshairVisibleForTesting, "整列命中应显示准线")

        // 再现 demo 入场动画后的布局（动画完成回调会跑 layout）
        chart.playEntranceAnimation()
        chart.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(2.5))   // 等动画完成回调
        chart.performTap(at: CGPoint(x: 195, y: 150))
        XCTAssertTrue(chart.isCrosshairAttachedForTesting, "入场动画后准线层仍应在树上")
        XCTAssertTrue(chart.isCrosshairVisibleForTesting, "入场动画后整列命中仍应显示准线")

        // 关闭开关：命中不再画线
        chart.isCrosshairEnabled = false
        chart.performTap(at: CGPoint(x: 195, y: 150))
        XCTAssertFalse(chart.isCrosshairVisibleForTesting, "isCrosshairEnabled=false 时不显示")

        // 路径 2：自动档（nil → 单系列走逐点+吸附）
        chart.isCrosshairEnabled = true
        chart.isSharedTooltipOnTapEnabled = nil
        chart.performTap(at: CGPoint(x: 195, y: 150))
        XCTAssertTrue(chart.isCrosshairVisibleForTesting, "逐点命中也应显示准线")

        // 多系列自动档：整列路径
        let multi = CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: [20, 40, 60, 30]),
                     CartesianSeriesElement(name: "b", data: [50, 25, 45, 70])])
        chart.configure(model: multi, theme: CartesianChartTheme())
        chart.layoutIfNeeded()
        XCTAssertFalse(chart.isCrosshairVisibleForTesting, "configure 重置后准线应隐藏")
        chart.performTap(at: CGPoint(x: 195, y: 150))
        XCTAssertTrue(chart.isCrosshairVisibleForTesting, "多系列自动档整列命中应显示准线")
    }

    /// 橡皮筋回弹端到端：拖出边界 → 松手 → 动画结束视口回全量域（fix: 越界余量曾按全量域算）。
    func testRubberBandRebound() {
        let chart = HYMChartView<LineChartRenderer>(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        chart.isZoomEnabled = true
        chart.isDragDecelerationEnabled = false   // 隔离：只验回弹，不叠惯性
        chart.configure(model: CartesianChartModel(
            series: [CartesianSeriesElement(name: "a", data: (0..<100).map { Double($0) })]),
                        theme: CartesianChartTheme())
        chart.layoutIfNeeded()
        let full = chart.xAxisViewportForTesting!

        // 手指右滑拖出下界（把首类目往右拖），越界余量 = 窗口跨度 25%
        chart.simulateViewportPan(deltaX: 5000)
        let overshot = chart.xAxisViewportForTesting!
        XCTAssertLessThan(overshot.lowerBound, full.lowerBound, "应已越出下界")
        XCTAssertLessThanOrEqual(full.lowerBound - overshot.lowerBound,
                                 (full.upperBound - full.lowerBound) * 0.25 + 1e-6,
                                 "越界不超过窗口跨度 25%")

        // 松手回弹：DisplayLink 驱动（wait 驱动主 RunLoop；run(until:) 不服务 display link）
        let reboundDone = expectation(description: "rebound")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { reboundDone.fulfill() }
        wait(for: [reboundDone], timeout: 3)
        XCTAssertEqual(chart.xAxisViewportForTesting!.lowerBound, full.lowerBound, accuracy: 1e-6,
                       "回弹后视口应回全量域")
        XCTAssertEqual(chart.xAxisViewportForTesting!.upperBound, full.upperBound, accuracy: 1e-6)
    }

    func testChartSelfTest() {
        ChartSelfTest.runAll()
    }

    /// 条形图水平轴系渲染契约（docs/todo-bar-axis-fix.md 验收）。
    func testBarHorizontalAxis() {
        ChartSelfTest.runHorizontalAxisSelfTest()
    }









    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
