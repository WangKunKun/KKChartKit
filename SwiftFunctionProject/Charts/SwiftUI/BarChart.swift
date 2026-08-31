import SwiftUI

/// 条形图 SwiftUI 封装（demo 配套最小版）
public struct BarChart: View {
    private let model: CartesianChartModel
    private let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((BarHitTarget, HYMChartGesture) -> Void)?
    private let isZoomEnabled: Bool
    private let minimumVisibleCategories: Int
    private let isDragDecelerationEnabled: Bool
    private let isHighlightPerDragEnabled: Bool
    private let isRubberBandEnabled: Bool
    private let isSharedTooltipOnTapEnabled: Bool?
    private let isCrosshairEnabled: Bool
    private let zoomAxisMode: HYMChartZoomAxisMode

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((BarHitTarget, HYMChartGesture) -> Void)? = nil,
                isZoomEnabled: Bool = false,
                minimumVisibleCategories: Int = 12,
                isDragDecelerationEnabled: Bool = true,
                isHighlightPerDragEnabled: Bool = true,
                isRubberBandEnabled: Bool = true,
                isSharedTooltipOnTapEnabled: Bool? = nil,
                isCrosshairEnabled: Bool = true,
                zoomAxisMode: HYMChartZoomAxisMode = .x) {
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
    }

    public var body: some View {
        BarChartRepresentable(model: model, theme: theme,
                               playsAnimationOnAppear: playsAnimationOnAppear,
                               onHit: onHit,
                               isZoomEnabled: isZoomEnabled,
                               minimumVisibleCategories: minimumVisibleCategories,
                               isDragDecelerationEnabled: isDragDecelerationEnabled,
                               isHighlightPerDragEnabled: isHighlightPerDragEnabled,
                               isRubberBandEnabled: isRubberBandEnabled,
                               isSharedTooltipOnTapEnabled: isSharedTooltipOnTapEnabled,
                               isCrosshairEnabled: isCrosshairEnabled,
                               zoomAxisMode: zoomAxisMode)
    }
}

public struct BarChartRepresentable: UIViewRepresentable {
    public let model: CartesianChartModel
    public let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    public let onHit: ((BarHitTarget, HYMChartGesture) -> Void)?
    private let isZoomEnabled: Bool
    private let minimumVisibleCategories: Int
    private let isDragDecelerationEnabled: Bool
    private let isHighlightPerDragEnabled: Bool
    private let isRubberBandEnabled: Bool
    private let isSharedTooltipOnTapEnabled: Bool?
    private let isCrosshairEnabled: Bool
    private let zoomAxisMode: HYMChartZoomAxisMode

    public init(model: CartesianChartModel, theme: CartesianChartTheme, playsAnimationOnAppear: Bool, onHit: ((BarHitTarget, HYMChartGesture) -> Void)?, isZoomEnabled: Bool, minimumVisibleCategories: Int,
                isDragDecelerationEnabled: Bool,
                isHighlightPerDragEnabled: Bool,
                isRubberBandEnabled: Bool,
                isSharedTooltipOnTapEnabled: Bool?,
                isCrosshairEnabled: Bool,
                zoomAxisMode: HYMChartZoomAxisMode) {
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
    }

    public func makeUIView(context: Context) -> HYMChartView<BarChartRenderer> {
        let chart = HYMChartView<BarChartRenderer>(frame: .zero)
        chart.showsTooltipOnHit = true
        chart.isZoomEnabled = isZoomEnabled
        chart.minimumVisibleCategories = minimumVisibleCategories
        chart.isDragDecelerationEnabled = isDragDecelerationEnabled
        chart.isHighlightPerDragEnabled = isHighlightPerDragEnabled
        chart.isRubberBandEnabled = isRubberBandEnabled
        chart.isSharedTooltipOnTapEnabled = isSharedTooltipOnTapEnabled
        chart.isCrosshairEnabled = isCrosshairEnabled
        chart.zoomAxisMode = zoomAxisMode
        chart.onHit = { target, gesture in
            if let h = target as? BarHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear, theme.showsColumnEntranceAnimation {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    public func updateUIView(_ uiView: HYMChartView<BarChartRenderer>, context: Context) {
        // 交互开关同步：demo 里拨动开关时 SwiftUI 不重建 UIView，须在此回写才实时生效
        uiView.isZoomEnabled = isZoomEnabled
        uiView.minimumVisibleCategories = minimumVisibleCategories
        uiView.isDragDecelerationEnabled = isDragDecelerationEnabled
        uiView.isHighlightPerDragEnabled = isHighlightPerDragEnabled
        uiView.isRubberBandEnabled = isRubberBandEnabled
        uiView.isSharedTooltipOnTapEnabled = isSharedTooltipOnTapEnabled
        uiView.isCrosshairEnabled = isCrosshairEnabled
        uiView.zoomAxisMode = zoomAxisMode
        uiView.configure(model: model, theme: theme)
    }
}