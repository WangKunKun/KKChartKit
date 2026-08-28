import SwiftUI

/// 折线图 SwiftUI 封装（demo 配套最小版；完备参数面在路线图阶段 10 统一补齐）。
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

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((LineHitTarget, HYMChartGesture) -> Void)? = nil,
                isZoomEnabled: Bool = false,
                minimumVisibleCategories: Int = 12,
                isDragDecelerationEnabled: Bool = true,
                isHighlightPerDragEnabled: Bool = true,
                isRubberBandEnabled: Bool = true) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
        self.isZoomEnabled = isZoomEnabled
        self.minimumVisibleCategories = minimumVisibleCategories
        self.isDragDecelerationEnabled = isDragDecelerationEnabled
        self.isHighlightPerDragEnabled = isHighlightPerDragEnabled
        self.isRubberBandEnabled = isRubberBandEnabled
    }

    public var body: some View {
        LineChartRepresentable(model: model, theme: theme,
                               playsAnimationOnAppear: playsAnimationOnAppear,
                               onHit: onHit,
                               isZoomEnabled: isZoomEnabled,
                               minimumVisibleCategories: minimumVisibleCategories,
                               isDragDecelerationEnabled: isDragDecelerationEnabled,
                               isHighlightPerDragEnabled: isHighlightPerDragEnabled,
                               isRubberBandEnabled: isRubberBandEnabled)
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

    func makeUIView(context: Context) -> HYMChartView<LineChartRenderer> {
        let chart = HYMChartView<LineChartRenderer>(frame: .zero)
        chart.showsTooltipOnHit = true
        chart.isZoomEnabled = isZoomEnabled
        chart.minimumVisibleCategories = minimumVisibleCategories
        chart.isDragDecelerationEnabled = isDragDecelerationEnabled
        chart.isHighlightPerDragEnabled = isHighlightPerDragEnabled
        chart.isRubberBandEnabled = isRubberBandEnabled
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
        uiView.configure(model: model, theme: theme)
    }
}
