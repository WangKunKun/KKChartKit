import UIKit

/// 折线图命中目标（点中数据点时产生）。
public struct LineHitTarget: HYMChartHitTarget {
    public let identifier: String
    public let index: Int
    public let seriesIndex: Int
    /// 命中数据点的值。
    public let value: Double
    /// 绑定的值轴（0 = 主轴/左，1 = 次轴/右）。
    public let yAxisIndex: Int
    public let tooltipText: String?

    public init(seriesIndex: Int, index: Int, value: Double, label: String?, yAxisIndex: Int = 0) {
        self.seriesIndex = seriesIndex
        self.index = index
        self.value = value
        self.yAxisIndex = yAxisIndex
        let name = label ?? "series \(seriesIndex)"
        self.identifier = "\(name):\(index)"
        var text = "\(name) · \(AxisRenderer.format(value))"
        if yAxisIndex == 1 { text += " (右轴)" }
        self.tooltipText = text
    }
}

/// 折线图渲染器：CartesianRendererBase 的首个薄 Renderer——
/// 只负责"把 series 画成折线 + 数据点 + 点命中 + strokeEnd 生长动画"。
public final class LineChartRenderer: CartesianRendererBase<CartesianChartTheme> {

    /// 命中检测缓存：各数据点 frame（view 坐标系，正方形=命中半径直径）。
    private var lastPointFrames: [(series: Int, index: Int, frame: CGRect)] = []
    /// 折线层（入场动画 strokeEnd 驱动）。
    private var lineLayers: [CAShapeLayer] = []
    /// 命中半径（pt）。
    private let hitRadius: CGFloat = 10

