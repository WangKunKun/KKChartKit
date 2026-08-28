import UIKit
import Foundation

/// 柱状图渲染器（垂直柱体）
public final class ColumnChartRenderer: CartesianRendererBase<CartesianChartTheme> {

    // MARK: - Override

    /// 子类实现：绘制 series
    ///
    /// 性能设计：每系列的柱体合并为 ≤2 个 CAShapeLayer 的复合 path
    /// （正值色一条 + 负值覆盖色一条）——大数据量（1440 柱）从千级 layer
    /// 降到个位数，手势期间的逐帧重排不再掉帧。命中测试用几何计算，不依赖 layer。
    public override func drawSeries(
        model: CartesianChartModel,
        theme: CartesianChartTheme,
        plotFrame: CGRect
    ) {
        guard !model.series.isEmpty else { return }

        // 清空旧柱体（render 与动画/手势的逐帧重画共用本方法，必须先清后画）
        seriesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // 1. 计算零轴位置（次轴系列在循环内按所属值域另算）

        // 2. 如果堆叠，计算累计值（按轴分组：跨轴不混叠）
        let dataToDraw: [[Double]]
        if model.stacking == .normal {
            dataToDraw = CartesianGeometry.stackedValuesByAxis(series: model.series)
        } else {
            dataToDraw = model.series.map { $0.data }
        }

        // 3. 可见类目范围（视口缩放后跳过视口外柱体的 path 构造）
        let visible = visibleCategoryRange
        let seriesCount = model.stacking == .normal ? 1 : model.series.count

        // 4. 每系列：复合 path 收集 → 单 layer 输出
        for (seriesIndex, oneSeries) in dataToDraw.enumerated() {
            let baseColor = model.series[seriesIndex].color ?? theme.seriesColor
            let negativeColor = model.series[seriesIndex].negativeColor ?? baseColor
            let axisIdx = model.series[seriesIndex].effectiveYAxisIndex
            let seriesZeroY = CartesianGeometry.zeroAxisPosition(
                viewport: currentViewport, plotArea: plotFrame, isHorizontal: false,
                valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil)

            var positivePath = UIBezierPath()
            var negativePath = UIBezierPath()   // 仅负值色独立时才单独成层
            var separatorPath = UIBezierPath()  // 堆叠分隔线（同色同宽合并）

            for index in visible where index < oneSeries.count {
                let value = oneSeries[index]

                // 基准值（堆叠）：同符号链前累计 = 自身累计 − 自身原值（正链贴零轴向上、
                // 负链贴零轴向下；与 Highcharts 正负分开堆叠一致）。基准 ≈ 0 → 从零轴起。
                let baselineValue: Double?
                if model.stacking == .normal {
                    let base = value - (index < model.series[seriesIndex].data.count
                                        ? model.series[seriesIndex].data[index] : 0)
                    baselineValue = abs(base) < 1e-9 ? nil : base
                } else {
                    baselineValue = nil
                }

                var rect = CartesianGeometry.columnRect(
                    dataPoint: value,
                    categoryIndex: index,
                    viewport: currentViewport,
                    valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil,
                    plotArea: plotFrame,
                    theme: theme,
                    zeroY: seriesZeroY,
                    baselineValue: baselineValue,
                    seriesIndex: model.stacking == .normal ? 0 : seriesIndex,
                    seriesCount: seriesCount
                )
                rect = animatedRect(from: rect, zeroY: seriesZeroY, progress: currentAnimationProgress)

                // 圆角方向：正值顶部圆角、负值底部圆角；子路径独立圆角
                let corners: UIRectCorner = rect.minY < seriesZeroY
                    ? [.topLeft, .topRight]
                    : [.bottomLeft, .bottomRight]
                let columnPath = UIBezierPath(
                    roundedRect: rect, byRoundingCorners: corners,
                    cornerRadii: CGSize(width: theme.columnCornerRadius, height: theme.columnCornerRadius))

                if value < 0, negativeColor != baseColor {
                    negativePath.append(columnPath)
                } else {
                    positivePath.append(columnPath)
                }

                // 堆叠且非同轴最后一个系列：记录分隔线 y
                if model.stacking == .normal,
                   model.series[(seriesIndex + 1)...].contains(where: { $0.effectiveYAxisIndex == axisIdx }) {
                    separatorPath.move(to: CGPoint(x: plotFrame.minX, y: rect.maxY))
                    separatorPath.addLine(to: CGPoint(x: plotFrame.maxX, y: rect.maxY))
                }
            }

            if !positivePath.isEmpty {
                seriesLayer.addSublayer(makeColumnLayer(path: positivePath, color: baseColor, theme: theme))
            }
            if !negativePath.isEmpty {
                seriesLayer.addSublayer(makeColumnLayer(path: negativePath, color: negativeColor, theme: theme))
            }
            if !separatorPath.isEmpty, let separatorColor = theme.stackSeparatorColor {
                let line = CAShapeLayer()
                line.path = separatorPath.cgPath
                line.strokeColor = separatorColor.cgColor
                line.fillColor = nil
                line.lineWidth = theme.stackSeparatorWidth
                seriesLayer.addSublayer(line)
            }
        }
    }

