import UIKit

/// OC 返回的 NSError 使用此域与命名错误码；配置失败不会替换当前图表。
public enum HYMCartesianConfigurationError: Int, Error, CustomNSError {
    case invalidIdentifiers = 1
    case invalidPercentageBase = 2
    case unsupportedSecondaryAxis = 3
    public static var errorDomain: String { "HYMCharts.Configuration" }
    public var errorCode: Int { rawValue }
    public var errorUserInfo: [String: Any] {
        let message: String
        switch self {
        case .invalidIdentifiers: message = "系列和组的 ID 必须非空且分别唯一"
        case .invalidPercentageBase: message = "固定百分比基准必须为正有限值"
        case .unsupportedSecondaryAxis: message = "条形图暂不支持次值轴"
        }
        return [NSLocalizedDescriptionKey: message]
    }
}

/// OC 最小轴系入口；所有 UI 属性与方法须在主线程使用。
/// 持有此对象，将 chartView 加到父视图；配置变更后调用 configure/update。
@objcMembers public final class HYMCartesianChartViewBridge: NSObject {
    public private(set) var chartView: UIView = UIView()
    public var showsLegend = true
    public var showsTooltip = true
    public var usesSharedTooltip = true
    public var isZoomEnabled = false
    /// 单点/拖动/共享命中都返回同一快照数组。取消选择由外部 UI 生命周期处理。
    public var onHit: (([HYMCartesianDatum]) -> Void)?
    public var onSeriesVisibilityChanged: ((String, Bool) -> Void)?
    private let kind: HYMCartesianChartKind
    private var apply: ((CartesianChartModel, CartesianChartTheme, Bool) -> Void)?
    private var showRange: ((Range<Int>) -> Void)?
    private var reset: (() -> Void)?
    private var visibility: ((Bool, String) -> Void)?

    public init(kind: HYMCartesianChartKind, frame: CGRect) {
        self.kind = kind
        super.init()
        switch kind {
        case .line: install(HYMChartView<LineChartRenderer>(frame: frame))
        case .column: install(HYMChartView<ColumnChartRenderer>(frame: frame))
        case .bar: install(HYMChartView<BarChartRenderer>(frame: frame))
        case .combined: install(HYMChartView<CombinedChartRenderer>(frame: frame))
        }
    }

    private func install<R>(_ chart: HYMChartView<R>) where R.Model == CartesianChartModel, R.Theme == CartesianChartTheme {
        chartView = chart
        chart.onHit = { [weak self] target, _ in
            self?.onHit?(((target as? CartesianHitDataSource)?.chartData ?? []).map(HYMCartesianDatum.init))
        }
        chart.onSeriesVisibilityChanged = { [weak self] id, visible in self?.onSeriesVisibilityChanged?(id, visible) }
        apply = { [weak self] model, theme, preserve in
            guard let self else { return }
            chart.showsTooltipOnHit = self.showsTooltip
            chart.isSharedTooltipOnTapEnabled = self.usesSharedTooltip
            chart.isZoomEnabled = self.isZoomEnabled
            chart.zoomAxisMode = self.kind == .bar ? .y : .x
            if preserve { chart.update(model: model, theme: theme) }
            else { chart.configure(model: model, theme: theme) }
        }
        showRange = { chart.showCategoryRange($0) }
        reset = { chart.resetViewport() }
        visibility = { chart.setSeriesVisible($0, for: $1) }
    }

    /// 初次配置或重置。非法系列/组 ID、固定百分比基准、Bar 双轴返回 NSError。
    @objc(configureWithModel:error:)
    public func configure(model: HYMCartesianModel) throws { try apply(model, preserve: false) }

    /// 更新模型，默认保留当前窗口。桥接复制为 Swift 值模型，后续修改 OC 对象需再次 update。
    @objc(updateWithModel:preserveViewport:error:)
    public func update(model: HYMCartesianModel, preserveViewport: Bool) throws { try apply(model, preserve: preserveViewport) }

    private func apply(_ model: HYMCartesianModel, preserve: Bool) throws {
        func valid(_ ids: [String]) -> Bool { ids.allSatisfy { !$0.isEmpty } && Set(ids).count == ids.count }
        guard valid(model.series.map(\.identifier)), valid(model.groups.map(\.identifier)) else {
            throw HYMCartesianConfigurationError.invalidIdentifiers
        }
        guard model.stacking != .percentFixed || (model.percentageBase.isFinite && model.percentageBase > 0) else {
            throw HYMCartesianConfigurationError.invalidPercentageBase
        }
        guard kind != .bar || (!model.usesSecondaryAxis && model.series.allSatisfy { $0.yAxisIndex == 0 }) else {
            throw HYMCartesianConfigurationError.unsupportedSecondaryAxis
        }
        var theme = CartesianChartTheme()
        theme.legend.isEnabled = showsLegend
        theme.showsTooltipOnHit = showsTooltip
        apply?(model.build(), theme, preserve)
    }

    /// 类目区间为 NSRange 的 location/length；空范围忽略。
    public func showCategoryRange(_ range: NSRange) {
        guard range.location != NSNotFound, range.location >= 0, range.length > 0,
              range.location <= Int.max - range.length else { return }
        showRange?(range.location..<(range.location + range.length))
    }
    public func resetViewport() { reset?() }
    public func setSeriesVisible(_ visible: Bool, forID identifier: String) { visibility?(visible, identifier) }
}
