import SwiftUI

/// SwiftUI 热力图封装（UIViewRepresentable 包装通用容器）。
public struct HeatmapChart: View {
    private let model: HeatmapChartModel
    private var theme: HeatmapChartTheme
    private let playsAnimationOnAppear: Bool
    private let tooltipTheme: HYMChartTooltipTheme
    /// 命中回调：点中格子时触发，携带 HeatmapHitTarget（row + column）
    private let onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)?
    /// 命中后带位置信息的回调（自定义弹窗用）。设置后内置 tooltip 自动不显示。
    private let onHitLocated: ((HYMChartHitContext?, HYMChartGesture) -> Void)?
    /// 命中弹窗内容（SwiftUI View）。SDK 套外壳 + 智能定位 + 显隐；设了它跳过 onHitLocated 与内置 tooltip。
    private let popup: ((HYMChartHitContext) -> AnyView)?

    public init(model: HeatmapChartModel,
                theme: HeatmapChartTheme = HeatmapChartTheme(),
                playsAnimationOnAppear: Bool = true,
                tooltipTheme: HYMChartTooltipTheme = .default,
                onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)? = nil,
                onHitLocated: ((HYMChartHitContext?, HYMChartGesture) -> Void)? = nil,
                popup: ((HYMChartHitContext) -> AnyView)? = nil) {
        self.model = model
        self.theme = theme
        self.theme.colorScale = .alpha(UIColor(named: "Green")!)
        self.theme.showsRowLabels = false
        self.theme.showsColumnLabels = false
        self.theme.rowSpacing = 0
        self.theme.columnSpacing = 0
        self.theme.cellCornerRadius = 0
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.tooltipTheme = tooltipTheme
        self.onHit = onHit
        self.onHitLocated = onHitLocated
        self.popup = popup
    }

    public var body: some View {
        HeatmapChartRepresentable(model: model, theme: theme,
                                  playsAnimationOnAppear: playsAnimationOnAppear,
                                  tooltipTheme: tooltipTheme,
                                  onHit: onHit, onHitLocated: onHitLocated, popup: popup)
    }
}

struct HeatmapChartRepresentable: UIViewRepresentable {
    let model: HeatmapChartModel
    let theme: HeatmapChartTheme
    let playsAnimationOnAppear: Bool
    let tooltipTheme: HYMChartTooltipTheme
    let onHit: ((HeatmapHitTarget, HYMChartGesture) -> Void)?
    let onHitLocated: ((HYMChartHitContext?, HYMChartGesture) -> Void)?
    let popup: ((HYMChartHitContext) -> AnyView)?

    func makeUIView(context: Context) -> HYMChartView<HeatmapChartRenderer> {
        let chart = HYMChartView<HeatmapChartRenderer>(frame: .zero)
        chart.tooltipTheme = tooltipTheme
        chart.showsTooltipOnHit = true
        chart.onHit = { target, gesture in
            if let h = target as? HeatmapHitTarget { onHit?(h, gesture) }
        }
        chart.onHitLocated = onHitLocated
        chart.popupContentProvider = Self.makePopupProvider(popup)
        chart.configure(model: model, theme: theme)
        if playsAnimationOnAppear {
            DispatchQueue.main.async { chart.playEntranceAnimation() }
        }
        return chart
    }

    func updateUIView(_ uiView: HYMChartView<HeatmapChartRenderer>, context: Context) {
        uiView.tooltipTheme = tooltipTheme
        uiView.showsTooltipOnHit = true
        uiView.onHit = { target, gesture in
            if let h = target as? HeatmapHitTarget { onHit?(h, gesture) }
        }
        uiView.onHitLocated = onHitLocated
        uiView.popupContentProvider = Self.makePopupProvider(popup)
        uiView.configure(model: model, theme: theme)
    }

    /// SwiftUI View → UIView（UIHostingController）。popup 为 nil 时返回 nil（不接管弹窗）。
    private static func makePopupProvider(_ popup: ((HYMChartHitContext) -> AnyView)?)
        -> ((HYMChartHitContext) -> UIView?)? {
        guard let popup else { return nil }
        return { context in
            let host = UIHostingController(rootView: popup(context))
            host.view.backgroundColor = .clear
            return host.view
        }
    }
}