    /// 柱体复合 path → 填充层（带可选边框）。
    private func makeColumnLayer(path: UIBezierPath, color: UIColor, theme: CartesianChartTheme) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.fillColor = color.cgColor
        if let borderColor = theme.columnBorderColor {
            layer.strokeColor = borderColor.cgColor
            layer.lineWidth = theme.columnBorderWidth
        }
        return layer
    }

    /// 子类实现：命中测试
    public override func seriesHitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard let model = currentModel else { return nil }
        guard let theme = currentTheme as? CartesianChartTheme else { return nil }
        guard !model.series.isEmpty else { return nil }

        // 1. 视口驱动反推类目索引：屏幕点 → x 值 → 最近类目中心
        //    （缩放/平移后与绘制同源，天然一致）
        let xValue = CartesianGeometry.value(at: point, viewport: currentViewport, plotFrame: currentPlotFrame).x
        let categoryIndex = Int(xValue.rounded())

        guard categoryIndex >= 0 && categoryIndex < model.maxPointCount else { return nil }

        // 2. 确定系列索引（堆叠时需要判断 point.y 落在哪个柱体段）
        let dataToCheck = model.stacking == .normal
            ? CartesianGeometry.stackedValuesByAxis(series: model.series)
            : model.series.map { $0.data }

        for (seriesIndex, oneSeries) in dataToCheck.enumerated() {
            guard categoryIndex < oneSeries.count else { continue }
            let value = oneSeries[categoryIndex]
            let axisIdx = model.series[seriesIndex].effectiveYAxisIndex
            let seriesZeroY = CartesianGeometry.zeroAxisPosition(
                viewport: currentViewport, plotArea: currentPlotFrame, isHorizontal: false,
                valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil)
            let rect = CartesianGeometry.columnRect(
                dataPoint: value,
                categoryIndex: categoryIndex,
                viewport: currentViewport,
                valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil,
                plotArea: currentPlotFrame,
                theme: theme,
                zeroY: seriesZeroY,
                seriesIndex: model.stacking == .normal ? 0 : seriesIndex,
                seriesCount: model.stacking == .normal ? 1 : model.series.count
            )

            if rect.contains(point) {
                return ColumnHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex,
                                       value: value, yAxisIndex: axisIdx)
            }
        }

        return nil
    }

    // MARK: - 弹窗锚点（命中柱体 rect，上下避让）
    public override func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard let t = target as? ColumnHitTarget,
              let model = currentModel,
              let theme = currentTheme as? CartesianChartTheme,
              theme.showsTooltipOnHit else { return nil }

        // 与 hitTest 同源几何：非堆叠多系列时定位到具体系列的子槽
        let zeroY = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport, plotArea: currentPlotFrame, isHorizontal: false)
        let rect = CartesianGeometry.columnRect(
            dataPoint: t.value,
            categoryIndex: t.categoryIndex,
            viewport: currentViewport,
            plotArea: currentPlotFrame,
            theme: theme,
            zeroY: zeroY,
            seriesIndex: model.stacking == .normal ? 0 : t.seriesIndex,
            seriesCount: model.stacking == .normal ? 1 : model.series.count)
        return HYMChartTooltipAnchor(frame: rect, preferredPlacements: [.top, .bottom])
    }

    // MARK: - Private

    /// 计算动画过程中的矩形（堆叠模式下从基准线开始生长）
    private func animatedRect(from rect: CGRect, zeroY: CGFloat, progress: Double) -> CGRect {
        let progressCGFloat = CGFloat(min(max(progress, 0), 1))

        // 确定柱段的起始位置（动画开始位置）
        let startY: CGFloat
        if rect.minY < zeroY {
            // 正值柱段
            startY = rect.maxY  // 从底部（较大Y值）开始向上生长
        } else {
            // 负值柱段
            startY = rect.minY  // 从顶部（较小Y值）开始向下生长
        }

        // 计算当前高度
        let targetHeight = rect.height
        let currentHeight = targetHeight * progressCGFloat

        // 根据正负值确定最终矩形
        if rect.minY < zeroY {
            // 正值：从底部向上生长
            return CGRect(x: rect.minX, y: startY - currentHeight, width: rect.width, height: currentHeight)
        } else {
            // 负值：从顶部向下生长
            return CGRect(x: rect.minX, y: startY, width: rect.width, height: currentHeight)
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

    /// 吸附命中 → ColumnHitTarget（含轴索引）。
    public override func makeHitTarget(seriesIndex: Int, categoryIndex: Int, value: Double)
        -> (any HYMChartHitTarget)? {
        guard let model = currentModel, seriesIndex < model.series.count else { return nil }
        return ColumnHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex,
                               value: value,
                               yAxisIndex: model.series[seriesIndex].effectiveYAxisIndex)
    }
}
