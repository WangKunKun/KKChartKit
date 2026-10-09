import UIKit

/// 柱、折线、曲线、面积共用一套坐标轴、图例和选择状态。
/// 柱体先绘制，线族覆盖其上；同族按模型顺序。UI 方法仅限主线程。
/// 本阶段不启用时间聚合；固定柱尺寸及区间滚动可用，线族保留原始采样。
public final class CombinedChartRenderer: CartesianRendererBase<CartesianChartTheme> {
    let columns = ColumnChartRenderer()
    let lines = LineChartRenderer()
    public override var supportsFixedColumnLayout: Bool { true }

    override var supportsDivergingStackGeometry: Bool { true }

    override func resolvedModel(_ model: CartesianChartModel) -> CartesianChartModel {
        var result = model
        result.usesMixedSeries = true
        for i in result.series.indices { result.series[i].stackFamilyIsColumn = result.series[i].kind?.isColumn ?? true }
        return result
    }
    public override func legendSymbol(for series: CartesianSeriesElement, theme: CartesianChartTheme) -> ChartLegendSymbol {
        (series.kind?.isColumn ?? true) ? .roundedRectangle : lines.legendSymbol(for: series, theme: theme)
    }
    public override func drawSeries(model: CartesianChartModel, theme: CartesianChartTheme, plotFrame: CGRect) {
        defer { resolveDataLabelCollisions(theme: theme) }
        for pass in [columns as CartesianRendererBase<CartesianChartTheme>, lines] {
            pass.currentModel = model
            pass.currentTheme = theme
            pass.currentViewport = currentViewport
            pass.currentPlotFrame = plotFrame
            pass.currentSecondaryYDomain = currentSecondaryYDomain
            pass.currentCategoryLabels = currentCategoryLabels
            pass.currentDrawValues = currentDrawValues
            pass.currentBaseValues = currentBaseValues
            pass.seriesFilter = Set(model.series.indices.filter {
                (model.series[$0].kind?.isColumn ?? true) == (pass === columns)
            })
            // 只共享准备好的数据和几何；pass 不挂载 view，不再创建坐标轴/图例。
            pass.rootLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            pass.rootLayer.frame = rootLayer.bounds
            pass.seriesLayer.frame = plotFrame
            pass.seriesLayer.bounds.origin = plotFrame.origin
            pass.seriesLayer.masksToBounds = true
            pass.rootLayer.addSublayer(pass.seriesLayer)
            rootLayer.addSublayer(pass.rootLayer)
            pass.drawSeries(model: model, theme: theme, plotFrame: plotFrame)
        }
    }
    public override func seriesHitTest(_ point: CGPoint) -> (any HYMChartHitTarget)? {
        lines.seriesHitTest(point) ?? columns.seriesHitTest(point)
    }
    public override func tooltipAnchor(for target: any HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard currentTheme?.showsTooltipOnHit == true, let frame = hitFrame(for: target) else { return nil }
        return .init(frame: frame, preferredPlacements: [.top, .bottom])
    }
    public override func hitFrame(for target: any HYMChartHitTarget) -> CGRect? {
        target is LineHitTarget ? lines.hitFrame(for: target) : columns.hitFrame(for: target)
    }
    public override func makeHitTarget(seriesIndex: Int, categoryIndex: Int, value: Double) -> (any HYMChartHitTarget)? {
        guard let model = currentModel, model.series.indices.contains(seriesIndex) else { return nil }
        let pass: CartesianRendererBase<CartesianChartTheme> = (model.series[seriesIndex].kind?.isColumn ?? true) ? columns : lines
        return pass.makeHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex, value: value)
    }
    public override func updateSeriesAnimation(progress: Double) {
        columns.updateSeriesAnimation(progress: progress)
        lines.updateSeriesAnimation(progress: progress)
        if let theme = currentTheme { resolveDataLabelCollisions(theme: theme) }
    }
    public override func unmount(from view: UIView) {
        columns.unmount(from: view)
        lines.unmount(from: view)
        super.unmount(from: view)
    }
}
