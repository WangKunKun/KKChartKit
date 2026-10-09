import SwiftUI

/// 柱状图 SwiftUI 封装（demo 配套最小版）
/// 数据/主题更新默认保留窗口；viewportUpdatePolicy 设为 .reset 可恢复逐次重置行为。
/// 更新时替换 onHit（包括移除闭包），入场动画只在首次创建时触发。
public struct ColumnChart: View {
    private let model: CartesianChartModel
    private let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?
    private let isZoomEnabled: Bool
    private let minimumVisibleCategories: Int
    private let isDragDecelerationEnabled: Bool
    private let isHighlightPerDragEnabled: Bool
    private let isRubberBandEnabled: Bool
    private let isSharedTooltipOnTapEnabled: Bool?
    private let isCrosshairEnabled: Bool
    private let zoomAxisMode: HYMChartZoomAxisMode
    private let crosshairColor: UIColor
    private let crosshairLineWidth: CGFloat
    private let crosshairDashStyle: LineDashStyle
    private let isCrosshairDualDirectionEnabled: Bool
    private let cartesianTooltipPresentation: CartesianTooltipPresentation
    private let cartesianTooltipSampleSelection: CartesianTooltipSampleSelection
    private let tooltipTheme: HYMChartTooltipTheme
    private let tooltipTextOptions: HYMChartTooltipTextOptions
    private let onSeriesVisibilityChanged: ((String, Bool) -> Void)?
    /// 初次创建或范围变化时定位；其余更新保留用户手势窗口。nil 恢复全量。
    private let visibleCategoryRange: Range<Int>?
    private let viewportUpdatePolicy: HYMChartViewportUpdatePolicy

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)? = nil,
                isZoomEnabled: Bool = false,
                minimumVisibleCategories: Int = 12,
                isDragDecelerationEnabled: Bool = true,
                isHighlightPerDragEnabled: Bool = true,
                isRubberBandEnabled: Bool = true,
                isSharedTooltipOnTapEnabled: Bool? = nil,
                isCrosshairEnabled: Bool = true,
                zoomAxisMode: HYMChartZoomAxisMode = .x,
                crosshairColor: UIColor = UIColor(white: 0.55, alpha: 0.9),
                crosshairLineWidth: CGFloat = 0.75,
                crosshairDashStyle: LineDashStyle = .solid,
                isCrosshairDualDirectionEnabled: Bool = false,
                tooltipTextOptions: HYMChartTooltipTextOptions = HYMChartTooltipTextOptions(),
                viewportUpdatePolicy: HYMChartViewportUpdatePolicy = .preserve,
                onSeriesVisibilityChanged: ((String, Bool) -> Void)? = nil,
                visibleCategoryRange: Range<Int>? = nil,
                cartesianTooltipPresentation: CartesianTooltipPresentation = .init(),
                cartesianTooltipSampleSelection: CartesianTooltipSampleSelection = .init(),
                tooltipTheme: HYMChartTooltipTheme = .default) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
        self.isZoomEnabled = isZoomEnabled
        self.minimumVisibleCategories = minimumVisibleCategories
        self.isDragDecelerationEnabled = isDragDecelerationEnabled
        self.isHighlightPerDragEnabled = isHighlightPerDragEnabled
        self.isRubberBandEnabled = isRubberBandEnabled
        self.isSharedTooltipOnTapEnabled = isSharedTooltipOnTapEnabled
        self.isCrosshairEnabled = isCrosshairEnabled
        self.zoomAxisMode = zoomAxisMode
        self.crosshairColor = crosshairColor
        self.crosshairLineWidth = crosshairLineWidth
        self.crosshairDashStyle = crosshairDashStyle
        self.isCrosshairDualDirectionEnabled = isCrosshairDualDirectionEnabled
        self.tooltipTextOptions = tooltipTextOptions
        self.cartesianTooltipPresentation = cartesianTooltipPresentation
        self.cartesianTooltipSampleSelection = cartesianTooltipSampleSelection
        self.tooltipTheme = tooltipTheme
        self.visibleCategoryRange = visibleCategoryRange
        self.onSeriesVisibilityChanged = onSeriesVisibilityChanged
        self.viewportUpdatePolicy = viewportUpdatePolicy
    }

    public var body: some View {
        ColumnChartRepresentable(model: model, theme: theme,
                               playsAnimationOnAppear: playsAnimationOnAppear,
                               onHit: onHit,
                               isZoomEnabled: isZoomEnabled,
                               minimumVisibleCategories: minimumVisibleCategories,
                               isDragDecelerationEnabled: isDragDecelerationEnabled,
                               isHighlightPerDragEnabled: isHighlightPerDragEnabled,
                               isRubberBandEnabled: isRubberBandEnabled,
                               isSharedTooltipOnTapEnabled: isSharedTooltipOnTapEnabled,
                               isCrosshairEnabled: isCrosshairEnabled,
                               zoomAxisMode: zoomAxisMode,
                               crosshairColor: crosshairColor,
                               crosshairLineWidth: crosshairLineWidth,
                               crosshairDashStyle: crosshairDashStyle,
                               isCrosshairDualDirectionEnabled: isCrosshairDualDirectionEnabled,
                               tooltipTextOptions: tooltipTextOptions,
                               viewportUpdatePolicy: viewportUpdatePolicy,
                               onSeriesVisibilityChanged: onSeriesVisibilityChanged,
                               visibleCategoryRange: visibleCategoryRange,
                               cartesianTooltipPresentation: cartesianTooltipPresentation,
                               cartesianTooltipSampleSelection: cartesianTooltipSampleSelection,
                               tooltipTheme: tooltipTheme)
    }
}

