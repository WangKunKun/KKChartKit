import SwiftUI
import Combine

/// 回调读数与属性状态分开，点击图表不会触发属性更新、清空刚选中的弹窗。
final class DemoChartReport: ObservableObject {
    @Published var text = "点击图表查看命中数据。"
    @Published var selectedRange: Range<Int>?
}
struct DemoHitReadout: View {
    @ObservedObject var report: DemoChartReport
    var body: some View {
        Text(report.text).font(.caption).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal).accessibilityIdentifier("demo.hit")
    }
}

struct DemoChartHost<R: HYMChartRenderer>: UIViewRepresentable {
    let model: R.Model
    let theme: R.Theme
    var interaction = DemoInteractionSettings()
    var tooltipTheme = HYMChartTooltipTheme()
    let report: DemoChartReport
    var command = 0
    var range: Range<Int>?
    var animation = 0
    var onVisibility: ((String, Bool) -> Void)?

    final class Coordinator {
        var command = 0
        var animation = 0
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> HYMChartView<R> {
        let chart = HYMChartView<R>(frame: .zero)
        chart.accessibilityIdentifier = "demo.chart.preview"
        apply(chart)
        chart.configure(model: model, theme: theme)
        return chart
    }
    func updateUIView(_ chart: HYMChartView<R>, context: Context) {
        apply(chart)
        chart.update(model: model, theme: theme, viewportPolicy: interaction.preserve ? .preserve : .reset)
        if command != context.coordinator.command {
            context.coordinator.command = command
            if let range { chart.showCategoryRange(range) } else { chart.resetViewport() }
        }
        if animation != context.coordinator.animation {
            context.coordinator.animation = animation
            chart.playEntranceAnimation()
        }
    }
    private func apply(_ chart: HYMChartView<R>) {
        chart.isZoomEnabled = interaction.zoom
        chart.maximumZoomScale = interaction.maxZoom
        chart.minimumVisibleCategories = interaction.minimumVisible
        chart.zoomAxisMode = interaction.zoomAxis
        chart.isDragDecelerationEnabled = interaction.deceleration
        chart.isHighlightPerDragEnabled = interaction.highlight
        chart.isRubberBandEnabled = interaction.rubberBand
        chart.isSharedTooltipOnTapEnabled = interaction.shared
        chart.isCrosshairEnabled = interaction.crosshair
        chart.isCrosshairDualDirectionEnabled = interaction.dualCrosshair
        chart.crosshairColor = interaction.crosshairColor
        chart.crosshairLineWidth = interaction.crosshairWidth
        chart.crosshairDashStyle = interaction.crosshairDash
        chart.showsTooltipOnHit = interaction.tooltip
        chart.tooltipTheme = tooltipTheme
        chart.tooltipTextOptions = .init(header: interaction.header.isEmpty ? nil : interaction.header,
            valueSuffix: interaction.suffix.isEmpty ? nil : interaction.suffix, valueDecimals: Int(interaction.decimals))
        chart.onSeriesVisibilityChanged = onVisibility
        chart.onHit = { target, gesture in
            report.text = "\(gesture) · " + (target.tooltipText ?? target.identifier)
            if let data = (target as? CartesianHitDataSource)?.chartData.first {
                let raw = data.rawValue.map { String($0) } ?? "nil（聚合）"
                let percent = data.percentage.map { String(format: "%.2f%%", $0) } ?? "—"
                report.text += "\n原值 \(raw) · 绘制 \(data.drawValue) · 起点 \(data.stackBase) · 占比 \(percent)\n组 \(data.groupName ?? data.groupID ?? "无") · 原始索引 \(data.sourceRange)"
            }
            report.selectedRange = (target as? ColumnHitTarget)?.timeBucket?.sourceRange
                ?? (target as? CartesianSharedHitTarget)?.entries.first?.timeBucket?.sourceRange
        }
        chart.onHitLocated = interaction.popupMode == "位置回调" ? { context, _ in
            guard let context else { return }
            report.text += "\n位置：\(context.location)，区域：\(context.frame)"
        } : nil
        chart.popupContentProvider = interaction.popupMode == "自定义内容" ? { context in
            let label = UILabel()
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 12)
            label.textColor = .white
            label.text = "自定义内容\n" + (context.target.tooltipText ?? context.target.identifier)
            return label
        } : nil
    }
}
