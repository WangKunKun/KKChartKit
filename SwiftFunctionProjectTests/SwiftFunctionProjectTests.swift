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
