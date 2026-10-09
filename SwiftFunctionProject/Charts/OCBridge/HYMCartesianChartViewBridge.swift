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
    public var selectionStyle = HYMCartesianSelectionStyle()
    public var showsDataLabels = false
    public var showsStackTotalLabels = false
    public var dataLabelFontSize: CGFloat = 10
    public var dataLabelColor: UIColor?
    public var dataLabelBackgroundColor: UIColor?
    public var dataLabelAvoidsOverlap = false
    public var showsLegend = true
    public var showsTooltip = true
    /// 沿基线叠加自身厚度，正负基线可确定时跨零分片；默认 false 保留独立插值。
    /// 修改后调用 configure/update；上层跨缺测连接保留两侧轮廓，缺口直连基准后叠加厚度。
    /// 下层仍按自身缺测策略断开，不补业务点；缺口不保证全域无缝，原始零值仍属于正链。
    /// 自动百分比对同链份额共同归一化；同链须全为沿基线面积、缺测分段一致且分母非零。
    /// 不兼容或超过精度/细分上限则整链回退；普通/序号分组/固定基准百分比继续可用。
    public var stackedAreaFollowsBaseline = false
    /// 启用正负双链共享边界并在任一参与系列缺测处统一断段；优先于 stackedAreaFollowsBaseline。
    /// 不改业务数据/命中；自动百分比精度不足时整组改用共享直线。修改后调用 configure/update。
    public var stackedAreaUsesDivergingChains = false
    public var usesSharedTooltip = true
    public var tooltipOptions = HYMCartesianTooltipOptions()
    public var legendStartsNewRowPerGroup = false
    public var legendSymbolSize = CGSize(width: 22, height: 12)
    public var legendItemStyles: [String: HYMCartesianLegendItemStyle] = [:]
    public var isZoomEnabled = false
    /// 单点/拖动/共享命中都返回同一快照数组。取消选择由外部 UI 生命周期处理。
    public var onHit: (([HYMCartesianDatum]) -> Void)?
    public var onSeriesVisibilityChanged: ((String, Bool) -> Void)?
    private let kind: HYMCartesianChartKind
    private var apply: ((CartesianChartModel, CartesianChartTheme, Bool, HYMChartsSpecificationTooltipConfiguration?) -> Void)?
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
        apply = { [weak self] model, theme, preserve, tooltip in
            guard let self else { return }
            chart.showsTooltipOnHit = tooltip?.isEnabled ?? self.showsTooltip
            chart.isSharedTooltipOnTapEnabled = self.usesSharedTooltip
            chart.tooltipTextOptions = tooltip?.textOptions ?? self.tooltipOptions.build()
            let runtimePresentation = self.tooltipOptions.buildPresentation()
            chart.cartesianTooltipPresentation = tooltip?.presentation(preservingRuntime: runtimePresentation) ?? runtimePresentation
            chart.cartesianTooltipSampleSelection = tooltip?.sampleSelection ?? self.tooltipOptions.buildSampleSelection()
            let runtimeTheme = self.tooltipOptions.buildTooltipTheme(base: chart.tooltipTheme)
            chart.tooltipTheme = tooltip?.theme(preservingRuntime: runtimeTheme) ?? runtimeTheme
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

    /// 使用通用模型初次配置/重置；数据、系列样式、轴和图例取自 document。
    /// 非 nil 的 v6 Tooltip 覆盖 bridge 的内容/取值/位置；nil 恢复 bridge 设置。手势仍属宿主。
    /// 失败保留当前图表（包括提示/图例）；须在主线程调用。
    @objc(configureWithSpecification:error:)
    public func configure(specification: HYMChartSpecificationDocument) throws {
        try apply(specification, preserve: false)
    }

    /// 用新的不可变通用描述更新；preserveViewport 仅保留窗口，不跨更新恢复选点。
    @objc(updateWithSpecification:preserveViewport:error:)
    public func update(specification: HYMChartSpecificationDocument, preserveViewport: Bool) throws {
        try apply(specification, preserve: preserveViewport)
    }

    private func apply(_ document: HYMChartSpecificationDocument, preserve: Bool) throws {
        let configuration = try HYMChartsSpecificationAdapter().makeConfiguration(from: document.specification)
        guard configuration.kind == kind else {
            throw ChartSpecificationError(issues: [.init(code: .unsupportedCapability, path: "series/orientation",
                message: "描述所需图形与当前 bridge 类型不一致；请按 nativeChartKind 创建对应 bridge")],
                backendIdentifier: "hymcharts")
        }
        apply?(configuration.model, configuration.theme, preserve, configuration.tooltip)
    }

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
        theme.selection = selectionStyle.build()
        theme.showsDataLabels = showsDataLabels
        theme.showsStackTotalLabels = showsStackTotalLabels
        theme.dataLabelFontSize = dataLabelFontSize
        theme.dataLabelColor = dataLabelColor
        theme.dataLabelBackgroundColor = dataLabelBackgroundColor
        theme.dataLabelAvoidsOverlap = dataLabelAvoidsOverlap
        theme.legend.isEnabled = showsLegend
        theme.legend.startsNewRowPerGroup = legendStartsNewRowPerGroup
        theme.legend.symbolSize = legendSymbolSize
        theme.legend.itemOverrides = legendItemStyles.mapValues { $0.build() }
        theme.showsTooltipOnHit = showsTooltip
        theme.stackedAreaBoundaryMode = stackedAreaUsesDivergingChains ? .diverging
            : (stackedAreaFollowsBaseline ? .followBaseline : .independent)
        apply?(model.build(), theme, preserve, nil)
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
