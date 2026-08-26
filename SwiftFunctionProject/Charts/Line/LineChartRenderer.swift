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
        lastPointFrames.removeAll()
        lineLayers.removeAll()

        for (s, element) in model.series.enumerated() {
            guard !element.data.isEmpty else { continue }
            let color = element.color ?? theme.seriesColor

            // 折线 path
            let path = UIBezierPath()
            for (i, v) in element.data.enumerated() {
                let p = screenPoint(x: Double(i), y: v)
                i == 0 ? path.move(to: p) : path.addLine(to: p)
                let r = max(hitRadius, theme.pointRadius)   // 命中半径 ≥ 视觉点半径
                lastPointFrames.append((s, i,
                    CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)))
            }
            let line = CAShapeLayer()
            line.path = path.cgPath
            line.strokeColor = color.cgColor
            line.fillColor = nil
            line.lineWidth = theme.lineWidth
            line.lineJoin = .round
            line.lineCap = .round
            rootLayer.addSublayer(line)
            lineLayers.append(line)

            // 数据点
            if theme.showsPoints {
                for (i, v) in element.data.enumerated() {
                    let p = screenPoint(x: Double(i), y: v)
                    let dot = CALayer()
                    dot.frame = CGRect(x: p.x - theme.pointRadius, y: p.y - theme.pointRadius,
                                       width: theme.pointRadius * 2, height: theme.pointRadius * 2)
                    dot.cornerRadius = theme.pointRadius
                    dot.backgroundColor = (theme.pointColor ?? color).cgColor
                    dot.borderColor = UIColor.white.cgColor
                    dot.borderWidth = 1
                    rootLayer.addSublayer(dot)
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
    public func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard let t = target as? LineHitTarget,
              currentTheme?.showsTooltipOnHit == true,
              let hit = lastPointFrames.first(where: { $0.series == t.seriesIndex && $0.index == t.index })
        else { return nil }
        return HYMChartTooltipAnchor(frame: hit.frame, preferredPlacements: [.top, .bottom])
    }

    public func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
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
