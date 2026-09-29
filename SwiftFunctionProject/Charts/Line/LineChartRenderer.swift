import UIKit

/// 折线图命中目标（点中数据点时产生）。
public struct LineHitTarget: HYMChartHitTarget, CartesianHitDataSource {
    /// 明确的数据语义。旧 value 继续表示历史绘制值，业务请使用 rawValue/displayValue。
    public let datum: CartesianDatum?
    public var rawValue: Double? { datum?.rawValue }
    public var drawValue: Double { datum?.drawValue ?? value }
    public var stackBase: Double? { datum?.stackBase }
    public var percentage: Double? { datum?.percentage }
    public var chartData: [CartesianDatum] { datum.map { [$0] } ?? [] }
    public let identifier: String
    public let index: Int
    public let seriesID: String?
    public let seriesIndex: Int
    /// 命中数据点的值。
    public let value: Double
    /// 绑定的值轴（0 = 主轴/左，1 = 次轴/右）。
    public let yAxisIndex: Int
    public let tooltipText: String?
    /// 系列名（弹窗模板数据源用）
    public let name: String

    public init(seriesIndex: Int, index: Int, value: Double, label: String?, yAxisIndex: Int = 0, seriesID: String? = nil, datum: CartesianDatum? = nil) {
        self.datum = datum
        self.seriesID = seriesID
        self.seriesIndex = seriesIndex
        self.index = index
        self.value = value
        self.yAxisIndex = yAxisIndex
        let name = label ?? "series \(seriesIndex)"
        self.name = name
        self.identifier = "\(name):\(index)"
        var text = "\(name) · \(AxisRenderer.format(value))"
        if yAxisIndex == 1 { text += " (右轴)" }
        self.tooltipText = CartesianDatumText.text(datum.map { [$0] } ?? []) ?? text
    }
}

extension LineHitTarget: HYMChartTooltipDataSource {
    public var tooltipRows: [(name: String, value: Double, isSecondaryAxis: Bool)] {
        if let datum { return [(datum.name, datum.displayValue, datum.yAxisIndex == 1)] }
        return [(name, value, yAxisIndex == 1)]
    }
    public var tooltipHeaderKey: String? { nil }
}

/// 折线图渲染器：CartesianRendererBase 的首个薄 Renderer——
/// 只负责"把 series 画成折线 + 数据点 + 点命中 + strokeEnd 生长动画"。
public final class LineChartRenderer: CartesianRendererBase<CartesianChartTheme> {
    override func resolvedModel(_ model: CartesianChartModel) -> CartesianChartModel {
        var result = model
        result.usesMixedSeries = false
        for i in result.series.indices { result.series[i].stackFamilyIsColumn = false }
        return result
    }


    /// 命中检测缓存：各数据点 frame（view 坐标系，正方形=命中半径直径）。
    private var lastPointFrames: [(series: Int, index: Int, frame: CGRect)] = []
    /// 内部诊断（测试检查绘制规模，不改变公开命中值语义）。
    private(set) var renderedIndices: [Int: [[Int]]] = [:]
    private(set) var denseSeries: Set<Int> = []
    private var usesSampling = false
    /// 折线层（入场动画 strokeEnd 驱动）。
    private var lineLayers: [CAShapeLayer] = []
    /// 命中半径（pt）。
    private let hitRadius: CGFloat = 10

    public override func legendSymbol(for series: CartesianSeriesElement, theme: CartesianChartTheme) -> ChartLegendSymbol {
        let theme = series.lineTheme(theme)
        return theme.showsPoints ? .lineWithMarker(series.pointSymbol ?? theme.pointSymbol) : .line
    }

