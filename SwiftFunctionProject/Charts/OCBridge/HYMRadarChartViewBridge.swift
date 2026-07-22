import UIKit

/// OC 友好的雷达视图桥接：持有内部泛型容器，OC 拿 chartView(UIView) 嵌入。
@objcMembers
public final class HYMRadarChartViewBridge: NSObject {
    private let chart: HYMChartView<RadarChartRenderer>
    private let theme: RadarChartTheme

    /// OC 端命中回调：OC 赋值后，内部容器命中时自动触发 (identifier, index)。
    /// 本期雷达 hitTest 默认无命中目标；后续 RadarChartRenderer 实现 hitTest 后自动生效。
    @objc public var onHit: ((NSString, Int) -> Void)?

    @objc public init(theme: HYMRadarThemeBuilder, frame: CGRect) {
        self.theme = theme.build()
        self.chart = HYMChartView<RadarChartRenderer>(frame: frame)
        super.init()
        // 一次性接线：内部容器命中 → 翻译成 OC block（[weak self] 防循环）
        chart.onHit = { [weak self] target, _ in
            self?.onHit?(target.identifier as NSString, target.index)
        }
    }

    /// OC 嵌入用（加入父 view）
    @objc public var chartView: UIView { chart }

    /// 配置数据（NSNumber? 桥接内部 Double?）
    @objc public func configure(dimensions: [HYMRadarDimensionBridge],
                                showsCenterScore: Bool,
                                centerScore: NSNumber?) {
        let dims = dimensions.map { $0.dimension }
        let m = RadarChartModel(dimensions: dims,
                                showsCenterScore: showsCenterScore,
                                centerScore: centerScore?.doubleValue)
        chart.configure(model: m, theme: theme)
    }

    @objc public func playEntranceAnimation() {
        chart.playEntranceAnimation()
    }
}
