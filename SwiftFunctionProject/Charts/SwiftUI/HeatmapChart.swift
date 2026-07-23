import SwiftUI

/// SwiftUI 热力图封装（UIViewRepresentable 包装通用容器）。
public struct HeatmapChart: View {
    private let model: HeatmapChartModel
    private var theme: HeatmapChartTheme
    private let playsAnimationOnAppear: Bool
    /// 命中回调：点中格子时触发，携带 HeatmapHitTarget（row + column）
    private let onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)?

    public init(model: HeatmapChartModel,
                theme: HeatmapChartTheme = HeatmapChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)? = nil) {
        self.model = model
        self.theme = theme
        self.theme.colorScale = .alpha(UIColor(named: "Green")!)
        self.theme.showsRowLabels = false
        self.theme.showsColumnLabels = false
        self.theme.rowSpacing = 0
        self.theme.columnSpacing = 0
        self.theme.cellCornerRadius = 0
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
    }

    public var body: some View {
        HeatmapChartRepresentable(model: model, theme: theme,
                                  playsAnimationOnAppear: playsAnimationOnAppear, onHit: onHit)
    }
}

struct HeatmapChartRepresentable: UIViewRepresentable {
    let model: HeatmapChartModel
    let theme: HeatmapChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)?

    func makeUIView(context: Context) -> HYMChartView<HeatmapChartRenderer> {
        let chart = HYMChartView<HeatmapChartRenderer>(frame: .zero)
        chart.onHit = { target, gesture in
            if let h = target as? HeatmapHitTarget { onHit?(h, gesture) }
        }
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<HeatmapChartRenderer>, context: Context) {
        uiView.onHit = { target, gesture in
            if let h = target as? HeatmapHitTarget { onHit?(h, gesture) }
        }
        uiView.configure(model: model, theme: theme)
    }
}
