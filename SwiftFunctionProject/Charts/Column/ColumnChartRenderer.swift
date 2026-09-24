import UIKit
import Foundation

/// 柱状图渲染器（垂直柱体）
public final class ColumnChartRenderer: CartesianRendererBase<CartesianChartTheme> {

    public override var supportsTimeGrouping: Bool { true }

    /// 系列标签独立挂载，逐帧替换，避免动画过程中累积旧标签。
    private let annotationLayer = CALayer()

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
        // 清空旧柱体（render 与动画/手势的逐帧重画共用本方法，必须先清后画）
        seriesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        clearSeriesShadowCasters()
        annotationLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        if annotationLayer.superlayer == nil { rootLayer.addSublayer(annotationLayer) }
        guard !model.series.isEmpty else { return }

        // 1. 计算零轴位置（次轴系列在循环内按所属值域另算）

        // 2. 如果堆叠，计算累计值（normal=符号链累计 / percent=百分比累计）
        let dataToDraw = currentDrawValues

        // 3. 可见类目范围（视口缩放后跳过视口外柱体的 path 构造）
        let visible = visibleCategoryRange
        let seriesCount = model.isStacked ? 1 : model.visibleSeriesCount

        let wantsStackTotals = model.isStacked && theme.showsStackTotalLabels
        var stackTotals = CartesianStackTotalLabels()

        for (seriesIndex, oneSeries) in dataToDraw.enumerated() {
            let element = model.series[seriesIndex]
            guard element.isVisible else { continue }
            let baseColor = element.color ?? theme.seriesColor
            let negativeColor = element.negativeColor ?? baseColor
            let axisIdx = element.effectiveYAxisIndex
            let seriesZeroY = CartesianGeometry.zeroAxisPosition(
                viewport: currentViewport, plotArea: plotFrame, isHorizontal: false,
                valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil)

            // 按最终填充色分组的复合 path（同色合一层，大数据量性能与单色一致）：
            // 取色优先级 = 负值换色 negativeColor > 逐柱色 barColors（按类目循环）> 系列色
            var pathsByColor: [UIColor: UIBezierPath] = [:]
            var separatorPath = UIBezierPath()  // 堆叠分隔线（同色同宽合并）

            for index in visible where index < oneSeries.count && oneSeries[index].isFinite {
                let value = oneSeries[index]
                // 堆叠数组会补齐短系列；占位不绘制，也不能反查不存在的原值。
                guard index < element.data.count, element.data[index].isFinite,
                      element.data[index] != 0 else { continue }

                // 基准值（堆叠）：同符号链前累计 = 自身累计 − 自身原值（正链贴零轴向上、
                // 负链贴零轴向下；与 Highcharts 正负分开堆叠一致）。基准 ≈ 0 → 从零轴起。
                let baselineValue: Double?
                if model.isStacked {
                    let rawBase = currentBaseValues[seriesIndex]
                    let base = value - (index < rawBase.count ? rawBase[index] : 0)
                    baselineValue = base
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
                    seriesIndex: model.isStacked ? 0 : model.visibleSlot(for: seriesIndex),
                    seriesCount: seriesCount,
                    categoryPosition: model.categoryPosition(index), categorySpan: model.categorySpan(index)
                )
                rect = animatedRect(from: rect, zeroY: seriesZeroY, progress: currentAnimationProgress)

                // 圆角方向：正值顶部圆角、负值底部圆角；子路径独立圆角。
                // 堆叠时只有链**末端段**保留圆角（正链最上段顶圆角、负链最下段底圆角），
                // 中间段直角——整根堆叠柱看起来是一个连续柱体而非逐段圆角。
                let corners: UIRectCorner
                if model.isStacked {
                    // 同轴同符号链上方还有非零段 → 本段是中间段，不圆角
                    let hasSegmentAbove = model.series[(seriesIndex + 1)...].contains { s2 in
                        guard s2.isVisible, s2.effectiveYAxisIndex == axisIdx,
                              index < s2.data.count, abs(s2.data[index]) > 1e-9 else { return false }
                        return (s2.data[index] >= 0) == (value >= 0)
                    }
                    corners = hasSegmentAbove
                        ? []
                        : (value >= 0 ? [.topLeft, .topRight] : [.bottomLeft, .bottomRight])
                } else {
                    corners = rect.minY < seriesZeroY
                        ? [.topLeft, .topRight]
                        : [.bottomLeft, .bottomRight]
                }
                let cornerRadius = corners.isEmpty
                    ? 0
                    : theme.columnCornerRadius
                let columnPath = UIBezierPath(
                    roundedRect: rect, byRoundingCorners: corners,
                    cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))

                let fillColor: UIColor
                if value < 0, negativeColor != baseColor {
                    fillColor = negativeColor
                } else if let barColors = element.barColors, !barColors.isEmpty {
                    fillColor = barColors[index % barColors.count]
                } else {
                    fillColor = baseColor
                }
                if pathsByColor[fillColor] == nil { pathsByColor[fillColor] = UIBezierPath() }
                pathsByColor[fillColor]!.append(columnPath)

                if wantsStackTotals {
                    stackTotals.add(rawValue: element.data[index], category: index,
                                    axis: axisIdx, rect: rect,
                                    horizontal: false)
                }

                // 堆叠且非同轴最后一个系列：记录分隔线 y
                if model.isStacked,
                   model.series[(seriesIndex + 1)...].contains(where: { $0.isVisible && $0.effectiveYAxisIndex == axisIdx }) {
                    separatorPath.move(to: CGPoint(x: plotFrame.minX, y: rect.maxY))
                    separatorPath.addLine(to: CGPoint(x: plotFrame.maxX, y: rect.maxY))
                }

                // 数据标签：数值 = 系列原值（堆叠时各段自身值，位置在累计后的段矩形上），
                // 随入场动画矩形一起生长。挂 rootLayer（不被 plot 裁剪，端部外侧可探出）。
                if dataLabelsAllowed(for: model.series[seriesIndex], theme: theme) {
                    let raw = model.series[seriesIndex].data[index]
                    let text = CartesianDataLabelGeometry.labelText(
                        raw, formatter: theme.dataLabelFormatter)
                    let size = dataLabelTextSize(text, fontSize: theme.dataLabelFontSize)
                    let center = CartesianDataLabelGeometry.labelCenter(
                        rect: rect, textSize: size, position: theme.dataLabelPosition,
                        isHorizontal: false, isPositive: value >= 0)
                    annotationLayer.addSublayer(makeDataLabelLayer(
                        text: text, fontSize: theme.dataLabelFontSize,
                        color: dataLabelColor(theme: theme,
                                              inside: theme.dataLabelPosition != .outsideEnd),
                        center: center))
                }
            }

