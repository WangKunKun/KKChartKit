import UIKit
import Foundation

/// 条形图渲染器（水平柱体）
public final class BarChartRenderer: CartesianRendererBase<CartesianChartTheme> {

    // MARK: - Override

    /// 水平图：值域落 X（底部数值刻度、竖网格线、捏合缩放数值轴），
    /// 类目域落 Y（左侧类目标签、横网格线）。viewport 语义随之对调。
    public override var isHorizontalValueAxis: Bool { true }

    /// 子类实现：绘制 series
    ///
    /// 性能设计：与 ColumnChartRenderer 对称——每系列条形合并为 ≤2 个
    /// CAShapeLayer 的复合 path（正值色 + 负值覆盖色），大数据量不掉帧。
    public override func drawSeries(
        model: CartesianChartModel,
        theme: CartesianChartTheme,
        plotFrame: CGRect
    ) {
        guard !model.series.isEmpty else { return }

        // 清空旧条形（render 与动画/手势的逐帧重画共用本方法，必须先清后画）
        seriesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // 1. 计算零轴位置（X 轴）
        let zeroX = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport,
            plotArea: plotFrame,
            isHorizontal: true  // 关键差异：水平图
        )

        // 2. 如果堆叠，计算累计值（normal=符号链累计 / percent=百分比累计）
        let dataToDraw = model.stackedDrawValues

        // 3. 遍历每个系列（类目在 Y 轴、恒全量可见，无需裁剪；
        //    条形长度沿 X 数值轴，视口缩放由 seriesLayer 裁剪兜底）
        let seriesCount = model.isStacked ? 1 : model.series.count
        for (seriesIndex, oneSeries) in dataToDraw.enumerated() {
            let baseColor = model.series[seriesIndex].color ?? theme.seriesColor
            let negativeColor = model.series[seriesIndex].negativeColor ?? baseColor

            var positivePath = UIBezierPath()
            var negativePath = UIBezierPath()   // 仅负值色独立时才单独成层
            var separatorPath = UIBezierPath()  // 堆叠分隔线（同色同宽合并）

            for (index, value) in oneSeries.enumerated() where value.isFinite {
                // 基准值（堆叠）：符号链前累计 = 自身累计 − 自身基准原值（percent 时为归一化原值）
                let baselineValue: Double?
                if model.isStacked {
                    let rawBase = model.rawBaseValues(forSeries: seriesIndex)
                    let base = value - (index < rawBase.count ? rawBase[index] : 0)
                    baselineValue = abs(base) < 1e-9 ? nil : base
                } else {
                    baselineValue = nil
                }

                var rect = CartesianGeometry.barRect(
                    dataPoint: value,
                    categoryIndex: index,
                    viewport: currentViewport,
                    plotArea: plotFrame,
                    theme: theme,
                    zeroX: zeroX,
                    baselineValue: baselineValue,
                    seriesIndex: model.isStacked ? 0 : seriesIndex,
                    seriesCount: seriesCount
                )
                rect = animatedRect(from: rect, zeroX: zeroX, progress: currentAnimationProgress)

                // 圆角方向：正值左侧圆角（从零轴向右）、负值右侧圆角
                let corners: UIRectCorner = rect.minX >= zeroX
                    ? [.topLeft, .bottomLeft]
                    : [.topRight, .bottomRight]
                let barPath = UIBezierPath(
                    roundedRect: rect, byRoundingCorners: corners,
                    cornerRadii: CGSize(width: theme.columnCornerRadius, height: theme.columnCornerRadius))

                if value < 0, negativeColor != baseColor {
                    negativePath.append(barPath)
                } else {
                    positivePath.append(barPath)
                }

                // 堆叠且非最后系列：记录分隔线 x
                if model.isStacked, seriesIndex < model.series.count - 1 {
                    separatorPath.move(to: CGPoint(x: rect.maxX, y: plotFrame.minY))
                    separatorPath.addLine(to: CGPoint(x: rect.maxX, y: plotFrame.maxY))
                }

                // 数据标签：数值 = 系列原值（堆叠时各段自身值）；水平方向镜像（端部在右/左）。
                if dataLabelsAllowed(for: model.series[seriesIndex], theme: theme) {
                    let raw = model.series[seriesIndex].data[index]
                    let text = CartesianDataLabelGeometry.labelText(
                        raw, formatter: theme.dataLabelFormatter)
                    let size = dataLabelTextSize(text, fontSize: theme.dataLabelFontSize)
                    let center = CartesianDataLabelGeometry.labelCenter(
                        rect: rect, textSize: size, position: theme.dataLabelPosition,
                        isHorizontal: true, isPositive: value >= 0)
                    rootLayer.addSublayer(makeDataLabelLayer(
                        text: text, fontSize: theme.dataLabelFontSize,
                        color: dataLabelColor(theme: theme,
                                              inside: theme.dataLabelPosition != .outsideEnd),
                        center: center))
                }
            }

            if !positivePath.isEmpty {
                seriesLayer.addSublayer(makeBarLayer(path: positivePath, color: baseColor, theme: theme))
            }
            if !negativePath.isEmpty {
                seriesLayer.addSublayer(makeBarLayer(path: negativePath, color: negativeColor, theme: theme))
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

    /// 条形复合 path → 填充层（带可选边框）。
    private func makeBarLayer(path: UIBezierPath, color: UIColor, theme: CartesianChartTheme) -> CAShapeLayer {
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

        let zeroX = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport,
            plotArea: currentPlotFrame,
            isHorizontal: true
        )

        // 1. 类目在 Y 轴（恒全量）：屏幕点 → 类目值 → 最近类目中心
        //    （用水平图专用映射：类目 0 在顶部，与 barRect/标签/网格同一方向）
        let yValue = CartesianGeometry.horizontalCategory(atY: point.y,
                                                          viewport: currentViewport,
                                                          plotFrame: currentPlotFrame)
        let categoryIndex = Int(yValue.rounded())

        guard categoryIndex >= 0 && categoryIndex < model.maxPointCount else { return nil }

        // 2. 确定系列索引（堆叠时需要判断 point.x 落在哪个条形段）
        let dataToCheck = model.isStacked
            ? model.stackedDrawValues
            : model.series.map { $0.data }

        for (seriesIndex, oneSeries) in dataToCheck.enumerated() {
            guard categoryIndex < oneSeries.count, oneSeries[categoryIndex].isFinite else { continue }
            let value = oneSeries[categoryIndex]
            let rect = CartesianGeometry.barRect(
                dataPoint: value,
                categoryIndex: categoryIndex,
                viewport: currentViewport,
                plotArea: currentPlotFrame,
                theme: theme,
                zeroX: zeroX,
                seriesIndex: model.isStacked ? 0 : seriesIndex,
                seriesCount: model.isStacked ? 1 : model.series.count
            )

            if rect.contains(point) {
                return BarHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex,
                                     value: value, name: model.series[seriesIndex].name)
            }
        }

        return nil
    }

