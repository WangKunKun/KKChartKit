import SwiftUI

/// SwiftUI 雷达图封装（UIViewRepresentable 包装通用容器）
public struct RadarChart: View {
    private let model: RadarChartModel
    private var theme: RadarChartTheme
    private let playsAnimationOnAppear: Bool
    /// 命中回调：点中数据顶点/标题顶点时触发，携带 RadarHitTarget（category + dimensionIndex）
    private let onHit: ((RadarHitTarget, HYMChartGesture) -> Void)?
    /// 命中后带位置信息的回调（自定义弹窗用）。设置后内置 tooltip 自动不显示。
    private let onHitLocated: ((HYMChartHitContext?, HYMChartGesture) -> Void)?
    /// 命中弹窗内容（SwiftUI View）。SDK 套外壳 + 智能定位 + 显隐；设了它跳过 onHitLocated 与内置 tooltip。
    private let popup: ((HYMChartHitContext) -> AnyView)?

    public init(model: RadarChartModel,
                theme: RadarChartTheme = RadarChartTheme(),
                playsAnimationOnAppear: Bool = true,
                onHit: ((RadarHitTarget, HYMChartGesture) -> Void)? = nil,
                onHitLocated: ((HYMChartHitContext?, HYMChartGesture) -> Void)? = nil,
                popup: ((HYMChartHitContext) -> AnyView)? = nil) {
        self.model = model
        self.theme = theme
        self.playsAnimationOnAppear = playsAnimationOnAppear
        self.onHit = onHit
        self.onHitLocated = onHitLocated
        self.popup = popup
    }

    public var body: some View {
        RadarChartRepresentable(model: model, theme: theme,
                                playsAnimationOnAppear: playsAnimationOnAppear,
                                onHit: onHit, onHitLocated: onHitLocated, popup: popup)
    }
}

struct RadarChartRepresentable: UIViewRepresentable {
    let model: RadarChartModel
    let theme: RadarChartTheme
    let playsAnimationOnAppear: Bool
    let onHit: ((RadarHitTarget, HYMChartGesture) -> Void)?
    let onHitLocated: ((HYMChartHitContext?, HYMChartGesture) -> Void)?
    let popup: ((HYMChartHitContext) -> AnyView)?

    func makeUIView(context: Context) -> HYMChartView<RadarChartRenderer> {
        let chart = HYMChartView<RadarChartRenderer>(frame: .zero)
        // 容器 onHit 是 any HYMChartHitTarget；此处 cast 到 RadarHitTarget 再回调
        chart.onHit = { target, gesture in
            if let r = target as? RadarHitTarget { onHit?(r, gesture) }
        }
        chart.onHitLocated = onHitLocated
        chart.popupContentProvider = Self.makePopupProvider(popup)
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
