import UIKit

/// OC 友好的雷达视图桥接：持有内部泛型容器，OC 拿 chartView(UIView) 嵌入。
@objcMembers
public final class HYMRadarChartViewBridge: NSObject {
    private let chart: HYMChartView<RadarChartRenderer>
    private var theme: RadarChartTheme
    /// 当前 model（applyTheme 时复用，触发重新渲染）
    private var currentModel: RadarChartModel?

    /// OC 端命中回调：(kind 字符串, 维度 index)。kind = "dataVertex"/"labelVertex"。
    @objc public var onHit: ((NSString, NSInteger) -> Void)?

    @objc public init(theme: HYMRadarThemeBuilder, frame: CGRect) {
        self.theme = theme.build()
        self.chart = HYMChartView<RadarChartRenderer>(frame: frame)
        super.init()
        // 一次性接线：内部容器命中 → 翻译成 OC block（[weak self] 防循环）
        chart.onHit = { [weak self] target, _ in
            if let r = target as? RadarHitTarget {
                self?.onHit?(r.kind as NSString, r.dimensionIndex)
            }
        }
    }

    /// OC 嵌入用（加入父 view）
    @objc public var chartView: UIView { chart }

    /// 配置数据（NSNumber? 桥接内部 Double?）。缓存 model 供 applyTheme 复用。
    @objc public func configure(dimensions: [HYMRadarDimensionBridge],
                                showsCenterScore: Bool,
                                centerScore: NSNumber?) {
        let dims = dimensions.map { $0.dimension }
        let m = RadarChartModel(dimensions: dims,
                                showsCenterScore: showsCenterScore,
                                centerScore: centerScore?.doubleValue)
        self.currentModel = m
        chart.configure(model: m, theme: theme)
    }

    /// 修改主题后调用：用新 theme 重新渲染（复用当前 model，触发 layoutSubviews → render）。
    @objc public func applyTheme(_ theme: HYMRadarThemeBuilder) {
        self.theme = theme.build()
        if let m = currentModel {
            chart.configure(model: m, theme: self.theme)
        }
    }

    @objc public func playEntranceAnimation() {
        chart.playEntranceAnimation()
    }
}