    // MARK: - drawSeries（模板方法扩展点）
    public override func drawSeries(model: CartesianChartModel,
                                    theme: CartesianChartTheme,
                                    plotFrame: CGRect) {
        // 清空旧内容（render 与动画/手势的逐帧重画共用本方法，必须先清后画）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        seriesObjects.begin(reusing: theme.reusesRenderingObjects)
        defer { seriesObjects.end(); CATransaction.commit() }
        seriesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        lastPointFrames.removeAll()
        renderedIndices.removeAll()
        denseSeries.removeAll()
        usesSampling = theme.lineSampling != nil && !model.isStacked
            && model.series.filter(\.isVisible).allSatisfy { $0.lineTheme(theme).lineConnectionStyle == .straight }
        if case .grouped = model.stacking { usesSampling = false }
        lineLayers.removeAll()
        clearSeriesShadowCasters()

        // 堆叠：normal=符号链累计 / percent=百分比累计；非堆叠用原值
        let dataToDraw = currentDrawValues
        let inheritedTheme = theme
        let sampleInterval = model.timeAxis.flatMap { $0.isValid(count: model.maxPointCount) ? $0.interval : nil }

        for (s, element) in model.series.enumerated() {
            guard element.isVisible, includesSeries(s), !element.data.isEmpty else { continue }
            let theme = element.lineTheme(theme)
            let color = element.color ?? theme.seriesColor
            let axisIdx = element.effectiveYAxisIndex
            let values = dataToDraw[s]

            // 零轴（面积填充的闭合边界；按系列所属值域计算，双轴负值各自正确）
            let zeroY = CartesianGeometry.zeroAxisPosition(
                viewport: currentViewport, plotArea: plotFrame, isHorizontal: false,
                valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil)

            // 在原始索引上按缺测策略分段，再进行降采样；nil 策略兼容 connectNulls。
            // 每段独立成子路径——线断、面积分段、点与命中只取有效点
            let selection: LineRenderSelection
            if usesSampling, let configuration = theme.lineSampling {
                selection = LineMinMaxSampler.select(values: values, connectNulls: element.connectNulls,
                    visibleRange: currentViewport.xDomain, plotWidth: plotFrame.width, configuration: configuration,
                    gapPolicy: element.gapPolicy, sampleInterval: sampleInterval)
            } else {
                let original = LineMinMaxSampler.segments(values: values, connectNulls: element.connectNulls,
                                                         gapPolicy: element.gapPolicy, sampleInterval: sampleInterval)
                selection = LineRenderSelection(segments: original,
                    visiblePointCount: original.reduce(0) { $0 + $1.count }, isDense: false)
            }
            let segments = selection.segments
            guard !segments.isEmpty else { continue }
            renderedIndices[s] = segments
            if selection.isDense { denseSeries.insert(s) }
            let showsMarkers = theme.showsPoints && !(selection.isDense && theme.lineSampling?.hidesDenseMarkers == true)
            let showsLabels = !(selection.isDense && theme.lineSampling?.hidesDenseDataLabels == true)

            // 每段屏幕坐标（命中 frame 按数据点，与阶梯形态无关）
            var segmentPoints: [[CGPoint]] = []
            for seg in segments {
                segmentPoints.append(seg.map { idx in
                    screenPoint(x: Double(idx), y: values[idx], yAxisIndex: axisIdx)
                })
            }
            if !usesSampling {
                for (segIdx, seg) in segments.enumerated() {
                    for (k, p) in segmentPoints[segIdx].enumerated() {
                        let r = max(hitRadius, theme.pointRadius)
                        lastPointFrames.append((s, seg[k],
                            CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)))
                    }
                }
            }

            // 先生成完整路径，再按 X/Y 条带裁剪上色。曲线只插值一次，换色不会改变切线。
            let zones = CartesianResolvedColorZones(configuration: element.colorZones,
                negativeColor: element.negativeColor, baseColor: color)
            let regions = zones?.regions(viewport: currentViewport,
                yDomain: axisIdx == 1 ? currentSecondaryYDomain : nil, plot: plotFrame) ?? []
            let path = UIBezierPath()
            for pts in segmentPoints {
                guard let first = pts.first else { continue }
                if theme.lineConnectionStyle == .smooth {
                    path.move(to: first)
                    CartesianGeometry.appendSmoothCurve(to: path, points: pts)
                } else {
                    let pathPts = CartesianGeometry.steppedScreenPoints(pts, style: theme.lineConnectionStyle)
                    for (i, p) in pathPts.enumerated() {
                        i == 0 ? path.move(to: p) : path.addLine(to: p)
                    }
                }
            }

            // 面积填充（面积图形态）：每段独立闭合（空值处面积断开）；
            // 堆叠时分层下边界 = 同符号链基准（自身累计 − 基准原值，percent 为归一化原值）。
            if theme.showsArea, !path.isEmpty {
                var base: [Double]? = nil
                if model.isStacked {
                    let rawBaseFull = currentBaseValues[s]
                    let rawBase = rawBaseFull + [Double](repeating: 0,
                        count: max(0, values.count - rawBaseFull.count))
                    base = zip(values, rawBase).map { $0 - $1 }
                }
                // 每段独立构建面积子路径（正向折线 + 反向下边界 + close）：
                // 不能从整条折线 path 拷贝后追加——close 会闭错子路径、回走起点错乱
                let areaPath = UIBezierPath()
                for (segIdx, seg) in segments.enumerated() {
                    let pts = segmentPoints[segIdx]
                    guard let first = pts.first, let last = pts.last else { continue }
                    // 正向：与折线同一连接形态
                    if theme.lineConnectionStyle == .smooth {
                        areaPath.move(to: first)
                        CartesianGeometry.appendSmoothCurve(to: areaPath, points: pts)
                    } else {
                        let pathPts = CartesianGeometry.steppedScreenPoints(pts, style: theme.lineConnectionStyle)
                        for (i, p) in pathPts.enumerated() {
                            i == 0 ? areaPath.move(to: p) : areaPath.addLine(to: p)
                        }
                    }
                    // 反向：下边界（堆叠 = 同符号链基准，与折线同形态；否则闭合到零轴）
                    if let base = base {
                        let baseData = seg.map { idx in
                            screenPoint(x: Double(idx), y: base[idx], yAxisIndex: axisIdx)
                        }
                        let lowerStyle = baselineStyle(series: s, indices: seg, base: base,
                                                       model: model, theme: inheritedTheme)
                        if lowerStyle == .smooth {
                            // 下边界 = 前一层累计线的同一条平滑曲线倒序回走：
                            // 若用直连线（旧实现），上层面积顶部是曲线、下层底部是弦线——
                            // 曲线拱起处露白、下凹处叠色（堆叠+平滑+面积的报告缺陷）
                            if let lastBase = baseData.last { areaPath.addLine(to: lastBase) }
                            CartesianGeometry.appendSmoothCurveReversed(to: areaPath, points: baseData)
                        } else {
                            let basePts = CartesianGeometry.steppedScreenPoints(
                                baseData, style: lowerStyle)
                            for pp in basePts.reversed() { areaPath.addLine(to: pp) }
                        }
                    } else {
                        areaPath.addLine(to: CGPoint(x: last.x, y: zeroY))
                        areaPath.addLine(to: CGPoint(x: first.x, y: zeroY))
                    }
                    areaPath.close()
                }

                if zones?.overridesArea == true {
                    for region in regions {
                        LineChartColorLayers.area(path: areaPath.cgPath,
                            color: region.zone.areaGradientColors != nil ? (region.zone.color ?? color) : color,
                            colors: region.zone.areaGradientColors ?? theme.areaGradientColors,
                            opacity: element.style.resolvedFillOpacity, plot: plotFrame, clip: region.clip,
                            parent: seriesLayer, pool: seriesObjects)
                    }
                } else {
                    // 只设置线色（包括旧 negativeColor）时保持既有面积渐变。
                    LineChartColorLayers.area(path: areaPath.cgPath, color: color, colors: theme.areaGradientColors,
                        opacity: element.style.resolvedFillOpacity, plot: plotFrame, clip: nil,
                        parent: seriesLayer, pool: seriesObjects)
                }
            }

            if !path.isEmpty {
                let dash = element.lineDashStyle ?? theme.lineDashStyle
                if zones != nil {
                    for region in regions {
                        lineLayers.append(LineChartColorLayers.line(path: path.cgPath,
                            color: region.zone.color ?? color, theme: theme, dash: dash, clip: region.clip,
                            parent: seriesLayer, pool: seriesObjects))
                    }
                } else {
                    lineLayers.append(LineChartColorLayers.line(path: path.cgPath, color: color,
                        theme: theme, dash: dash, clip: nil, parent: seriesLayer, pool: seriesObjects))
                }
                // 阴影使用完整路径一次，不因分区叠加加深。
                if let shadowStyle = element.shadow ?? theme.seriesShadow {
                    addSeriesShadowCaster(path: path.cgPath, style: shadowStyle)
                }
            }
            // 数据点（画在有效数据点位置，与阶梯形态无关；空值处不画点）。
            // 标记符号：圆/方/菱/正三角/倒三角（系列级覆盖主题）；点色优先级为 pointColor、分区、系列色；
            // 空心内芯（pointHoleRadius > 0）：同形状缩小版叠在点上（Charts holeRadius 同款）
            // 密集模式也保留孤立有效点的标记，否则“一点一缺测”会变成完全空白。
            if showsMarkers || (theme.showsPoints && segments.contains(where: { $0.count == 1 })) {
                let symbol = element.pointSymbol ?? theme.pointSymbol
                let holeR = min(theme.pointHoleRadius, theme.pointRadius - 0.5)
                for (segIdx, seg) in segments.enumerated() {
                    if !showsMarkers && seg.count > 1 { continue }
                    for (k, p) in segmentPoints[segIdx].enumerated() {
                        let i = seg[k]
                        if usesSampling && !currentViewport.xDomain.contains(Double(i)) { continue }
                        let dotColor = theme.pointColor
                            ?? (zones?.color(x: Double(i), y: values[i]) ?? color)
                        let dot = seriesObjects.shape()
                        dot.path = symbol.path(center: p, radius: theme.pointRadius)
                        dot.fillColor = dotColor.cgColor
                        dot.strokeColor = UIColor.white.cgColor
                        dot.lineWidth = 1
                        seriesLayer.addSublayer(dot)
                        if holeR > 0 {
                            let hole = seriesObjects.shape()
                            hole.path = symbol.path(center: p, radius: holeR)
                            hole.fillColor = theme.pointHoleColor.cgColor
                            hole.strokeColor = nil
                            seriesLayer.addSublayer(hole)
                        }
                    }
                }
            }

            // 数据标签：数值 = 系列原值（堆叠时也标各段自身值，位置在累计后的点上）；
            // outsideEnd = 点上方，center/insideEnd = 点下方。挂 rootLayer（不被 plot 裁剪）。
            if showsLabels && dataLabelsAllowed(for: element, theme: theme) {
                let labelColor = dataLabelColor(theme: theme, inside: false)
                let radius = showsMarkers ? theme.pointRadius : 0
                for (segIdx, seg) in segments.enumerated() {
                    let pts = segmentPoints[segIdx]
                    for (k, p) in pts.enumerated()
                    where visibleCategoryRange.contains(seg[k]) {
                        let i = seg[k]
                        guard i < element.data.count, element.data[i].isFinite else { continue }
                        let text = CartesianDataLabelGeometry.labelText(
                            element.data[i], formatter: theme.dataLabelFormatter)
                        let size = dataLabelTextSize(text, fontSize: theme.dataLabelFontSize)
                        let center = CartesianDataLabelGeometry.labelCenter(
                            point: p, textSize: size,
                            position: theme.dataLabelPosition, pointRadius: radius)
                        rootLayer.addSublayer(makeDataLabelLayer(
                            text: text, fontSize: theme.dataLabelFontSize,
                            color: labelColor, center: center, objects: seriesObjects))
                    }
                }
            }
        }
    }

    /// 连续同符号链的下边界沿用前层形态，避免逐系列连接覆盖造成层间露白/叠色。
    /// 缺测或换符号导致一段内基准来自不同系列时，回退该段自身的连接方式。
    private func baselineStyle(series: Int, indices: [Int], base: [Double],
                               model: CartesianChartModel, theme: CartesianChartTheme) -> LineConnectionStyle {
        let key = model.stackKey(for: series)
        for previous in (0..<series).reversed() {
            let element = model.series[previous]
            guard element.isVisible, model.stackKey(for: previous) == key else { continue }
            let values = currentDrawValues[previous]
            if indices.allSatisfy({ index in
                index < element.data.count && element.data[index].isFinite && index < values.count
                && abs(values[index] - base[index]) <= 1e-9
            }) { return element.lineTheme(theme).lineConnectionStyle }
        }
        return model.series[series].lineTheme(theme).lineConnectionStyle
    }

    // MARK: - 命中（近者优先；正方形 frame 含点即命中）
    public override func seriesHitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard let model = currentModel else { return nil }
        if usesSampling { return originalPointHit(at: point) }
        // 后面的 series 画在上层 → 倒序先查
        for hit in lastPointFrames.reversed() where hit.frame.contains(point) {
            // 堆叠时命中报累计值（与柱状现状对齐）
            let value: Double
            if model.isStacked {
                value = currentDrawValues[hit.series][hit.index]
            } else {
                value = model.series[hit.series].data[hit.index]
            }
            return LineHitTarget(seriesIndex: hit.series, index: hit.index,
                                 value: value,
                                 label: model.series[hit.series].name,
                                 yAxisIndex: model.series[hit.series].effectiveYAxisIndex,
                                 seriesID: model.series[hit.series].id, datum: datum(series: hit.series, category: hit.index))
        }
        return nil
    }

    // MARK: - 弹窗锚点（数据点正方形 frame，上下避让）
    public override func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard currentTheme?.showsTooltipOnHit == true, let frame = hitFrame(for: target) else { return nil }
        return HYMChartTooltipAnchor(frame: frame, preferredPlacements: [.top, .bottom])
    }

    public override func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
        guard let t = target as? LineHitTarget else { return nil }
        if usesSampling { return originalPointFrame(series: t.seriesIndex, index: t.index) }
        return lastPointFrames.first(where: { $0.series == t.seriesIndex && $0.index == t.index })?.frame
    }

    /// 只在点击容差所覆盖的原始索引范围内查找。省略的绘制点仍可命中，不为所有原始点建 frame。
    private func originalPointHit(at point: CGPoint) -> LineHitTarget? {
        guard let model = currentModel, currentPlotFrame.contains(point), currentPlotFrame.width > 0 else { return nil }
        let radius = max(hitRadius, model.series.map { $0.lineTheme(currentTheme ?? .init()).pointRadius }.max() ?? 0)
        let span = currentViewport.xMax - currentViewport.xMin
        let lo = currentViewport.xMin + Double((point.x - radius - currentPlotFrame.minX) / currentPlotFrame.width) * span
        let hi = currentViewport.xMin + Double((point.x + radius - currentPlotFrame.minX) / currentPlotFrame.width) * span
        guard lo.isFinite, hi.isFinite else { return nil }
        for s in model.series.indices.reversed() where model.series[s].isVisible && includesSeries(s) {
            let count = model.series[s].data.count
            guard count > 0 else { continue }
            let lower = Int(max(0, min(Double(count), ceil(lo))))
            let upper = Int(max(0, min(Double(count - 1), floor(hi))))
            guard lower <= upper else { continue }
            var closest: (index: Int, distance: CGFloat)?
            for i in lower...upper {
                guard let frame = originalPointFrame(series: s, index: i), frame.contains(point) else { continue }
                let distance = hypot(frame.midX - point.x, frame.midY - point.y)
                if closest == nil || distance < closest!.distance { closest = (i, distance) }
            }
            if let hit = closest {
                let element = model.series[s]
                return LineHitTarget(seriesIndex: s, index: hit.index, value: element.data[hit.index],
                    label: element.name, yAxisIndex: element.effectiveYAxisIndex, seriesID: element.id,
                    datum: datum(series: s, category: hit.index))
            }
        }
        return nil
    }

    private func originalPointFrame(series: Int, index: Int) -> CGRect? {
        guard let model = currentModel, model.series.indices.contains(series) else { return nil }
        let element = model.series[series]
        guard element.isVisible, includesSeries(series), element.data.indices.contains(index), element.data[index].isFinite,
              currentViewport.xDomain.contains(Double(index)) else { return nil }
        let p = screenPoint(x: Double(index), y: element.data[index], yAxisIndex: element.effectiveYAxisIndex)
        let radius = max(hitRadius, element.lineTheme(currentTheme ?? .init()).pointRadius)
        return CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
    }

    // MARK: - 入场动画：折线 strokeEnd 0→1 生长（点/网格随 rootLayer opacity 淡入）
    public override func updateSeriesAnimation(progress: Double) {
        for line in lineLayers {
            line.strokeEnd = CGFloat(min(max(progress, 0), 1))
        }
    }

    // MARK: - 测试辅助（DEBUG 自检用屏幕映射）
    func testScreenPoint(series: Int, index: Int) -> CGPoint {
        guard let model = currentModel,
              series < model.series.count, index < model.series[series].data.count else {
            return .zero
        }
        // 堆叠模式返回累计值位置（与绘制同源）
        let value: Double
        if model.isStacked {
            value = currentDrawValues[series][index]
        } else {
            value = model.series[series].data[index]
        }
        return screenPoint(x: Double(index), y: value,
                           yAxisIndex: model.series[series].effectiveYAxisIndex)
    }

    /// DEBUG 自检辅助：seriesLayer 子层（面积渐变层数量断言用）。
    func seriesLayerSublayersForTesting() -> [CALayer] { seriesLayer.sublayers ?? [] }

    /// 吸附命中 → LineHitTarget（含轴索引，弹窗带右轴标记）。
    public override func makeHitTarget(seriesIndex: Int, categoryIndex: Int, value: Double)
        -> (any HYMChartHitTarget)? {
        guard let model = currentModel, seriesIndex < model.series.count else { return nil }
        let element = model.series[seriesIndex]
        return LineHitTarget(seriesIndex: seriesIndex, index: categoryIndex,
                             value: value, label: element.name,
                             yAxisIndex: element.effectiveYAxisIndex, seriesID: element.id,
                             datum: datum(series: seriesIndex, category: categoryIndex))
    }
}
