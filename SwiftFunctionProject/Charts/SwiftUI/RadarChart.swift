import SwiftUI

/// SwiftUI 雷达图封装（UIViewRepresentable 包装通用容器）
public struct RadarChart: View {
    private let model: RadarChartModel
    private let theme: RadarChartTheme
    private let playsAnimationOnAppear: Bool
    /// 命中回调（构造期注入；本期雷达无命中目标，预留）
    private let onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    public init(model: RadarChartModel,
                theme: RadarChartTheme = RadarChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
    }

    public var body: some View {
        RadarChartRepresentable(model: model, theme: theme,
                                playsAnimationOnAppear: playsAnimationOnAppear, onHit: onHit)
    }
}

struct RadarChartRepresentable: UIViewRepresentable {
    let model: RadarChartModel
    let theme: RadarChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<RadarChartRenderer> {
        let chart = HYMChartView<RadarChartRenderer>(frame: .zero)
        chart.onHit = onHit
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear {
            // 延后一个 runloop，确保 layoutSubviews 已执行
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<RadarChartRenderer>, context: Context) {
        uiView.onHit = onHit
        uiView.configure(model: model, theme: theme)
    }
}
