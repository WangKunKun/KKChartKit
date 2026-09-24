import XCTest
import SwiftUI
@testable import SwiftFunctionProject

@MainActor final class ChartDemoTests: XCTestCase {
    private func binding<T>(_ get: @escaping () -> T, _ set: @escaping (T) -> Void) -> Binding<T> { Binding(get: get, set: set) }

    func testPanelChangesRealThemeAndRestoresOptionalDefaults() {
        var theme = CartesianChartTheme()
        let b = binding({ theme }, { theme = $0 })
        let items = DemoThemeFields.items(b)
        guard case .toggle(_, let points) = items.first(where: { $0.label == "showsPoints" }) else { return XCTFail() }
        points.wrappedValue = false
        XCTAssertFalse(theme.showsPoints)
        guard case .toggle(_, let color) = items.first(where: { $0.label == "自定义 pointColor" }) else { return XCTFail() }
        color.wrappedValue = true; XCTAssertNotNil(theme.pointColor)
        color.wrappedValue = false; XCTAssertNil(theme.pointColor)
        guard case .slider(_, let width, _, _) = items.first(where: { $0.label == "columnWidthRatio" }) else { return XCTFail() }
        width.wrappedValue = 0.4; XCTAssertEqual(theme.columnWidthRatio, 0.4, accuracy: 0.0001)
    }

    func testSeriesPanelUsesIndependentReducerAndLegendOverride() {
        var first = DemoSeriesSettings(name: "能量", color: .systemBlue)
        let second = DemoSeriesSettings(name: "功率", color: .systemOrange)
        let b = binding({ first }, { first = $0 })
        let items = DemoSeriesSettings.items(b, kind: .column)
        guard case .picker(_, let reducer, _) = items.first(where: { $0.label == "聚合规则" }) else { return XCTFail() }
        reducer.wrappedValue = "求和"
        XCTAssertEqual(first.reducer?.name, "合计"); XCTAssertEqual(second.reducer?.name, "平均")
        first.legendTitle = "电量"; first.legendSymbol = "标记"; first.legendMarker = .diamond
        XCTAssertEqual(first.legendStyle.title, "电量")
        guard case .marker(.diamond) = first.legendStyle.symbol else { return XCTFail() }
    }

    func testHeatmapSwiftUIHonorsSuppliedTheme() {
        var theme = HeatmapChartTheme()
        theme.colorScale = .none; theme.baseColor = .systemRed
        theme.showsRowLabels = true; theme.showsColumnLabels = true
        theme.cellCornerRadius = 9; theme.rowSpacing = 8; theme.columnSpacing = 7
        let root = HeatmapChart(model: .init(rows: [[.init(value: 1), .init(value: 2)]], rowLabels: ["R"], columnLabels: ["A", "B"]), theme: theme, playsAnimationOnAppear: false)
        let host = UIHostingController(rootView: root)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 220)
        let window = UIWindow(frame: host.view.frame); window.rootViewController = host; window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        func views(_ v: UIView) -> [UIView] { [v] + v.subviews.flatMap(views) }
        func layers(_ l: CALayer) -> [CALayer] { [l] + (l.sublayers ?? []).flatMap(layers) }
        let chart = views(host.view).compactMap { $0 as? HYMChartView<HeatmapChartRenderer> }.first
        XCTAssertNotNil(chart)
        let cells = chart.map { layers($0.layer).filter { $0.cornerRadius == 9 } } ?? []
        XCTAssertEqual(cells.count, 2)
        XCTAssertTrue(cells.allSatisfy { $0.backgroundColor == UIColor.systemRed.cgColor })
        XCTAssertTrue(views(host.view).compactMap { ($0 as? UILabel)?.text }.contains("R"))
        window.isHidden = true
    }
}