            for (color, path) in pathsByColor where !path.isEmpty {
                seriesLayer.addSublayer(makeColumnLayer(path: path, color: color, theme: theme))
            }
            // 阴影走隐形 caster（挂裁剪层外）：柱底贴 plot 下边界，画在 seriesLayer
            // 内会被 masksToBounds 裁光
            if let shadowStyle = element.shadow ?? theme.seriesShadow {
                let union = UIBezierPath()
                for (_, p) in pathsByColor where !p.isEmpty { union.append(p) }
                if !union.isEmpty {
                    addSeriesShadowCaster(path: union.cgPath, style: shadowStyle)
                }
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

        if wantsStackTotals {
            drawStackTotalLabels(stackTotals, theme: theme, into: annotationLayer)
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
        guard !model.series.isEmpty else { return nil }

        // 1. 视口驱动反推类目索引：屏幕点 → x 值 → 最近类目中心
        //    （缩放/平移后与绘制同源，天然一致）
        let xValue = CartesianGeometry.value(at: point, viewport: currentViewport, plotFrame: currentPlotFrame).x
        let rawIndex = Int(xValue.rounded())
        guard rawIndex >= 0, rawIndex < model.maxPointCount else { return nil }
        let categoryIndex = model.bucketAnchor(for: rawIndex)

        guard categoryIndex >= 0 && categoryIndex < model.maxPointCount else { return nil }

        for seriesIndex in model.series.indices.reversed() {
            if let rect = markRect(seriesIndex: seriesIndex, categoryIndex: categoryIndex), rect.contains(point) {
                return makeHitTarget(seriesIndex: seriesIndex, categoryIndex: categoryIndex,
                                     value: currentDrawValues[seriesIndex][categoryIndex])
            }
        }
        return nil
    }

    /// 与绘制同源：显隐分组槽位、堆叠段基线和次轴都在这里统一。
    private func markRect(seriesIndex: Int, categoryIndex: Int) -> CGRect? {
        guard let model = currentModel, let theme = currentTheme,
              model.series.indices.contains(seriesIndex) else { return nil }
        let element = model.series[seriesIndex]
        guard element.isVisible, element.data.indices.contains(categoryIndex),
              element.data[categoryIndex].isFinite, element.data[categoryIndex] != 0 else { return nil }
        let value = currentDrawValues[seriesIndex][categoryIndex]
        guard value.isFinite else { return nil }
        let axis = element.effectiveYAxisIndex
        let zero = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport, plotArea: currentPlotFrame, isHorizontal: false,
            valueDomain: axis == 1 ? currentSecondaryYDomain : nil)
        return CartesianGeometry.columnRect(
                dataPoint: value, categoryIndex: categoryIndex, viewport: currentViewport,
                valueDomain: axis == 1 ? currentSecondaryYDomain : nil,
                plotArea: currentPlotFrame, theme: theme, zeroY: zero,
                baselineValue: model.isStacked ? value - currentBaseValues[seriesIndex][categoryIndex] : nil,
                seriesIndex: model.isStacked ? 0 : model.visibleSlot(for: seriesIndex),
                seriesCount: model.isStacked ? 1 : model.visibleSeriesCount,
                categoryPosition: model.categoryPosition(categoryIndex), categorySpan: model.categorySpan(categoryIndex))
    }

    public override func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard currentTheme?.showsTooltipOnHit == true, let rect = hitFrame(for: target) else { return nil }
        return HYMChartTooltipAnchor(frame: rect, preferredPlacements: [.top, .bottom])
    }

    public override func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
        guard let target = target as? ColumnHitTarget else { return nil }
        return markRect(seriesIndex: target.seriesIndex, categoryIndex: target.categoryIndex)
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
                               yAxisIndex: model.series[seriesIndex].effectiveYAxisIndex,
                               name: model.series[seriesIndex].name, seriesID: model.series[seriesIndex].id,
                               timeBucket: model.timeBucket(series: seriesIndex, category: categoryIndex))
    }

    /// DEBUG 自检辅助：seriesLayer 子层（圆角曲线数量断言用）。
    func seriesLayerSublayersForTesting() -> [CALayer] { seriesLayer.sublayers ?? [] }
}