public struct ColumnChartRepresentable: UIViewRepresentable {
    public let model: CartesianChartModel
    public let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    public let onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?
    private let isZoomEnabled: Bool
    private let minimumVisibleCategories: Int
    private let isDragDecelerationEnabled: Bool
    private let isHighlightPerDragEnabled: Bool
    private let isRubberBandEnabled: Bool
    private let isSharedTooltipOnTapEnabled: Bool?
    private let isCrosshairEnabled: Bool
    private let zoomAxisMode: HYMChartZoomAxisMode
    private let crosshairColor: UIColor
    private let crosshairLineWidth: CGFloat
    private let crosshairDashStyle: LineDashStyle
    private let isCrosshairDualDirectionEnabled: Bool
    private let cartesianTooltipPresentation: CartesianTooltipPresentation
    private let cartesianTooltipSampleSelection: CartesianTooltipSampleSelection
    private let tooltipTheme: HYMChartTooltipTheme
    private let tooltipTextOptions: HYMChartTooltipTextOptions
    private let onSeriesVisibilityChanged: ((String, Bool) -> Void)?
    /// 初次创建或范围变化时定位；其余更新保留用户手势窗口。nil 恢复全量。
    private let visibleCategoryRange: Range<Int>?
    private let viewportUpdatePolicy: HYMChartViewportUpdatePolicy

