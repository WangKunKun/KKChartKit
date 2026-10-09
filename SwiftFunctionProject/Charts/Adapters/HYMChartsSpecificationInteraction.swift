import UIKit

/// 已校验的中立提示配置的原生快照；主线程构造/使用，不拥有 view 或运行时 provider。
/// 不要只应用 model/theme 而遗漏本配置。nil 配置表示保留宿主设置。
public struct HYMChartsSpecificationTooltipConfiguration {
    private let source: ChartTooltipSpecification
    init(_ source: ChartTooltipSpecification) { self.source = source }
    public var isEnabled: Bool { source.isEnabled }
    /// 中立配置使用平铺内容，不推断业务分组/小计；数值仍使用系列自身格式与单位。
    public var textOptions: HYMChartTooltipTextOptions {
        var options = CartesianTooltipOptions(); options.hidesZeroValues = source.hidesZeroValues
        return .init(header: source.headerTemplate, cartesian: options)
    }
    public var sampleSelection: CartesianTooltipSampleSelection {
        let input = source.sampleSelection
        var result = CartesianTooltipSampleSelection()
        result.offset = input.offset; result.offsetsBySeriesID = input.offsetsBySeriesID
        switch input.boundaryPolicy {
        case .omit: result.boundaryPolicy = .omit
        case .clamp: result.boundaryPolicy = .clamp
        case .current: result.boundaryPolicy = .current
        }
        result.showsSourceLabel = input.showsSourceLabel; result.sourceLabelTemplate = input.sourceLabelTemplate
        return result
    }
    /// 从独立宿主配置构造，不将前一次适配结果当作 runtime 反复叠加。
    /// runtime provider 仍可供给图片/未覆盖行；匹配规则时中立标题（非 nil）、显隐/数值开关优先。
    public func presentation(preservingRuntime runtime: CartesianTooltipPresentation = .init()) -> CartesianTooltipPresentation {
        var result = runtime
        result.layout = source.layout == .columns ? .columns : .text
        let rules = source.seriesRules, provider = runtime.rowStyleProvider
        result.rowStyleProvider = { datum in
            var style = provider?(datum) ?? .init()
            if let rule = rules[datum.seriesID] {
                if let title = rule.title { style.title = title }
                style.isHidden = rule.isHidden; style.hidesValue = rule.hidesValue
            }
            return style
        }
        return result
    }
    /// 覆盖位置；fixedTop 默认限制在绘图区以避开标题/图例，不预留额外空间。
    /// automatic 保留宿主的 fixedTopUsesPlotArea 值（此时不生效）；颜色、字体、偏移和动画仍由宿主控制。
    public func theme(preservingRuntime runtime: HYMChartTooltipTheme = .default) -> HYMChartTooltipTheme {
        var result = runtime; result.position = source.position == .fixedTop ? .fixedTop : .automatic
        if source.position == .fixedTop { result.fixedTopUsesPlotArea = true }
        return result
    }
}

public extension HYMChartsSpecificationConfiguration {
    /// v1–v5 或 v6 null 返回 nil；宿主应显式保留/恢复自身提示配置，不能沿用上次中立覆盖。
    var tooltip: HYMChartsSpecificationTooltipConfiguration? { source.tooltip.map(HYMChartsSpecificationTooltipConfiguration.init) }
}

extension ChartLegendSpecification {
    func nativeConfiguration(isEnabled: Bool) -> ChartLegendConfiguration {
        var result = ChartLegendConfiguration(); result.isEnabled = isEnabled
        switch position {
        case .top: result.position = .top
        case .bottom: result.position = .bottom
        case .left: result.position = .left
        case .right: result.position = .right
        }
        switch alignment {
        case .leading: result.alignment = .leading
        case .center: result.alignment = .center
        case .trailing: result.alignment = .trailing
        }
        result.overflow = overflow == .scroll ? .scroll : .expand
        result.maxRows = maxRows; result.maxHeight = CGFloat(maxHeight); result.maxWidth = CGFloat(maxWidth)
        result.allowsToggling = allowsToggling; result.startsNewRowPerGroup = startsNewRowPerGroup
        result.itemOverrides = titlesBySeriesID.mapValues { .init(title: $0) }
        return result
    }
}
