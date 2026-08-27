import SwiftUI

/// 柱状图 SwiftUI 封装（demo 配套最小版）
public struct ColumnChart: View {
    private let model: CartesianChartModel
    private let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
    }

    public var body: some View {
        ColumnChartRepresentable(model: model, theme: theme,
                               playsAnimationOnAppear: playsAnimationOnAppear,
                               onHit: onHit)
    }
}

private struct ColumnChartRepresentable: UIViewRepresentable {
    let model: CartesianChartModel
    let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    let onHit: ((ColumnHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<ColumnChartRenderer> {
        let chart = HYMChartView<ColumnChartRenderer>(frame: .zero)
        chart.showsTooltipOnHit = true
        chart.onHit = { target, gesture in
            if let h = target as? ColumnHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear, theme.showsColumnEntranceAnimation {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<ColumnChartRenderer>, context: Context) {
        uiView.configure(model: model, theme: theme)
    }
}
