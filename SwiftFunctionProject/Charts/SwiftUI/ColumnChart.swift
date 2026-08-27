import SwiftUI

/// 柱状图 SwiftUI 封装（demo 配套最小版）
public struct ColumnChart: View {
    private let model: CartesianChartModel
    private let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?
    private let isZoomEnabled: Bool
    private let minimumVisibleCategories: Int

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)? = nil,
                isZoomEnabled: Bool = false,
                minimumVisibleCategories: Int = 12) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
        self.isZoomEnabled = isZoomEnabled
        self.minimumVisibleCategories = minimumVisibleCategories
    }

    public var body: some View {
        ColumnChartRepresentable(model: model, theme: theme,
                               playsAnimationOnAppear: playsAnimationOnAppear,
                               onHit: onHit,
                               isZoomEnabled: isZoomEnabled,
                               minimumVisibleCategories: minimumVisibleCategories)
    }
}

public struct ColumnChartRepresentable: UIViewRepresentable {
    public let model: CartesianChartModel
    public let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    public let onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?
    private let isZoomEnabled: Bool
    private let minimumVisibleCategories: Int

    public init(model: CartesianChartModel, theme: CartesianChartTheme, playsAnimationOnAppear: Bool, onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?, isZoomEnabled: Bool, minimumVisibleCategories: Int) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
        self.isZoomEnabled = isZoomEnabled
        self.minimumVisibleCategories = minimumVisibleCategories
    }

    public func makeUIView(context: Context) -> HYMChartView<ColumnChartRenderer> {
        let chart = HYMChartView<ColumnChartRenderer>(frame: .zero)
        chart.showsTooltipOnHit = true
        chart.isZoomEnabled = isZoomEnabled
        chart.minimumVisibleCategories = minimumVisibleCategories
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