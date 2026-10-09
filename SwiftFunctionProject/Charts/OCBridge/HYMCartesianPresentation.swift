import UIKit

@objc public enum HYMCartesianTooltipLayout: Int { case text, columns }
@objc public enum HYMCartesianTooltipSampleBoundaryPolicy: Int { case omit, clamp, current }
@objc public enum HYMCartesianTooltipPosition: Int { case automatic, fixedTop }

/// OC 逐点提示覆盖；通过 tooltipOptions.rowStyleProvider 返回。nil 使用默认行。
@objcMembers public final class HYMCartesianTooltipRowStyle: NSObject {
    public var title: String?
    public var image: UIImage?
    public var isHidden = false
    public var hidesValue = false
    func build() -> CartesianTooltipRowStyle {
        .init(title: title, image: image, isHidden: isHidden, hidesValue: hidesValue)
    }
}

/// OC 内置提示配置；修改后调用 bridge.configure/update。所有 UI 接口在主线程使用。
@objcMembers public final class HYMCartesianTooltipOptions: NSObject {
    public var header: String?
    public var valueSuffix: String?
    public var valueDecimals: NSNumber?
    public var groupsByBusinessID = false
    public var showsGroupSubtotals = false
    public var hidesZeroValues = false
    public var excludedSeriesIDs: [String] = []
    public var ungroupedTitle = "未分组"
    public var subtotalTitle = "小计"
    public var layout: HYMCartesianTooltipLayout = .text
    /// 主线程执行；请使用 seriesID/sourceRange 判断，避免强捕获 bridge。
    public var rowStyleProvider: ((HYMCartesianDatum) -> HYMCartesianTooltipRowStyle?)?
    public var iconSize: CGFloat = 16
    public var rowSpacing: CGFloat = 4
    public var columnSpacing: CGFloat = 10
    public var sectionSpacing: CGFloat = 8
    public var showsSectionSeparators = true

    /// 相对命中原始索引取值。-1 为前值；实际时间聚合时保留当前统计桶。
    public var sampleOffset = 0
    public var sampleOffsetsBySeriesID: [String: NSNumber] = [:]
    public var sampleBoundaryPolicy: HYMCartesianTooltipSampleBoundaryPolicy = .omit
    public var showsSourceLabel = true
    public var sourceLabelTemplate = "取值 {key}"
    public var position: HYMCartesianTooltipPosition = .automatic
    public var offset: CGPoint = .zero
    public var fixedTopInset: CGFloat = 8
    /// 固定顶部提示限制在绘图区，避开标题/图例/轴标签；默认 false 保留原生定位。
    public var fixedTopUsesPlotArea = false

    func buildSampleSelection() -> CartesianTooltipSampleSelection {
        var result = CartesianTooltipSampleSelection()
        result.offset = sampleOffset
        result.offsetsBySeriesID = sampleOffsetsBySeriesID.mapValues(\.intValue)
        switch sampleBoundaryPolicy {
        case .omit: result.boundaryPolicy = .omit
        case .clamp: result.boundaryPolicy = .clamp
        case .current: result.boundaryPolicy = .current
        }
        result.showsSourceLabel = showsSourceLabel; result.sourceLabelTemplate = sourceLabelTemplate
        return result
    }

    func buildTooltipTheme(base: HYMChartTooltipTheme = .default) -> HYMChartTooltipTheme {
        var result = base
        result.position = position == .fixedTop ? .fixedTop : .automatic
        result.offset = offset; result.fixedTopInset = fixedTopInset
        result.fixedTopUsesPlotArea = fixedTopUsesPlotArea
        return result
    }

    func buildPresentation() -> CartesianTooltipPresentation {
        var result = CartesianTooltipPresentation()
        result.layout = layout == .columns ? .columns : .text
        result.iconSize = iconSize; result.rowSpacing = rowSpacing
        result.columnSpacing = columnSpacing; result.sectionSpacing = sectionSpacing
        result.showsSectionSeparators = showsSectionSeparators
        if let provider = rowStyleProvider { result.rowStyleProvider = { provider(HYMCartesianDatum($0))?.build() } }
        return result
    }

    func build() -> HYMChartTooltipTextOptions {
        var options = CartesianTooltipOptions()
        options.groupsByBusinessID = groupsByBusinessID
        options.showsGroupSubtotals = showsGroupSubtotals
        options.hidesZeroValues = hidesZeroValues
        options.excludedSeriesIDs = Set(excludedSeriesIDs)
        options.ungroupedTitle = ungroupedTitle; options.subtotalTitle = subtotalTitle
        return .init(header: header, valueSuffix: valueSuffix,
                     valueDecimals: valueDecimals.map { min(12, max(0, $0.intValue)) }, cartesian: options)
    }
}

/// OC 图例覆盖；字典 key 使用稳定系列 identifier。尺寸沿用 bridge.legendSymbolSize。
/// provider 在主线程每次更新调用，返回专属于该项的符号视图；避免强捕获 bridge。
@objcMembers public final class HYMCartesianLegendItemStyle: NSObject {
    public var title: String?
    public var symbolColor: UIColor?
    public var image: UIImage?
    public var hiddenImage: UIImage?
    public var backgroundColor: UIColor?
    public var cornerRadius: CGFloat = 0
    public var symbolViewProvider: ((Bool) -> UIView?)?

    func build() -> LegendItemStyle {
        .init(title: title, symbolColor: symbolColor, image: image, hiddenImage: hiddenImage,
              backgroundColor: backgroundColor, cornerRadius: cornerRadius,
              symbolViewProvider: symbolViewProvider)
    }
}
