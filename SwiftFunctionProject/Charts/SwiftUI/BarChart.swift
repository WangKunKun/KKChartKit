import SwiftUI

/// 条形图 SwiftUI 封装（demo 配套最小版）
public struct BarChart: View {
    private let model: CartesianChartModel
    private let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    private let onHit: ((BarHitTarget, HYMChartGesture) -> Void)?
    private let isZoomEnabled: Bool

    public init(model: CartesianChartModel,
                theme: CartesianChartTheme = CartesianChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((BarHitTarget, HYMChartGesture) -> Void)? = nil,
                isZoomEnabled: Bool = false) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
        self.isZoomEnabled = isZoomEnabled
    }

    public var body: some View {
        BarChartRepresentable(model: model, theme: theme,
                               playsAnimationOnAppear: playsAnimationOnAppear,
                               onHit: onHit,
                               isZoomEnabled: isZoomEnabled)
    }
}

public struct BarChartRepresentable: UIViewRepresentable {
    public let model: CartesianChartModel
    public let theme: CartesianChartTheme
    private let playsAnimationOnAppear: Bool
    public let onHit: ((BarHitTarget, HYMChartGesture) -> Void)?
    private let isZoomEnabled: Bool

    public init(model: CartesianChartModel, theme: CartesianChartTheme, playsAnimationOnAppear: Bool, onHit: ((BarHitTarget, HYMChartGesture) -> Void)?, isZoomEnabled: Bool) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
        self.isZoomEnabled = isZoomEnabled
    }

    public func makeUIView(context: Context) -> HYMChartView<BarChartRenderer> {
        let chart = HYMChartView<BarChartRenderer>(frame: .zero)
        chart.showsTooltipOnHit = true
        chart.isZoomEnabled = isZoomEnabled
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
        uiView.configure(model: model, theme: theme)
    }
}