import UIKit

/// 雷达图渲染器：实现 HYMChartRenderer，承载全部 layer 重建 / 标签 / 主题配色 / 数值动画。
/// 本期 hitTest 保持协议默认 nil（无交互命中），后续 override 增加命中目标。
public final class RadarChartRenderer: HYMChartRenderer {
    public typealias Model = RadarChartModel
    public typealias Theme = RadarChartTheme

    public init() {}

    // MARK: - 私有 layer 子树
    private let gradientLayer = CAGradientLayer()
    private let gridFillContainerLayer = CALayer()   // 网格每圈底色容器
    private let gridLayer = CAShapeLayer()
    private let axisLayer = CAShapeLayer()
    private let dataFillLayer = CAShapeLayer()
    private let dataStrokeLayer = CAShapeLayer()
    private let vertexDotsLayer = CAShapeLayer()

    // MARK: - 私有子视图
    private weak var hostView: UIView?
    private var labels: [UILabel] = []
    private let scoreLabel = UILabel()
    private let subtitleLabel = UILabel()

    // MARK: - 当前状态（render 时存，供动画/命中读取）
    private var currentModel: RadarChartModel?
    private var currentTheme: RadarChartTheme?
    private var lastCenter = CGPoint.zero

    // MARK: - mount / unmount
    public func mount(into view: UIView) {
        hostView = view

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.masksToBounds = true
        view.layer.addSublayer(gradientLayer)
        view.layer.addSublayer(gridFillContainerLayer)

        gridLayer.fillColor = UIColor.clear.cgColor
        axisLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(gridLayer)
        view.layer.addSublayer(axisLayer)

        dataFillLayer.fillColor = UIColor.clear.cgColor
        dataStrokeLayer.fillColor = UIColor.clear.cgColor
        vertexDotsLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(dataFillLayer)
        view.layer.addSublayer(dataStrokeLayer)
        view.layer.addSublayer(vertexDotsLayer)

        scoreLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center
        scoreLabel.numberOfLines = 1
        subtitleLabel.numberOfLines = 1
        view.addSubview(subtitleLabel)
        view.addSubview(scoreLabel)
    }

    public func unmount(from view: UIView) {
        labels.forEach { $0.removeFromSuperview() }
        labels.removeAll()
        [gradientLayer, gridFillContainerLayer, gridLayer, axisLayer,
         dataFillLayer, dataStrokeLayer, vertexDotsLayer].forEach { $0.removeFromSuperlayer() }
        scoreLabel.removeFromSuperview()
        subtitleLabel.removeFromSuperview()
        hostView = nil
    }

    // MARK: - 动画契约
    public var animatableLayers: [CALayer] {
        [dataFillLayer, dataStrokeLayer, vertexDotsLayer, gridLayer, axisLayer, gridFillContainerLayer]
    }

    public var centerScoreTarget: Double? {
        guard let m = currentModel else { return nil }
        return resolvedCenterScore(m)
    }

    public func updateEntranceAnimation(progress: Double) {
        guard let theme = currentTheme else { return }
        let target = centerScoreTarget ?? 0
        let value = target * progress
        scoreLabel.text = formatScore(value)
        scoreLabel.font = theme.scoreFont
        scoreLabel.textColor = theme.scoreColor
        scoreLabel.sizeToFit()
        scoreLabel.center = CGPoint(x: lastCenter.x, y: lastCenter.y + 18)
        scoreLabel.alpha = CGFloat(min(1, progress * 1.5))   // 前段淡入
    }