    // MARK: - drawSeries（模板方法扩展点）
    public override func drawSeries(model: CartesianChartModel,
                                    theme: CartesianChartTheme,
                                    plotFrame: CGRect) {
        // 清空旧内容（render 与动画/手势的逐帧重画共用本方法，必须先清后画）
        seriesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        lastPointFrames.removeAll()
        lineLayers.removeAll()

        // 堆叠：normal=符号链累计 / percent=百分比累计；非堆叠用原值
        let dataToDraw = model.stackedDrawValues

        for (s, element) in model.series.enumerated() {
            guard !element.data.isEmpty else { continue }
            let color = element.color ?? theme.seriesColor
            let axisIdx = element.effectiveYAxisIndex
            let values = dataToDraw[s]

            // 零轴（面积填充的闭合边界；按系列所属值域计算，双轴负值各自正确）
            let zeroY = CartesianGeometry.zeroAxisPosition(
                viewport: currentViewport, plotArea: plotFrame, isHorizontal: false,
                valueDomain: axisIdx == 1 ? currentSecondaryYDomain : nil)

            // 空值（NaN）分段：有效索引按连续性切分（connectNulls 合成一段全直连）；
            // 每段独立成子路径——线断、面积分段、点与命中只取有效点
            let finiteIndices = values.indices.filter { values[$0].isFinite }
            guard !finiteIndices.isEmpty else { continue }
            var segments: [[Int]] = []
            if element.connectNulls {
                segments = [finiteIndices]
            } else {
                var run: [Int] = []
                for idx in finiteIndices {
                    if let last = run.last, idx == last + 1 { run.append(idx) }
                    else { if !run.isEmpty { segments.append(run) }; run = [idx] }
                }
                if !run.isEmpty { segments.append(run) }
            }

            // 每段屏幕坐标（命中 frame 按数据点，与阶梯形态无关）
            var segmentPoints: [[CGPoint]] = []
            for seg in segments {
                segmentPoints.append(seg.map { idx in
                    screenPoint(x: Double(idx), y: values[idx], yAxisIndex: axisIdx)
                })
            }
            for (segIdx, seg) in segments.enumerated() {
                for (k, p) in segmentPoints[segIdx].enumerated() {
                    let r = max(hitRadius, theme.pointRadius)   // 命中半径 ≥ 视觉点半径
                    lastPointFrames.append((s, seg[k],
                        CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)))
                }
            }

            // 折线 path（连接形态在此应用：直线/阶梯 = 过渡点折线，曲线 = 单调插值；
            // 每段一个子路径，视口外的点也连线，溢出由 seriesLayer 裁剪）
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
                    let rawBaseFull = model.rawBaseValues(forSeries: s)
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
                        let basePts = theme.lineConnectionStyle == .smooth
                            ? baseData
                            : CartesianGeometry.steppedScreenPoints(baseData, style: theme.lineConnectionStyle)
                        for pp in basePts.reversed() { areaPath.addLine(to: pp) }
                    } else {
                        areaPath.addLine(to: CGPoint(x: last.x, y: zeroY))
                        areaPath.addLine(to: CGPoint(x: first.x, y: zeroY))
                    }
                    areaPath.close()
                }

                let gradient = CAGradientLayer()
                gradient.frame = plotFrame
                // 坐标系对齐（与 seriesLayer 同技巧）：mask 的 path 是 view 绝对坐标
                gradient.bounds.origin = plotFrame.origin
                // colors 必须用 CGColor：直接传 UIColor 数组在某些渲染路径（离屏/无分辨上下文）不出色
                gradient.colors = (theme.areaGradientColors?.map { $0.cgColor }) ?? [
                    color.withAlphaComponent(0.35).cgColor,
                    color.withAlphaComponent(0.04).cgColor
                ]
                gradient.startPoint = CGPoint(x: 0.5, y: 0)
                gradient.endPoint = CGPoint(x: 0.5, y: 1)

                let mask = CAShapeLayer()
                mask.path = areaPath.cgPath
                gradient.mask = mask
                seriesLayer.addSublayer(gradient)
            }

            let line = CAShapeLayer()
            line.path = path.cgPath
            line.strokeColor = color.cgColor
            line.fillColor = nil
            line.lineWidth = theme.lineWidth
            line.lineJoin = .round
            line.lineCap = .round
            // 虚线/点线（圆头线帽下 1pt 段呈现为点）；nil = 实线
            line.lineDashPattern = (element.lineDashStyle ?? theme.lineDashStyle).dashPattern
            seriesLayer.addSublayer(line)
            lineLayers.append(line)

            // 数据点（画在有效数据点位置，与阶梯形态无关；空值处不画点）。
            // 标记符号：圆/方/菱/正三角/倒三角（系列级覆盖主题）
            if theme.showsPoints {
                let symbol = element.pointSymbol ?? theme.pointSymbol
                for p in segmentPoints.flatMap({ $0 }) {
                    let dot = CAShapeLayer()
                    dot.path = symbol.path(center: p, radius: theme.pointRadius)
                    dot.fillColor = (theme.pointColor ?? color).cgColor
                    dot.strokeColor = UIColor.white.cgColor
                    dot.lineWidth = 1
                    seriesLayer.addSublayer(dot)
                }
            }
        }
    }

    // MARK: - 命中（近者优先；正方形 frame 含点即命中）
    public override func seriesHitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard let model = currentModel else { return nil }
        // 后面的 series 画在上层 → 倒序先查
        for hit in lastPointFrames.reversed() where hit.frame.contains(point) {
            // 堆叠时命中报累计值（与柱状现状对齐）
            let value: Double
            if model.stacking == .normal || model.stacking == .percent {
                value = model.stackedDrawValues[hit.series][hit.index]
            } else {
                value = model.series[hit.series].data[hit.index]
            }
            return LineHitTarget(seriesIndex: hit.series, index: hit.index,
                                 value: value,
                                 label: model.series[hit.series].name,
                                 yAxisIndex: model.series[hit.series].effectiveYAxisIndex)
        }
        return nil
    }

    // MARK: - 弹窗锚点（数据点正方形 frame，上下避让）
    public override func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard let t = target as? LineHitTarget,
              currentTheme?.showsTooltipOnHit == true,
              let hit = lastPointFrames.first(where: { $0.series == t.seriesIndex && $0.index == t.index })
        else { return nil }
        return HYMChartTooltipAnchor(frame: hit.frame, preferredPlacements: [.top, .bottom])
    }

    public override func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
        guard let t = target as? LineHitTarget,
              let hit = lastPointFrames.first(where: { $0.series == t.seriesIndex && $0.index == t.index })
        else { return nil }
        return hit.frame
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
        if model.stacking == .normal || model.stacking == .percent {
            value = model.stackedDrawValues[series][index]
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
                             yAxisIndex: element.effectiveYAxisIndex)
    }
}