    // MARK: - 弹窗锚点（命中条形 rect，上下避让）
    public override func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard let t = target as? BarHitTarget,
              let model = currentModel,
              let theme = currentTheme as? CartesianChartTheme,
              theme.showsTooltipOnHit else { return nil }

        // 与 hitTest 同源几何：非堆叠多系列时定位到具体系列的子槽
        let zeroX = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport, plotArea: currentPlotFrame, isHorizontal: true)
        let rect = CartesianGeometry.barRect(
            dataPoint: t.value,
            categoryIndex: t.categoryIndex,
            viewport: currentViewport,
            plotArea: currentPlotFrame,
            theme: theme,
            zeroX: zeroX,
            seriesIndex: model.isStacked ? 0 : t.seriesIndex,
            seriesCount: model.isStacked ? 1 : model.series.count)
        return HYMChartTooltipAnchor(frame: rect, preferredPlacements: [.top, .bottom])
    }

    // MARK: - Private

    /// 计算动画过程中的矩形（堆叠模式下从基准线开始生长）
    private func animatedRect(from rect: CGRect, zeroX: CGFloat, progress: Double) -> CGRect {
        let progressCGFloat = CGFloat(min(max(progress, 0), 1))

        // 确定柱段的起始位置（动画开始位置）
        let startX: CGFloat
        if rect.minX >= zeroX {
            // 正值柱段：从左侧（基准线）开始向右生长
            startX = rect.minX
        } else {
            // 负值柱段：从右侧（基准线）开始向左生长
            startX = rect.maxX
        }

        // 计算当前宽度
        let targetWidth = rect.width
        let currentWidth = targetWidth * progressCGFloat

        // 根据正负值确定最终矩形
        if rect.minX >= zeroX {
            // 正值：从基准线向右生长
            return CGRect(x: startX, y: rect.minY, width: currentWidth, height: rect.height)
        } else {
            // 负值：从基准线向左生长
            return CGRect(x: startX - currentWidth, y: rect.minY, width: currentWidth, height: rect.height)
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

    /// 吸附命中 → BarHitTarget（水平图按最近类目行取条形值）。
    public override func makeHitTarget(seriesIndex: Int, categoryIndex: Int, value: Double)
        -> (any HYMChartHitTarget)? {
        guard let model = currentModel, seriesIndex < model.series.count else { return nil }
        return BarHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex,
                            value: value, name: model.series[seriesIndex].name)
    }
}