    // MARK: - render
    public func render(model: RadarChartModel, theme: RadarChartTheme, context: HYMChartRenderContext) {
        currentModel = model
        currentTheme = theme
        lastCenter = context.center

        applyThemeColors(theme)

        let pad = theme.labelOuterPadding
        gradientLayer.frame = context.bounds.insetBy(dx: pad, dy: pad)
        gradientLayer.cornerRadius = theme.cardCornerRadius

        guard !model.dimensions.isEmpty else {
            gridLayer.path = nil
            axisLayer.path = nil
            dataFillLayer.path = nil
            dataStrokeLayer.path = nil
            vertexDotsLayer.path = nil
            scoreLabel.isHidden = true
            subtitleLabel.isHidden = true
            return
        }

        let center = context.center
        let radius = maxRadius(bounds: context.bounds)

        rebuildGridFill(model, center: center, radius: radius)
        rebuildGrid(model, center: center, radius: radius)
        rebuildAxis(model, center: center, radius: radius)
        rebuildData(model, center: center, radius: radius)
        rebuildVertexDots(model, center: center, radius: radius)
        rebuildLabels(model, center: center, radius: radius)
        rebuildScore(model, center: center)

        // animatable layer 的 frame = bounds（identity transform 下），保证容器 scale 动画锚点居中
        for l in animatableLayers { l.frame = context.bounds }
    }

    // MARK: - 主题配色
    private func applyThemeColors(_ theme: RadarChartTheme) {
        gradientLayer.colors = [theme.backgroundGradientStart.cgColor,
                                theme.backgroundGradientEnd.cgColor]
        gridLayer.strokeColor = theme.gridColor.cgColor
        gridLayer.lineWidth = 1
        axisLayer.strokeColor = theme.axisColor.cgColor
        axisLayer.lineWidth = 1

        dataFillLayer.fillColor = theme.dataFillColor.cgColor
        dataFillLayer.strokeColor = UIColor.clear.cgColor
        dataStrokeLayer.fillColor = UIColor.clear.cgColor
        dataStrokeLayer.strokeColor = theme.dataStrokeColor.cgColor
        dataStrokeLayer.lineWidth = theme.dataLineWidth
        vertexDotsLayer.fillColor = theme.vertexDotColor.cgColor
        vertexDotsLayer.strokeColor = theme.vertexDotRingColor.cgColor
        vertexDotsLayer.lineWidth = 2

        // 显隐开关（彼此正交）
        gridLayer.isHidden = !theme.showsGridLines
        axisLayer.isHidden = !theme.showsAxes
        let dataHidden = !theme.showsData
        dataFillLayer.isHidden = dataHidden
        dataStrokeLayer.isHidden = dataHidden
        vertexDotsLayer.isHidden = dataHidden
        gradientLayer.isHidden = !theme.showsBackground
    }

    private func maxRadius(bounds: CGRect) -> CGFloat {
        guard let theme = currentTheme else { return 0 }
        let half = min(bounds.width, bounds.height) / 2
        let cardHalf = half - theme.labelOuterPadding
        let dotMargin = theme.vertexDotRadius + 2
        return max(0, cardHalf - dotMargin)
    }

    // MARK: - 网格描边
    private func rebuildGrid(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        guard let theme = currentTheme else { return }
        let ringCount = max(1, theme.gridRingCount)
        let path = UIBezierPath()
        for k in 0..<ringCount {
            let pts = RadarGeometry.ringPoints(count: n, center: center, radius: radius,
                                               ringIndex: k, ringCount: ringCount)
            guard let first = pts.first else { continue }
            path.move(to: first)
            for p in pts.dropFirst() { path.addLine(to: p) }
            path.close()
        }
        gridLayer.path = path.cgPath
    }

    // MARK: - 网格底色（每圈独立 fill）
    private func rebuildGridFill(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        gridFillContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let theme = currentTheme else { return }
        let ringCount = max(1, theme.gridRingCount)
        let fills = ringFillColors(ringCount: ringCount)
        guard !fills.isEmpty else { return }   // .none：不填充

        // 倒序：外圈(k 大)先(底)，内圈(k 小)后(顶)，内圈覆盖外圈中心
        for k in (0..<ringCount).reversed() {
            addRingFillLayer(model: model, center: center, radius: radius,
                             ringIndex: k, ringCount: ringCount, color: fills[k])
        }
    }

    private func ringFillColors(ringCount: Int) -> [UIColor] {
        guard let theme = currentTheme else { return [] }
        switch theme.gridRingFill {
        case .none:
            return []
        case .gradient(let from, let to):
            if ringCount == 1 { return [from] }
            return (0..<ringCount).map { k in
                // 外圈(k=ringCount-1)→t=0(from)；内圈(k=0)→t=1(to)
                let t = CGFloat(ringCount - 1 - k) / CGFloat(ringCount - 1)
                return HYMColorInterpolation.lerp(from, to, t)
            }
        case .colors(let cols):
            return (0..<ringCount).map { k in
                k < cols.count ? cols[k] : (cols.last ?? .clear)
            }
        }
    }

