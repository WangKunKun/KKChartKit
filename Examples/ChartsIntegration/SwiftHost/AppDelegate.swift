import UIKit
import SwiftUI
import HYMCharts

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = IntegrationController()
        window.makeKeyAndVisible(); self.window = window
        return true
    }
}

/// This client deliberately uses only the framework's public Swift API.
private final class IntegrationController: UIViewController {
    private let chart = HYMChartView<LineChartRenderer>(frame: .zero)
    private let status = UILabel()
    private let hit = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        status.frame = CGRect(x: 20, y: 70, width: 350, height: 70)
        status.numberOfLines = 0; status.accessibilityIdentifier = "integration-status"
        hit.frame = CGRect(x: 20, y: 480, width: 350, height: 70)
        hit.numberOfLines = 0; hit.accessibilityIdentifier = "integration-hit"
        chart.frame = CGRect(x: 10, y: 150, width: 370, height: 310)
        view.addSubview(chart); view.addSubview(status); view.addSubview(hit)
        var model = CartesianChartModel(series: [.init(name: "Stable series", data: Array(repeating: 100, count: 48), id: "power")], xAxis: .init(kind: .category(labels: (0..<48).map(String.init))))
        model.series[0].colorZones = .init(zones: [.init(upperBound: 300, color: .systemRed), .init(color: .systemGreen)],
                                          columnValueSource: .rawValue)
        model.series[0].colorZones?.columnValueSource = .drawValue
        model.xAxis.style = .init(labelColor: .systemPurple, labelFont: .systemFont(ofSize: 13), lineColor: .systemPurple, lineWidth: 2)
        model.xAxis.categoryLabelInterval = 2
        model.yAxis.style.showsLine = false
        model.plotLines = [.init(value: 500, label: "Reference", labelStyle: .init(color: .systemPurple,
            font: .boldSystemFont(ofSize: 13), backgroundColor: .systemBackground, alignment: .leading,
            verticalAlignment: .top, offset: CGSize(width: 2, height: 3), bounds: .clamp))]
        model.plotBands = [.init(from: 300, to: 550, label: "Range", labelStyle: .init(alignment: .center))]
        var theme = CartesianChartTheme(); theme.legend.isEnabled = true
        theme.dataLabelBackgroundColor = .systemBackground; theme.dataLabelAvoidsOverlap = true
        theme.selection = .init(isEnabled: true, color: .systemOrange, lineWidth: 3, fillOpacity: 0.15, pointRadius: 8)
        theme.stackedAreaBoundaryMode = .diverging // Public framework API compile check.
        chart.configure(model: model, theme: theme); chart.layoutIfNeeded()
        chart.isZoomEnabled = true; chart.showCategoryRange(10..<30)
        var visibility: [Bool] = []
        chart.onSeriesVisibilityChanged = { id, visible in if id == "power" { visibility.append(visible) } }
        chart.setSeriesVisible(false, for: "power")
        var updated = model; updated.series[0].name = "Renamed series"
        updated.series[0].data = Array(repeating: 500, count: 48)
        chart.update(model: updated); chart.layoutIfNeeded()
        let keptHidden = chart.isSeriesVisible("power") == false
        chart.setSeriesVisible(true, for: "power"); chart.resetViewport()
        chart.onHit = { [weak self] target, _ in
            guard let source = target as? CartesianHitDataSource,
                  let datum = source.chartData.first else { return }
            self?.hit.text = "hit:\(datum.seriesID):\(Int(datum.rawValue ?? -1))"
        }
        // Compile the shipped SwiftUI wrapper through ordinary import as well.
        let wrapper = UIHostingController(rootView: LineChart(model: updated, playsAnimationOnAppear: false))
        wrapper.loadViewIfNeeded()
        var stackModel = CartesianChartModel(series: [
            .init(name: "Positive/negative", data: [20,-20,40,10], id: "g1-base", kind: .areaspline),
            .init(name: "Thin layer", data: [2,2,.nan,2], id: "g1-thin", kind: .area)
        ], stacking: .percent)
        stackModel.series[0].connectNulls = true // Explicit common-gap mode takes precedence.
        var released = 0
        for _ in 0..<30 {
            weak var weakChart: UIView?
            autoreleasepool {
                let temporary = HYMChartView<LineChartRenderer>(frame: chart.frame)
                temporary.configure(model: stackModel, theme: theme); temporary.layoutIfNeeded()
                weakChart = temporary
            }
            if weakChart == nil { released += 1 }
        }
        let neutralPassed: Bool
        do {
            guard let url = Bundle.main.url(forResource: "energy", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            let source = try ChartSpecification.decodeJSON(Data(contentsOf: url))
            let output = try HYMChartsSpecificationAdapter().makeConfiguration(from: source)
            let temporary = HYMChartView<LineChartRenderer>(frame: chart.frame)
            temporary.configure(model: output.model, theme: output.theme); temporary.layoutIfNeeded()
            guard let g1URL = Bundle.main.url(forResource: "energy-g1-v2", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            let g1 = try ChartSpecification.decodeJSON(Data(contentsOf: g1URL))
            let g1Output = try HYMChartsSpecificationAdapter().makeConfiguration(from: g1)
            temporary.update(model: g1Output.model, theme: g1Output.theme); temporary.layoutIfNeeded()
            let document = try HYMChartSpecificationDocument(specification: g1)
            let g1RoundTrip = try document.jsonData() == g1.jsonData()
            let g1Passed = g1.schemaVersion == 2 && g1.stackedAreaBoundary == .diverging
                && g1Output.theme.stackedAreaBoundaryMode == .diverging
                && g1.series == source.series
                && g1RoundTrip
            guard let zonesURL = Bundle.main.url(forResource: "energy-zones-v3", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            let zoned = try ChartSpecification.decodeJSON(Data(contentsOf: zonesURL))
            let zonedOutput = try HYMChartsSpecificationAdapter().makeConfiguration(from: zoned)
            temporary.update(model: zonedOutput.model, theme: zonedOutput.theme); temporary.layoutIfNeeded()
            let zonedDocument = try HYMChartSpecificationDocument(specification: zoned)
            let zonedRoundTrip = try zonedDocument.jsonData() == zoned.jsonData()
            let zonesPassed = zoned.schemaVersion == 3 && zoned.stackedAreaBoundary == .diverging
                && zoned.series[0].appearance.valueColorZones?.valueSource == .drawValue
                && zonedOutput.model.series[0].colorZones?.zones.count == 3
                && zonedOutput.model.series[1].colorZones == nil
                && zoned.series.map(\.samples) == source.series.map(\.samples) && zonedRoundTrip
            guard let axesURL = Bundle.main.url(forResource: "energy-axes-v4", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            let axes = try ChartSpecification.decodeJSON(Data(contentsOf: axesURL))
            let axesOutput = try HYMChartsSpecificationAdapter().makeConfiguration(from: axes)
            temporary.configure(model: axesOutput.model, theme: axesOutput.theme); temporary.layoutIfNeeded()
            let axesDocument = try HYMChartSpecificationDocument(specification: axes)
            let axesRoundTrip = try axesDocument.jsonData() == axes.jsonData()
            let axesPassed = axes.schemaVersion == 4 && axes.categoryLabelInterval == 2
                && axes.domainAppearance.labelFontWeight == .medium
                && axes.valueAxes[0].labelFormat?.unit == "%"
                && axesOutput.model.yAxis.tickPositions == [-100, -50, 0, 50, 100]
                && axesOutput.model.yAxis.labelFormatter?(50) == "50 %"
                && axesOutput.model.yAxis.style.labelFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true
                && axes.series.map(\.samples) == source.series.map(\.samples) && axesRoundTrip
            neutralPassed = g1Passed && zonesPassed && axesPassed && output.model.series[0].data[1].isNaN
                && output.sourceSample(seriesID: "solar", categoryIndex: 0)?.id == "solar-08"
                && output.model.stackedDrawValues[1][0] == -40
        } catch { neutralPassed = false }
        let passed = keptHidden && visibility == [false, true] && released == 30 && neutralPassed
        status.text = "\(passed ? "PASS" : "FAIL") Swift | update=500 | visibility=\(visibility.count) | released=\(released)/30 | neutral=\(neutralPassed)"
    }
}
