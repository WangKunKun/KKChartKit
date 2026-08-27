import UIKit
import Foundation

/// 条形图渲染器（水平柱体）
public final class BarChartRenderer: CartesianRendererBase<CartesianChartTheme> {

    // MARK: - Override

    /// 子类实现：绘制 series
    public override func drawSeries(
        model: CartesianChartModel,
        theme: CartesianChartTheme,
        plotFrame: CGRect
    ) {
        guard !model.series.isEmpty else { return }

        // 1. 计算零轴位置（X 轴）
        let zeroX = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport,
            plotArea: plotFrame,
            isHorizontal: true  // 关键差异：水平图
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

            // 4. 遍历每个数据点，计算条形并绘制
            for (index, value) in oneSeries.enumerated() {
                // 计算动画后的矩形
                var rect = CartesianGeometry.barRect(
                    dataPoint: value,
                    categoryIndex: index,
                    categoryCount: model.maxPointCount,
                    viewport: currentViewport,
                    plotArea: plotFrame,
                    theme: theme,
                    zeroX: zeroX
                )

                // 应用入场动画
                rect = animatedRect(from: rect, zeroX: zeroX, progress: currentAnimationProgress)

                // 负值颜色覆盖
                let color: UIColor
                if let negColor = model.series[seriesIndex].negativeColor, value < 0 {
                    color = negColor
                } else {
                    color = baseColor
                }

                // 绘制条形
                drawBar(rect: rect, color: color, zeroX: zeroX, in: rootLayer, theme: theme)

                // 如果堆叠且非最后系列，绘制分隔线
                if model.stacking == .normal && seriesIndex < model.series.count - 1 {
                    drawStackSeparator(at: rect.maxX, in: rootLayer, plotArea: plotFrame, theme: theme)
                }
            }
        }
    }

    /// 子类实现：命中测试
    public override func seriesHitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard let model = currentModel else { return nil }
        guard let theme = currentTheme as? CartesianChartTheme else { return nil }
        guard !model.series.isEmpty else { return nil }

        let zeroX = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport,
            plotArea: currentPlotFrame,
            isHorizontal: true
        )

        // 1. 确定 categoryIndex（point.y 落在哪个 slot）
        let slotHeight = currentPlotFrame.height / CGFloat(model.maxPointCount)
        let categoryIndex = Int((point.y - currentPlotFrame.minY) / slotHeight)

        guard categoryIndex >= 0 && categoryIndex < model.maxPointCount else { return nil }

        // 2. 确定系列索引（堆叠时需要判断 point.x 落在哪个条形段）
        let dataToCheck = model.stacking == .normal
            ? CartesianGeometry.stackedValues(series: model.series)
            : model.series.map { $0.data }

        for (seriesIndex, oneSeries) in dataToCheck.enumerated() {
            let value = oneSeries[categoryIndex]
            let rect = CartesianGeometry.barRect(
                dataPoint: value,
                categoryIndex: categoryIndex,
                categoryCount: model.maxPointCount,
                viewport: currentViewport,
                plotArea: currentPlotFrame,
                theme: theme,
                zeroX: zeroX
            )

            if rect.contains(point) {
                return BarHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex, value: value)
            }
        }

        return nil
    }

    // MARK: - Private

    /// 绘制单个条形
    private func drawBar(rect: CGRect, color: UIColor, zeroX: CGFloat, in layer: CALayer, theme: CartesianChartTheme) {
        // 水平版本：左右圆角
        let corners: UIRectCorner = rect.minX >= zeroX
            ? [.topLeft, .bottomLeft]    // 正值：左侧圆角（从零轴向右）
            : [.topRight, .bottomRight]  // 负值：右侧圆角（从零轴向左）

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

    /// 绘制堆叠分隔线（垂直线）
    private func drawStackSeparator(at x: CGFloat, in layer: CALayer, plotArea: CGRect, theme: CartesianChartTheme) {
        guard let separatorColor = theme.stackSeparatorColor else { return }

        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: plotArea.minY))
        path.addLine(to: CGPoint(x: x, y: plotArea.maxY))

        let lineLayer = CAShapeLayer()
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = separatorColor.cgColor
        lineLayer.lineWidth = theme.stackSeparatorWidth
        layer.addSublayer(lineLayer)
    }

    /// 计算动画过程中的矩形
    private func animatedRect(from rect: CGRect, zeroX: CGFloat, progress: Double) -> CGRect {
        let progressCGFloat = CGFloat(min(max(progress, 0), 1))

        if rect.minX >= zeroX {
            // 正值：从 zeroX 向右扩展
            let currentWidth = (rect.maxX - zeroX) * progressCGFloat
            return CGRect(x: zeroX, y: rect.minY, width: currentWidth, height: rect.height)
        } else {
            // 负值：从 zeroX 向左扩展
            let currentWidth = (zeroX - rect.minX) * progressCGFloat
            return CGRect(x: zeroX - currentWidth, y: rect.minY, width: currentWidth, height: rect.height)
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