    public init(model: CartesianChartModel, theme: CartesianChartTheme, playsAnimationOnAppear: Bool, onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?, isZoomEnabled: Bool, minimumVisibleCategories: Int,
                isDragDecelerationEnabled: Bool,
                isHighlightPerDragEnabled: Bool,
                isRubberBandEnabled: Bool,
                isSharedTooltipOnTapEnabled: Bool?,
                isCrosshairEnabled: Bool,
                zoomAxisMode: HYMChartZoomAxisMode,
                crosshairColor: UIColor,
                crosshairLineWidth: CGFloat,
                crosshairDashStyle: LineDashStyle,
                isCrosshairDualDirectionEnabled: Bool,
                tooltipTextOptions: HYMChartTooltipTextOptions,
                viewportUpdatePolicy: HYMChartViewportUpdatePolicy = .preserve,
                onSeriesVisibilityChanged: ((String, Bool) -> Void)? = nil,
                visibleCategoryRange: Range<Int>? = nil,
                cartesianTooltipPresentation: CartesianTooltipPresentation = .init(),
                cartesianTooltipSampleSelection: CartesianTooltipSampleSelection = .init(),
                tooltipTheme: HYMChartTooltipTheme = .default) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
        self.isZoomEnabled = isZoomEnabled
        self.minimumVisibleCategories = minimumVisibleCategories
        self.isDragDecelerationEnabled = isDragDecelerationEnabled
        self.isHighlightPerDragEnabled = isHighlightPerDragEnabled
        self.isRubberBandEnabled = isRubberBandEnabled
        self.isSharedTooltipOnTapEnabled = isSharedTooltipOnTapEnabled
        self.isCrosshairEnabled = isCrosshairEnabled
        self.zoomAxisMode = zoomAxisMode
        self.crosshairColor = crosshairColor
        self.crosshairLineWidth = crosshairLineWidth
        self.crosshairDashStyle = crosshairDashStyle
        self.isCrosshairDualDirectionEnabled = isCrosshairDualDirectionEnabled
        self.tooltipTextOptions = tooltipTextOptions
        self.cartesianTooltipPresentation = cartesianTooltipPresentation
        self.cartesianTooltipSampleSelection = cartesianTooltipSampleSelection
        self.tooltipTheme = tooltipTheme
        self.visibleCategoryRange = visibleCategoryRange
        self.onSeriesVisibilityChanged = onSeriesVisibilityChanged
        self.viewportUpdatePolicy = viewportUpdatePolicy
    }

    public final class Coordinator {
        var lastRequestedRange: Range<Int>?
    }
    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeUIView(context: Context) -> HYMChartView<ColumnChartRenderer> {
        let chart = HYMChartView<ColumnChartRenderer>(frame: .zero)
        chart.onSeriesVisibilityChanged = onSeriesVisibilityChanged
        chart.showsTooltipOnHit = true
        chart.isZoomEnabled = isZoomEnabled
        chart.minimumVisibleCategories = minimumVisibleCategories
        chart.isDragDecelerationEnabled = isDragDecelerationEnabled
        chart.isHighlightPerDragEnabled = isHighlightPerDragEnabled
        chart.isRubberBandEnabled = isRubberBandEnabled
        chart.isSharedTooltipOnTapEnabled = isSharedTooltipOnTapEnabled
        chart.isCrosshairEnabled = isCrosshairEnabled
        chart.zoomAxisMode = zoomAxisMode
        chart.crosshairColor = crosshairColor
        chart.crosshairLineWidth = crosshairLineWidth
        chart.crosshairDashStyle = crosshairDashStyle
        chart.isCrosshairDualDirectionEnabled = isCrosshairDualDirectionEnabled
        chart.tooltipTextOptions = tooltipTextOptions
        chart.cartesianTooltipPresentation = cartesianTooltipPresentation
        chart.cartesianTooltipSampleSelection = cartesianTooltipSampleSelection
        chart.tooltipTheme = tooltipTheme
        chart.onHit = { target, gesture in
            if let h = target as? ColumnHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear, theme.showsColumnEntranceAnimation {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        if let visibleCategoryRange { chart.showCategoryRange(visibleCategoryRange) }
        context.coordinator.lastRequestedRange = visibleCategoryRange
        return chart
    }

    public func updateUIView(_ uiView: HYMChartView<ColumnChartRenderer>, context: Context) {
        uiView.onSeriesVisibilityChanged = onSeriesVisibilityChanged
        // 交互开关同步：demo 里拨动开关时 SwiftUI 不重建 UIView，须在此回写才实时生效
        uiView.isZoomEnabled = isZoomEnabled
        uiView.minimumVisibleCategories = minimumVisibleCategories
        uiView.isDragDecelerationEnabled = isDragDecelerationEnabled
        uiView.isHighlightPerDragEnabled = isHighlightPerDragEnabled
        uiView.isRubberBandEnabled = isRubberBandEnabled
        uiView.isSharedTooltipOnTapEnabled = isSharedTooltipOnTapEnabled
        uiView.isCrosshairEnabled = isCrosshairEnabled
        uiView.zoomAxisMode = zoomAxisMode
        uiView.crosshairColor = crosshairColor
        uiView.crosshairLineWidth = crosshairLineWidth
        uiView.crosshairDashStyle = crosshairDashStyle
        uiView.isCrosshairDualDirectionEnabled = isCrosshairDualDirectionEnabled
        uiView.tooltipTextOptions = tooltipTextOptions
        uiView.cartesianTooltipPresentation = cartesianTooltipPresentation
        uiView.cartesianTooltipSampleSelection = cartesianTooltipSampleSelection
        uiView.tooltipTheme = tooltipTheme
        // 每次更新替换回调，避免继续调用 makeUIView 时捕获的旧闭包。
        uiView.onHit = onHit.map { callback in
            { target, gesture in
                if let hit = target as? ColumnHitTarget { callback(hit, gesture) }
            }
        }
        uiView.update(model: model, theme: theme, viewportPolicy: viewportUpdatePolicy)
        if context.coordinator.lastRequestedRange != visibleCategoryRange
            || (viewportUpdatePolicy == .reset && visibleCategoryRange != nil) {
            if let visibleCategoryRange { uiView.showCategoryRange(visibleCategoryRange) }
            else { uiView.resetViewport() }
            context.coordinator.lastRequestedRange = visibleCategoryRange
        }
    }
}