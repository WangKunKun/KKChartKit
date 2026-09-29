import UIKit
import Foundation

/// 条形图渲染器（水平柱体）
public final class BarChartRenderer: CartesianRendererBase<CartesianChartTheme> {
    override func resolvedModel(_ model: CartesianChartModel) -> CartesianChartModel {
        var result = model
        result.usesMixedSeries = false
        for i in result.series.indices { result.series[i].stackFamilyIsColumn = true }
        return result
    }


    /// 系列标签独立挂载，逐帧替换，避免动画过程中累积旧标签。
    private let annotationLayer = CALayer()

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
        // 清空旧条形（render 与动画/手势的逐帧重画共用本方法，必须先清后画）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        seriesObjects.begin(reusing: theme.reusesRenderingObjects)
        defer { seriesObjects.end(); CATransaction.commit() }
        seriesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        clearSeriesShadowCasters()
        annotationLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        if annotationLayer.superlayer == nil { rootLayer.addSublayer(annotationLayer) }
        guard !model.series.isEmpty else { return }

        // 1. 计算零轴位置（X 轴）
        let zeroX = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport,
            plotArea: plotFrame,
            isHorizontal: true  // 关键差异：水平图
        )

        // 2. 如果堆叠，计算累计值（normal=符号链累计 / percent=百分比累计）
        let dataToDraw = currentDrawValues

        // 3. 只绘制 Y 类目窗口内的条形；X 数值方向由 seriesLayer 裁剪。
        let slots = model.columnSlots
        let seriesCount = (slots.values.max() ?? -1) + 1

        let wantsStackTotals = model.isStacked && theme.showsStackTotalLabels
        var stackTotals = CartesianStackTotalLabels()

        for (seriesIndex, oneSeries) in dataToDraw.enumerated() {
            let element = model.series[seriesIndex]
            guard element.isVisible, includesSeries(seriesIndex) else { continue }
            let slot = slots[seriesIndex] ?? 0
            let baseColor = element.color ?? theme.seriesColor
            let negativeColor = element.negativeColor ?? baseColor

            // 按最终填充色分组的复合 path（同色合一层）：负值换色 > 逐条色 barColors > 系列色
            var pathsByColor: [UIColor: UIBezierPath] = [:]
            var separatorPath = UIBezierPath()  // 堆叠分隔线（同色同宽合并）

            for index in visibleCategoryRange where index < oneSeries.count && oneSeries[index].isFinite {
                let value = oneSeries[index]
                // 堆叠数组会补齐短系列；占位不绘制，也不能反查不存在的原值。
                guard index < element.data.count, element.data[index].isFinite,
                      element.data[index] != 0 else { continue }
                // 基准值（堆叠）：符号链前累计 = 自身累计 − 自身基准原值（percent 时为归一化原值）
                let baselineValue: Double?
                if model.isStacked {
                    let rawBase = currentBaseValues[seriesIndex]
                    let base = value - (index < rawBase.count ? rawBase[index] : 0)
                    baselineValue = base
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
                    seriesIndex: slot,
                    seriesCount: seriesCount
                )
                guard !rect.isEmpty else { continue }
                rect = animatedRect(from: rect, zeroX: zeroX, progress: currentAnimationProgress)

                // 同组同符号链仅末段外端圆角。
                let hasNext = model.isStacked && model.series[(seriesIndex + 1)...].contains {
                    $0.isVisible && $0.stackKey == model.stackKey(for: seriesIndex)
                    && index < $0.data.count && $0.data[index].isFinite && $0.data[index] != 0
                    && ($0.data[index] > 0) == (value > 0)
                }
                let corners: UIRectCorner = hasNext ? [] : (value >= 0 ? [.topRight, .bottomRight] : [.topLeft, .bottomLeft])
                let barPath = UIBezierPath(
                    roundedRect: rect, byRoundingCorners: corners,
                    cornerRadii: CGSize(width: theme.columnCornerRadius, height: theme.columnCornerRadius))

                let fillColor: UIColor
                if value < 0, negativeColor != baseColor {
                    fillColor = negativeColor
                } else if let barColors = element.barColors, !barColors.isEmpty {
                    fillColor = barColors[index % barColors.count]
                } else {
                    fillColor = baseColor
                }
                if pathsByColor[fillColor] == nil { pathsByColor[fillColor] = UIBezierPath() }
                pathsByColor[fillColor]!.append(barPath)

                if wantsStackTotals && element.participatesInStack {
                    stackTotals.add(rawValue: element.data[index], category: index,
                                    axis: 0, rect: rect,
                                    horizontal: true, stack: slot)
                }

                // 堆叠且非最后系列：记录分隔线 x
                if hasNext {
                    let x = value >= 0 ? rect.maxX : rect.minX
                    separatorPath.move(to: CGPoint(x: x, y: rect.minY))
                    separatorPath.addLine(to: CGPoint(x: x, y: rect.maxY))
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
                    annotationLayer.addSublayer(makeDataLabelLayer(
                        text: text, fontSize: theme.dataLabelFontSize,
                        color: dataLabelColor(theme: theme,
                                              inside: theme.dataLabelPosition != .outsideEnd),
                        center: center, objects: seriesObjects))
                }
            }

            for (color, path) in pathsByColor where !path.isEmpty {
                seriesLayer.addSublayer(makeBarLayer(path: path, color: color, theme: theme))
            }
            // 阴影走隐形 caster（挂裁剪层外）：条端贴 plot 边界，画在 seriesLayer
            // 内会被 masksToBounds 裁光
            if let shadowStyle = element.shadow ?? theme.seriesShadow {
                let union = UIBezierPath()
                for (_, p) in pathsByColor where !p.isEmpty { union.append(p) }
                if !union.isEmpty {
                    addSeriesShadowCaster(path: union.cgPath, style: shadowStyle)
                }
            }
            if !separatorPath.isEmpty, let separatorColor = theme.stackSeparatorColor {
                let line = seriesObjects.shape()
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

    /// 条形复合 path → 填充层（带可选边框）。
    private func makeBarLayer(path: UIBezierPath, color: UIColor, theme: CartesianChartTheme) -> CAShapeLayer {
        let layer = seriesObjects.shape()
        layer.path = path.cgPath
        layer.fillColor = color.cgColor
        layer.strokeColor = theme.columnBorderColor?.cgColor
        layer.lineWidth = theme.columnBorderWidth
        return layer
    }

    /// 子类实现：命中测试
    public override func seriesHitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard let model = currentModel else { return nil }
        guard !model.series.isEmpty else { return nil }

        // 1. 类目在 Y 轴（恒全量）：屏幕点 → 类目值 → 最近类目中心
        //    （用水平图专用映射：类目 0 在顶部，与 barRect/标签/网格同一方向）
        let yValue = CartesianGeometry.horizontalCategory(atY: point.y,
                                                          viewport: currentViewport,
                                                          plotFrame: currentPlotFrame)
        let categoryIndex = Int(yValue.rounded())

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
        guard element.isVisible, includesSeries(seriesIndex), element.data.indices.contains(categoryIndex),
              element.data[categoryIndex].isFinite, element.data[categoryIndex] != 0 else { return nil }
        let value = currentDrawValues[seriesIndex][categoryIndex]
        guard value.isFinite else { return nil }

        let zero = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport, plotArea: currentPlotFrame, isHorizontal: true)
        let rect = CartesianGeometry.barRect(
                dataPoint: value, categoryIndex: categoryIndex, viewport: currentViewport,
                plotArea: currentPlotFrame, theme: theme, zeroX: zero,
                baselineValue: model.isStacked ? value - currentBaseValues[seriesIndex][categoryIndex] : nil,
                seriesIndex: model.columnSlot(for: seriesIndex),
                seriesCount: model.columnSlotCount)
        return rect.isEmpty ? nil : rect
    }

    public override func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard currentTheme?.showsTooltipOnHit == true, let rect = hitFrame(for: target) else { return nil }
        return HYMChartTooltipAnchor(frame: rect, preferredPlacements: [.top, .bottom])
    }

    public override func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
        guard let target = target as? BarHitTarget else { return nil }
        return markRect(seriesIndex: target.seriesIndex, categoryIndex: target.categoryIndex)
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
                            value: value, name: model.series[seriesIndex].name, seriesID: model.series[seriesIndex].id,
                            datum: datum(series: seriesIndex, category: categoryIndex))
    }
}
