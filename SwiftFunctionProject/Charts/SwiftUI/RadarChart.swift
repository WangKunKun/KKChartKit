import SwiftUI

/// SwiftUI 雷达图封装（UIViewRepresentable 包装通用容器）
public struct RadarChart: View {
    private let model: RadarChartModel
    private var theme: RadarChartTheme
    private let playsAnimationOnAppear: Bool
    /// 命中回调：点中数据顶点/标题顶点时触发，携带 RadarHitTarget（category + dimensionIndex）
    private let onHit: ((RadarHitTarget, HYMChartGesture) -> Void)?

    public init(model: RadarChartModel,
                theme: RadarChartTheme = RadarChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((RadarHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
    }

    public var body: some View {
        RadarChartRepresentable(model: model, theme: theme,
                                playsAnimationOnAppear: playsAnimationOnAppear,
                                onHit: onHit)
    }
}

struct RadarChartRepresentable: UIViewRepresentable {
    let model: RadarChartModel
    let theme: RadarChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((RadarHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<RadarChartRenderer> {
        let chart = HYMChartView<RadarChartRenderer>(frame: .zero)
        // 容器 onHit 是 any HYMChartHitTarget；此处 cast 到 RadarHitTarget 再回调
        chart.onHit = { target, gesture in
            if let r = target as? RadarHitTarget { onHit?(r, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear {
            // 延后一个 runloop，确保 layoutSubviews 已执行
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<RadarChartRenderer>, context: Context) {
        uiView.onHit = { target, gesture in
            if let r = target as? RadarHitTarget { onHit?(r, gesture) }
        }
        uiView.configure(model: model, theme: theme)
    }
}
