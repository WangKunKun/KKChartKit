import UIKit
import Foundation

/// 柱状图渲染器（垂直柱体）
public final class ColumnChartRenderer: CartesianRendererBase<CartesianChartTheme> {

    // MARK: - Override

    /// 子类实现：绘制 series
    public override func drawSeries(
        model: CartesianChartModel,
        theme: CartesianChartTheme,
        plotFrame: CGRect
    ) {
        guard !model.series.isEmpty else { return }

        // 1. 计算零轴位置
        let zeroY = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport,
            plotArea: plotFrame,
            isHorizontal: false
        )

        // 2. 如果堆叠，计算累计值
        let dataToDraw: [[Double]]
        if model.stacking == .normal {
            dataToDraw = CartesianGeometry.stackedValues(series: model.series)
        } else {
            dataToDraw = model.series.map { $0.data }
        }

        // 3. 遍历每个系列
        for (seriesIndex, oneSeries) in dataToDraw.enumerated() {
            let baseColor = model.series[seriesIndex].color ?? theme.seriesColor

            // 4. 遍历每个数据点，计算柱体并绘制
            for (index, value) in oneSeries.enumerated() {
                // 计算动画后的矩形
                var rect = CartesianGeometry.columnRect(
                    dataPoint: value,
                    categoryIndex: index,
                    categoryCount: model.maxPointCount,
                    viewport: currentViewport,
                    plotArea: plotFrame,
                    theme: theme,
                    zeroY: zeroY
                )

                // 应用入场动画
                rect = animatedRect(from: rect, zeroY: zeroY, progress: currentAnimationProgress)

                // 负值颜色覆盖
                let color: UIColor
                if let negColor = model.series[seriesIndex].negativeColor, value < 0 {
                    color = negColor
                } else {
                    color = baseColor
                }

                // 绘制柱体
                drawColumn(rect: rect, color: color, zeroY: zeroY, in: rootLayer, theme: theme)

                // 如果堆叠且非最后系列，绘制分隔线
                if model.stacking == .normal && seriesIndex < model.series.count - 1 {
                    drawStackSeparator(at: rect.maxY, in: rootLayer, plotArea: plotFrame, theme: theme)
                }
            }
        }
    }

    /// 子类实现：命中测试
    public override func seriesHitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard let model = currentModel else { return nil }
        guard let theme = currentTheme as? CartesianChartTheme else { return nil }
        guard !model.series.isEmpty else { return nil }

        let zeroY = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport,
            plotArea: currentPlotFrame,
            isHorizontal: false
        )

        // 1. 确定 categoryIndex（point.x 落在哪个 slot）
        let slotWidth = currentPlotFrame.width / CGFloat(model.maxPointCount)
        let categoryIndex = Int((point.x - currentPlotFrame.minX) / slotWidth)

        guard categoryIndex >= 0 && categoryIndex < model.maxPointCount else { return nil }

        // 2. 确定系列索引（堆叠时需要判断 point.y 落在哪个柱体段）
        let dataToCheck = model.stacking == .normal
            ? CartesianGeometry.stackedValues(series: model.series)
            : model.series.map { $0.data }

        for (seriesIndex, oneSeries) in dataToCheck.enumerated() {
            let value = oneSeries[categoryIndex]
            let rect = CartesianGeometry.columnRect(
                dataPoint: value,
                categoryIndex: categoryIndex,
                categoryCount: model.maxPointCount,
                viewport: currentViewport,
                plotArea: currentPlotFrame,
                theme: theme,
                zeroY: zeroY
            )

            if rect.contains(point) {
                return ColumnHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex, value: value)
            }
        }

        return nil
    }

    // MARK: - Private

    /// 绘制单个柱体
    private func drawColumn(rect: CGRect, color: UIColor, zeroY: CGFloat, in layer: CALayer, theme: CartesianChartTheme) {
        // 确定圆角方向
        let corners: UIRectCorner = rect.minY < zeroY
            ? [.topLeft, .topRight]    // 正值：顶部圆角
            : [.bottomLeft, .bottomRight]  // 负值：底部圆角

        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: theme.columnCornerRadius, height: theme.columnCornerRadius))

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = color.cgColor

        // 边框
        if let borderColor = theme.columnBorderColor {
            shapeLayer.strokeColor = borderColor.cgColor
            shapeLayer.lineWidth = theme.columnBorderWidth
        }

        layer.addSublayer(shapeLayer)
    }

    /// 绘制堆叠分隔线
    private func drawStackSeparator(at y: CGFloat, in layer: CALayer, plotArea: CGRect, theme: CartesianChartTheme) {
        guard let separatorColor = theme.stackSeparatorColor else { return }

        let path = UIBezierPath()
        path.move(to: CGPoint(x: plotArea.minX, y: y))
        path.addLine(to: CGPoint(x: plotArea.maxX, y: y))

        let lineLayer = CAShapeLayer()
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = separatorColor.cgColor
        lineLayer.lineWidth = theme.stackSeparatorWidth
        layer.addSublayer(lineLayer)
    }

    /// 计算动画过程中的矩形
    private func animatedRect(from rect: CGRect, zeroY: CGFloat, progress: Double) -> CGRect {
        let progressCGFloat = CGFloat(min(max(progress, 0), 1))

        if rect.minY < zeroY {
            // 正值：从 zeroY 降到 minY
            let currentHeight = (zeroY - rect.minY) * progressCGFloat
            return CGRect(x: rect.minX, y: zeroY - currentHeight, width: rect.width, height: currentHeight)
        } else {
            // 负值：从 zeroY 升到 maxY
            let currentHeight = (rect.maxY - zeroY) * progressCGFloat
            return CGRect(x: rect.minX, y: zeroY, width: rect.width, height: currentHeight)
        }
    }

    /// 当前动画进度（从 updateSeriesAnimation 传入）
    private var currentAnimationProgress: Double = 1.0

    /// 子类动画钩子
    public override func updateSeriesAnimation(progress: Double) {
        currentAnimationProgress = progress
        // 重新绘制系列以应用动画
        if let model = currentModel, let theme = currentTheme {
            drawSeries(model: model, theme: theme, plotFrame: currentPlotFrame)
        }
    }
}
