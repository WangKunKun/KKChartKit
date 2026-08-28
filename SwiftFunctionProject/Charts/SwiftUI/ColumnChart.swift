import SwiftUI

/// 柱状图 SwiftUI 封装（demo 配套最小版）
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

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)? = nil,
                isZoomEnabled: Bool = false,
                minimumVisibleCategories: Int = 12,
                isDragDecelerationEnabled: Bool = true,
                isHighlightPerDragEnabled: Bool = true,
                isRubberBandEnabled: Bool = true,
                isSharedTooltipOnTapEnabled: Bool? = nil) {
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
                               isSharedTooltipOnTapEnabled: isSharedTooltipOnTapEnabled)
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

    public init(model: CartesianChartModel, theme: CartesianChartTheme, playsAnimationOnAppear: Bool, onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?, isZoomEnabled: Bool, minimumVisibleCategories: Int,
                isDragDecelerationEnabled: Bool,
                isHighlightPerDragEnabled: Bool,
                isRubberBandEnabled: Bool,
                isSharedTooltipOnTapEnabled: Bool?) {
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
    }

    public func makeUIView(context: Context) -> HYMChartView<ColumnChartRenderer> {
        let chart = HYMChartView<ColumnChartRenderer>(frame: .zero)
        chart.showsTooltipOnHit = true
        chart.isZoomEnabled = isZoomEnabled
        chart.minimumVisibleCategories = minimumVisibleCategories
        chart.isDragDecelerationEnabled = isDragDecelerationEnabled
        chart.isHighlightPerDragEnabled = isHighlightPerDragEnabled
        chart.isRubberBandEnabled = isRubberBandEnabled
        chart.isSharedTooltipOnTapEnabled = isSharedTooltipOnTapEnabled
        chart.onHit = { target, gesture in
            if let h = target as? ColumnHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear, theme.showsColumnEntranceAnimation {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    public func updateUIView(_ uiView: HYMChartView<ColumnChartRenderer>, context: Context) {
        uiView.configure(model: model, theme: theme)
    }
}