    private func addRingFillLayer(model: RadarChartModel, center: CGPoint, radius: CGFloat,
                                  ringIndex k: Int, ringCount: Int, color: UIColor) {
        let n = model.dimensions.count
        let pts = RadarGeometry.ringPoints(count: n, center: center, radius: radius,
                                           ringIndex: k, ringCount: ringCount)
        guard let first = pts.first else { return }
        let path = UIBezierPath()
        path.move(to: first)
        for p in pts.dropFirst() { path.addLine(to: p) }
        path.close()

        let ringLayer = CAShapeLayer()
        ringLayer.path = path.cgPath
        ringLayer.fillColor = color.cgColor
        ringLayer.strokeColor = UIColor.clear.cgColor
        gridFillContainerLayer.addSublayer(ringLayer)
    }

    // MARK: - 放射轴
    private func rebuildAxis(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        let path = UIBezierPath()
        for i in 0..<n {
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: 1)
            path.move(to: center)
            path.addLine(to: p)
        }
        axisLayer.path = path.cgPath
    }

    // MARK: - 数据多边形
    private func rebuildData(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        let n = model.dimensions.count
        let path = UIBezierPath()
        for i in 0..<n {
            let ratio = model.dimensions[i].normalized
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: ratio)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.close()
        dataFillLayer.path = path.cgPath
        dataStrokeLayer.path = path.cgPath
    }

    // MARK: - 顶点圆点
    private func rebuildVertexDots(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        guard let theme = currentTheme else { return }
        let n = model.dimensions.count
        let dotRadius = theme.vertexDotRadius
        let path = UIBezierPath()
        for i in 0..<n {
            let ratio = model.dimensions[i].normalized
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: ratio)
            path.append(UIBezierPath(arcCenter: p, radius: dotRadius,
                                     startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true))
        }
        vertexDotsLayer.path = path.cgPath
    }

    // MARK: - 文案标签（顶点外侧）
    private func rebuildLabels(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        guard let view = hostView, let theme = currentTheme else { return }
        labels.forEach { $0.removeFromSuperview() }
        labels.removeAll()

        let n = model.dimensions.count
        let gap = theme.labelOuterPadding
        for i in 0..<n {
            let a = RadarGeometry.angle(index: i, count: n)
            let r = radius + gap
            let labelCenter = CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))

            let lbl = UILabel()
            lbl.text = model.dimensions[i].label
            lbl.textColor = theme.labelColor
            lbl.font = theme.labelFont
            lbl.textAlignment = .center
            lbl.sizeToFit()
            lbl.center = labelCenter
            view.addSubview(lbl)
            labels.append(lbl)
        }
    }

    // MARK: - 中心分数（双模式）
    private func rebuildScore(_ model: RadarChartModel, center: CGPoint) {
        guard let theme = currentTheme else { return }
        let resolved = resolvedCenterScore(model)
        if let value = resolved {
            scoreLabel.isHidden = false
            subtitleLabel.isHidden = false
            scoreLabel.text = formatScore(value)
            scoreLabel.font = theme.scoreFont
            scoreLabel.textColor = theme.scoreColor
            scoreLabel.sizeToFit()

            subtitleLabel.text = theme.scoreSubtitleText
            subtitleLabel.font = theme.scoreSubtitleFont
            subtitleLabel.textColor = theme.scoreSubtitleColor
            subtitleLabel.sizeToFit()

            subtitleLabel.center = CGPoint(x: center.x, y: center.y - 10)
            scoreLabel.center = CGPoint(x: center.x, y: center.y + 18)
        } else {
            scoreLabel.isHidden = true
            subtitleLabel.isHidden = true
        }
    }

    private func formatScore(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10   // 保留 1 位小数
        return rounded.rounded() == rounded ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }
}
