import SwiftUI

/// SwiftUI 雷达图封装（UIViewRepresentable 包装通用容器）
public struct RadarChart: View {
    private let model: RadarChartModel
    private var theme: RadarChartTheme
    private let playsAnimationOnAppear: Bool
    /// 点击图表区域是否重播入场动画（排查/交互用；默认 false，不影响现有调用方）
    private let replayOnTap: Bool
    /// 命中回调（构造期注入；本期雷达无命中目标，预留）
    private let onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    public init(model: RadarChartModel,
                theme: RadarChartTheme = RadarChartTheme(),
                playsAnimationOnAppear: Bool = true,
                replayOnTap: Bool = false,
                onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.theme.showsDecorativeRing = true
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.replayOnTap = replayOnTap
        self.onHit = onHit
    }

    public var body: some View {
        RadarChartRepresentable(model: model, theme: theme,
                                playsAnimationOnAppear: playsAnimationOnAppear,
                                replayOnTap: replayOnTap,
                                onHit: onHit)
    }
}

struct RadarChartRepresentable: UIViewRepresentable {
    let model: RadarChartModel
    let theme: RadarChartTheme
    let playsAnimationOnAppear: Bool
    let replayOnTap: Bool
    let onHit: ((any HYMChartHitTarget, HYMChartGesture) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> HYMChartView<RadarChartRenderer> {
        let chart = HYMChartView<RadarChartRenderer>(frame: .zero)
        chart.onHit = onHit
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear {
            // 延后一个 runloop，确保 layoutSubviews 已执行
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        if replayOnTap {
            // Coordinator 持有容器弱引用，转发点击 → 重播动画
            context.coordinator.chart = chart
            let tap = UITapGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.replayEntrance(_:)))
            // 不阻断框架内部命中手势（onHit）
            tap.cancelsTouchesInView = false
            chart.addGestureRecognizer(tap)
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<RadarChartRenderer>, context: Context) {
        uiView.onHit = onHit
        uiView.configure(model: model, theme: theme)
    }

    /// 转发点击 → 重播入场动画（弱引用容器，避免循环）。
    final class Coordinator: NSObject {
        weak var chart: HYMChartView<RadarChartRenderer>?
        @objc func replayEntrance(_ gesture: UITapGestureRecognizer) {
            chart?.playEntranceAnimation()
        }
    }
}
