import SwiftUI

/// 折线图 SwiftUI 封装（demo 配套最小版；完备参数面在路线图阶段 10 统一补齐）。
/// 数据/主题更新默认保留窗口；viewportUpdatePolicy 设为 .reset 可恢复逐次重置行为。
/// 更新时替换 onHit（包括移除闭包），入场动画只在首次创建时触发。
public struct LineChart: View {
    private let model: CartesianChartModel
    private let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((LineHitTarget, HYMChartGesture) -> Void)?
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
    private let tooltipTextOptions: HYMChartTooltipTextOptions
    private let onSeriesVisibilityChanged: ((String, Bool) -> Void)?
    private let viewportUpdatePolicy: HYMChartViewportUpdatePolicy

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((LineHitTarget, HYMChartGesture) -> Void)? = nil,
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
                onSeriesVisibilityChanged: ((String, Bool) -> Void)? = nil) {
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
        self.onSeriesVisibilityChanged = onSeriesVisibilityChanged
        self.viewportUpdatePolicy = viewportUpdatePolicy
    }

    public var body: some View {
        LineChartRepresentable(model: model, theme: theme,
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
                               onSeriesVisibilityChanged: onSeriesVisibilityChanged,
                               viewportUpdatePolicy: viewportUpdatePolicy)
    }
}

private struct LineChartRepresentable: UIViewRepresentable {
    let model: CartesianChartModel
    let theme: CartesianChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((LineHitTarget, HYMChartGesture) -> Void)?
    let isZoomEnabled: Bool
    let minimumVisibleCategories: Int
    let isDragDecelerationEnabled: Bool
    let isHighlightPerDragEnabled: Bool
    let isRubberBandEnabled: Bool
    let isSharedTooltipOnTapEnabled: Bool?
    let isCrosshairEnabled: Bool
    let zoomAxisMode: HYMChartZoomAxisMode
    let crosshairColor: UIColor
    let crosshairLineWidth: CGFloat
    let crosshairDashStyle: LineDashStyle
    let isCrosshairDualDirectionEnabled: Bool
    let tooltipTextOptions: HYMChartTooltipTextOptions
    let onSeriesVisibilityChanged: ((String, Bool) -> Void)?
    let viewportUpdatePolicy: HYMChartViewportUpdatePolicy

    func makeUIView(context: Context) -> HYMChartView<LineChartRenderer> {
        let chart = HYMChartView<LineChartRenderer>(frame: .zero)
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
        chart.onHit = { target, gesture in
            if let h = target as? LineHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear, theme.showsEntranceAnimation {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<LineChartRenderer>, context: Context) {
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
        // 每次更新替换回调，避免继续调用 makeUIView 时捕获的旧闭包。
        uiView.onHit = onHit.map { callback in
            { target, gesture in
                if let hit = target as? LineHitTarget { callback(hit, gesture) }
            }
        }
        uiView.update(model: model, theme: theme, viewportPolicy: viewportUpdatePolicy)
    }
}
