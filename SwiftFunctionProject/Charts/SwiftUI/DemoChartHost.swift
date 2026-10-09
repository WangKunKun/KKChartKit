import SwiftUI
import Combine

/// 回调读数与属性状态分开，点击图表不会触发属性更新、清空刚选中的弹窗。
final class DemoChartReport: ObservableObject {
    @Published var text = "点击图表查看命中数据。"
    @Published var selectedRange: Range<Int>?
    @Published private(set) var samplingText = ""
    @Published private(set) var stackBoundaryText = ""
    private var pendingBoundaryText: String?
    private var pendingSamplingText: String?
    private var samplingUpdateScheduled = false

    /// 合并同一事件周期的重绘，只在布局结束后发布，避免 SwiftUI 更新期间发布状态。
    func receiveSamplingStatistics(_ statistics: [LineSamplingStatistics], boundaryText: String = "") {
        pendingBoundaryText = boundaryText
        pendingSamplingText = DemoLineSamplingReadout.text(statistics)
        guard !samplingUpdateScheduled else { return }
        samplingUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.samplingUpdateScheduled = false
            if let text = self.pendingSamplingText, text != self.samplingText { self.samplingText = text }
            if let text = self.pendingBoundaryText, text != self.stackBoundaryText { self.stackBoundaryText = text }
            self.pendingBoundaryText = nil
            self.pendingSamplingText = nil
        }
    }
}
struct DemoHitReadout: View {
    @ObservedObject var report: DemoChartReport
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(report.text).font(.caption).lineLimit(expanded ? nil : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("demo.hit")
            if report.text.contains("\n") {
                Button(expanded ? "收起读数" : "展开读数") { expanded.toggle() }
                    .font(.caption2).accessibilityIdentifier("demo.hit.expand")
            }
        }.padding(.horizontal)
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
        chart.isSharedTooltipOnTapEnabled = interaction.shared && interaction.popupMode == "内置"
        chart.isCrosshairEnabled = interaction.crosshair
        chart.isCrosshairDualDirectionEnabled = interaction.dualCrosshair
        chart.crosshairColor = interaction.crosshairColor
        chart.crosshairLineWidth = interaction.crosshairWidth
        chart.crosshairDashStyle = interaction.crosshairDash
        chart.showsTooltipOnHit = interaction.tooltip
        chart.tooltipTheme = tooltipTheme
        chart.tooltipTextOptions = interaction.textOptions
        chart.cartesianTooltipPresentation = interaction.presentation
        chart.cartesianTooltipSampleSelection = interaction.sampleSelection
        chart.onSeriesVisibilityChanged = onVisibility
        chart.observeLineDiagnostics { [weak report] statistics, participating, fallback in
            let boundary = participating.isEmpty ? "" : "正负分链：参与 \(participating.count) 个系列 · " +
                (fallback.isEmpty ? "未采用共享直线降级" : "共享直线降级 \(fallback.count) 个系列（整组）")
            report?.receiveSamplingStatistics(statistics, boundaryText: boundary)
        }
        chart.onHit = { [weak chart] target, gesture in
            let source = interaction.popupMode == "内置" ? target as? CartesianHitDataSource : nil
            let text = source == nil ? nil : chart?.cartesianTooltipContent(for: target)?.text
            report.text = "\(gesture) · " + (source != nil ? (text ?? "提示行已全部过滤") : (target.tooltipText ?? target.identifier))
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
        chart.popupContentProvider = interaction.tooltip && interaction.popupMode == "自定义内容" ? { context in
            let label = UILabel()
            label.numberOfLines = 0
            label.font = tooltipTheme.font
            label.textColor = tooltipTheme.textColor
            label.text = "自定义内容\n" + (context.target.tooltipText ?? context.target.identifier)
            return label
        } : nil
    }
}
