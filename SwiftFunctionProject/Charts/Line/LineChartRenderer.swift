import UIKit

/// 折线图命中目标（点中数据点时产生）。
public struct LineHitTarget: HYMChartHitTarget {
    public let identifier: String
    public let index: Int
    public let seriesIndex: Int
    /// 命中数据点的值。
    public let value: Double
    public let tooltipText: String?

    public init(seriesIndex: Int, index: Int, value: Double, label: String?) {
        self.seriesIndex = seriesIndex
        self.index = index
        self.value = value
        let name = label ?? "series \(seriesIndex)"
        self.identifier = "\(name):\(index)"
        self.tooltipText = "\(name) · \(AxisRenderer.format(value))"
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

        // 零轴（面积填充的闭合边界；Y 轴数据驱动，缩放中恒定）
        let zeroY = CartesianGeometry.zeroAxisPosition(
            viewport: currentViewport, plotArea: plotFrame, isHorizontal: false)

        for (s, element) in model.series.enumerated() {
            guard !element.data.isEmpty else { continue }
            let color = element.color ?? theme.seriesColor

            // 数据点屏幕坐标（命中 frame 按数据点，与阶梯形态无关）
            let screenPts = element.data.enumerated().map { (i, v) -> CGPoint in
                screenPoint(x: Double(i), y: v)
            }
            for (i, p) in screenPts.enumerated() {
                let r = max(hitRadius, theme.pointRadius)   // 命中半径 ≥ 视觉点半径
                lastPointFrames.append((s, i,
                    CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)))
            }

            // 折线 path（连接形态在此应用：直线/阶梯 = 过渡点折线，曲线 = Catmull-Rom；
            // 视口外的点也连线，保证可见段两侧的线形完整，溢出部分由 seriesLayer 裁剪）
            let path = UIBezierPath()
            if theme.lineConnectionStyle == .smooth {
                guard let first = screenPts.first else { continue }
                path.move(to: first)
                CartesianGeometry.appendSmoothCurve(to: path, points: screenPts)
            } else {
                let pathPts = CartesianGeometry.steppedScreenPoints(screenPts, style: theme.lineConnectionStyle)
                for (i, p) in pathPts.enumerated() {
                    i == 0 ? path.move(to: p) : path.addLine(to: p)
                }
            }

            // 面积填充（面积图形态）：折线 path 闭合到零轴 → CAGradientLayer + mask。
            // 先于线添加（线压在面积上）；渐变自上而下（近线浓 → 近零轴淡）。
            if theme.showsArea, let first = screenPts.first, let last = screenPts.last {
                let areaPath = UIBezierPath(cgPath: path.cgPath)
                areaPath.addLine(to: CGPoint(x: last.x, y: zeroY))
                areaPath.addLine(to: CGPoint(x: first.x, y: zeroY))
                areaPath.close()

                let gradient = CAGradientLayer()
                gradient.frame = plotFrame
                // 坐标系对齐（与 seriesLayer 同技巧）：mask 的 path 是 view 绝对坐标
                gradient.bounds.origin = plotFrame.origin
                gradient.colors = (theme.areaGradientColors ?? [
                    color.withAlphaComponent(0.35).cgColor,
                    color.withAlphaComponent(0.04).cgColor
                ])
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
            seriesLayer.addSublayer(line)
            lineLayers.append(line)

            // 数据点（画在原始数据点位置，与阶梯形态无关）
            if theme.showsPoints {
                for p in screenPts {
                    let dot = CALayer()
                    dot.frame = CGRect(x: p.x - theme.pointRadius, y: p.y - theme.pointRadius,
                                       width: theme.pointRadius * 2, height: theme.pointRadius * 2)
                    dot.cornerRadius = theme.pointRadius
                    dot.backgroundColor = (theme.pointColor ?? color).cgColor
                    dot.borderColor = UIColor.white.cgColor
                    dot.borderWidth = 1
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
            let value = model.series[hit.series].data[hit.index]
            return LineHitTarget(seriesIndex: hit.series, index: hit.index,
                                 value: value,
                                 label: model.series[hit.series].name)
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
        return screenPoint(x: Double(index), y: model.series[series].data[index])
    }
}
