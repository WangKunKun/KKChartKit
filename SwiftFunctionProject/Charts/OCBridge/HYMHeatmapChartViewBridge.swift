import UIKit

/// OC 友好的热力图视图桥接：持有内部泛型容器，OC 拿 chartView(UIView) 嵌入。
@objcMembers
public final class HYMHeatmapChartViewBridge: NSObject {
    private let chart: HYMChartView<HeatmapChartRenderer>
    private var theme: HeatmapChartTheme
    /// 当前 model（applyTheme 时复用，触发重新渲染）
    private var currentModel: HeatmapChartModel?

    /// OC 端命中回调：命中格子时触发 (row, column)。
    @objc public var onHit: ((NSInteger, NSInteger) -> Void)?

    /// OC 端带位置的命中回调：(hit, row, column, frame, location)。
    /// hit=YES 命中（row/column/frame/location 有效）；hit=NO 未命中（取消选中，外部据此隐藏弹窗）。
    /// 设置后内置 tooltip 自动不显示。
    @objc public var onHitLocated: ((Bool, NSInteger, NSInteger, CGRect, CGPoint) -> Void)? {
        didSet {
            chart.onHitLocated = onHitLocated != nil ? { [weak self] context, _ in
                guard let self else { return }
                if let context, let h = context.target as? HeatmapHitTarget {
                    self.onHitLocated?(true, h.row, h.column, context.frame, context.location)
                } else {
                    self.onHitLocated?(false, 0, 0, .zero, .zero)
                }
            } : nil
        }
    }

    /// OC 端弹窗内容提供者：(row, column) → 内容 UIView。SDK 套外壳 + 智能定位 + 显隐。
    /// 设了它 → 跳过 onHitLocated 与内置 text tooltip（popupContentProvider 优先）。
    @objc public var popupContentProvider: ((NSInteger, NSInteger) -> UIView?)? {
        didSet {
            chart.popupContentProvider = popupContentProvider != nil ? { [weak self] context in
                guard let self, let h = context.target as? HeatmapHitTarget else { return nil }
                return self.popupContentProvider?(h.row, h.column)
            } : nil
        }
    }

    @objc public init(theme: HYMHeatmapThemeBuilder, frame: CGRect) {
        self.theme = theme.build()
        self.chart = HYMChartView<HeatmapChartRenderer>(frame: frame)
        super.init()
        chart.showsTooltipOnHit = true   // 开启通用 tooltip 机制；开关细节由 theme.showsTooltipOnHit 控制
        chart.onHit = { [weak self] target, _ in
            if let h = target as? HeatmapHitTarget {
                self?.onHit?(h.row, h.column)
            }
        }
    }

    /// OC 嵌入用（加入父 view）。
    @objc public var chartView: UIView { chart }

    /// 配置数据。rows 为嵌套数组；rowLabels/columnLabels 可传 nil。缓存 model 供 applyTheme 复用。
    @objc public func configure(rows: [[HYMHeatmapCellBridge]],
                                rowLabels: [String]?,
                                columnLabels: [String]?) {
        let m = HeatmapChartModel(
            rows: rows.map { $0.map { $0.heatCell } },
            rowLabels: rowLabels,
            columnLabels: columnLabels)
        self.currentModel = m
        chart.configure(model: m, theme: theme)
    }

    /// 修改主题后调用：用新 theme 重新渲染（复用当前 model，触发 layoutSubviews → render）。
    @objc public func applyTheme(_ theme: HYMHeatmapThemeBuilder) {
        self.theme = theme.build()
        if let m = currentModel {
            chart.configure(model: m, theme: self.theme)
        }
    }

    @objc public func playEntranceAnimation() {
        chart.playEntranceAnimation()
    }
}
