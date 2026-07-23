import UIKit

/// OC 友好的热力图视图桥接：持有内部泛型容器，OC 拿 chartView(UIView) 嵌入。
@objcMembers
public final class HYMHeatmapChartViewBridge: NSObject {
    private let chart: HYMChartView<HeatmapChartRenderer>
    private let theme: HeatmapChartTheme

    /// OC 端命中回调：命中格子时触发 (row, column)。
    @objc public var onHit: ((NSInteger, NSInteger) -> Void)?

    @objc public init(theme: HYMHeatmapThemeBuilder, frame: CGRect) {
        self.theme = theme.build()
        self.chart = HYMChartView<HeatmapChartRenderer>(frame: frame)
        super.init()
        chart.onHit = { [weak self] target, _ in
            if let h = target as? HeatmapHitTarget {
                self?.onHit?(h.row, h.column)
            }
        }
    }

    /// OC 嵌入用（加入父 view）。
    @objc public var chartView: UIView { chart }

    /// 配置数据。rows 为嵌套数组；rowLabels/columnLabels 可传 nil。
    @objc public func configure(rows: [[HYMHeatmapCellBridge]],
                                rowLabels: [String]?,
                                columnLabels: [String]?) {
        let m = HeatmapChartModel(
            rows: rows.map { $0.map { $0.heatCell } },
            rowLabels: rowLabels,
            columnLabels: columnLabels)
        chart.configure(model: m, theme: theme)
    }

    @objc public func playEntranceAnimation() {
        chart.playEntranceAnimation()
    }
}
