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
    private let vertexDotsContainerLayer = CALayer()  // 数据点容器（每点一个子 layer，支持 per-dim 颜色）
    private let labelDotsContainerLayer = CALayer()   // 标题顶点圆点容器（每点子 layer，支持 per-dim 颜色）
    private let outerRingLayer = CAShapeLayer()     // 最外圈边框（连接标题顶点）
    private let decorativeRingLayer = CAShapeLayer()  // 装饰 ring（最外圈外，用 HYMRingRenderer）

    // MARK: - 私有子视图
    private weak var hostView: UIView?
    private var labels: [UILabel] = []
    private let scoreLabel = UILabel()

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
        view.layer.addSublayer(decorativeRingLayer)   // 装饰 ring：背景渐变之上、网格之下
        view.layer.addSublayer(gridFillContainerLayer)

        gridLayer.fillColor = UIColor.clear.cgColor
        outerRingLayer.fillColor = UIColor.clear.cgColor
        axisLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(gridLayer)
        view.layer.addSublayer(outerRingLayer)   // 最外圈：内圈网格之上、放射轴之下
        view.layer.addSublayer(axisLayer)

        dataFillLayer.fillColor = UIColor.clear.cgColor
        dataStrokeLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(dataFillLayer)
        view.layer.addSublayer(dataStrokeLayer)
        view.layer.addSublayer(vertexDotsContainerLayer)
        view.layer.addSublayer(labelDotsContainerLayer)   // 标题顶点圆点：数据点之上

        scoreLabel.textAlignment = .center
        scoreLabel.numberOfLines = 1
        view.addSubview(scoreLabel)
    }

    public func unmount(from view: UIView) {
        labels.forEach { $0.removeFromSuperview() }
        labels.removeAll()
        [gradientLayer, decorativeRingLayer, gridFillContainerLayer, gridLayer, outerRingLayer, axisLayer,
         dataFillLayer, dataStrokeLayer, vertexDotsContainerLayer, labelDotsContainerLayer].forEach { $0.removeFromSuperlayer() }
        scoreLabel.removeFromSuperview()
        hostView = nil
    }

    // MARK: - 动画契约
    public var animatableLayers: [CALayer] {
        [decorativeRingLayer, dataFillLayer, dataStrokeLayer, vertexDotsContainerLayer, labelDotsContainerLayer,
         gridLayer, outerRingLayer, axisLayer, gridFillContainerLayer]
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
        scoreLabel.center = lastCenter   // 无副标题，分数居中
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
            outerRingLayer.path = nil
            axisLayer.path = nil
            dataFillLayer.path = nil
            dataStrokeLayer.path = nil
            vertexDotsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            labelDotsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            decorativeRingLayer.path = nil
            scoreLabel.isHidden = true
            return
        }

        let center = context.center
        let radius = maxRadius(bounds: context.bounds)

        rebuildDecorativeRing(model, center: center, radius: radius, bounds: context.bounds)
        rebuildGridFill(model, center: center, radius: radius)
        rebuildGrid(model, center: center, radius: radius)
        rebuildAxis(model, center: center, radius: radius)
        rebuildData(model, center: center, radius: radius)
        rebuildVertexDots(model, center: center, radius: radius)
        rebuildLabelDots(model, center: center, radius: radius)
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
        gridLayer.lineDashPattern = theme.gridLineStyle.dashPattern
        axisLayer.strokeColor = theme.axisColor.cgColor
        axisLayer.lineWidth = 1
        axisLayer.lineDashPattern = theme.axisLineStyle.dashPattern

        // 最外圈边框（独立于内圈网格 showsGridLines）
        outerRingLayer.strokeColor = theme.outerRingColor.cgColor
        outerRingLayer.lineWidth = theme.outerRingLineWidth
        outerRingLayer.lineDashPattern = theme.outerRingLineStyle.dashPattern

        dataFillLayer.fillColor = theme.dataFillColor.cgColor
        dataFillLayer.strokeColor = UIColor.clear.cgColor
        dataStrokeLayer.fillColor = UIColor.clear.cgColor
        dataStrokeLayer.strokeColor = theme.dataStrokeColor.cgColor
        dataStrokeLayer.lineWidth = theme.dataLineWidth
        // 数据点/标题顶点颜色在 rebuild* 按每点设置（支持 per-dim）
        // 装饰 ring
        decorativeRingLayer.strokeColor = theme.decorativeRingColor.cgColor
        decorativeRingLayer.lineWidth = theme.decorativeRingLineWidth
        decorativeRingLayer.lineDashPattern = theme.decorativeRingLineStyle.dashPattern
        decorativeRingLayer.fillColor = (theme.decorativeRingFillColor ?? UIColor.clear).cgColor

        // 显隐开关（彼此正交）
        gridLayer.isHidden = !theme.showsGridLines
        outerRingLayer.isHidden = !theme.showsOuterRing
        axisLayer.isHidden = !theme.showsAxes
        let dataHidden = !theme.showsData
        dataFillLayer.isHidden = dataHidden
        dataStrokeLayer.isHidden = dataHidden
        vertexDotsContainerLayer.isHidden = !theme.showsVertexDots   // 数据点独立显隐
        labelDotsContainerLayer.isHidden = !theme.showsLabelDots
        decorativeRingLayer.isHidden = !theme.showsDecorativeRing
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
        let innerPath = UIBezierPath()    // 内圈（k < ringCount-1）→ gridLayer
        let outerPath = UIBezierPath()    // 最外圈（k == ringCount-1）→ outerRingLayer
        for k in 0..<ringCount {
            let pts = RadarGeometry.ringPoints(count: n, center: center, radius: radius,
                                               ringIndex: k, ringCount: ringCount)
            guard let first = pts.first else { continue }
            let path = (k == ringCount - 1) ? outerPath : innerPath
            path.move(to: first)
            for p in pts.dropFirst() { path.addLine(to: p) }
            path.close()
        }
        gridLayer.path = innerPath.cgPath
        outerRingLayer.path = outerPath.cgPath
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

    // MARK: - 顶点圆点（每点一个子 layer，支持 per-dim 颜色）
    private func rebuildVertexDots(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        guard let theme = currentTheme else { return }
        vertexDotsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let n = model.dimensions.count
        let dotRadius = theme.vertexDotRadius
        for i in 0..<n {
            let dim = model.dimensions[i]
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: dim.normalized)
            let dot = CAShapeLayer()
            dot.path = UIBezierPath(arcCenter: p, radius: dotRadius,
                                    startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true).cgPath
            dot.fillColor = (dim.dataDotColor ?? theme.vertexDotColor).cgColor
            dot.strokeColor = theme.vertexDotRingColor.cgColor
            dot.lineWidth = 2
            vertexDotsContainerLayer.addSublayer(dot)
        }
    }

    // MARK: - 标题顶点圆点（最外圈顶点；每点子 layer，支持 per-dim 颜色）
    private func rebuildLabelDots(_ model: RadarChartModel, center: CGPoint, radius: CGFloat) {
        guard let theme = currentTheme else { return }
        labelDotsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let n = model.dimensions.count
        let dotRadius = theme.labelDotRadius
        for i in 0..<n {
            let dim = model.dimensions[i]
            let p = RadarGeometry.point(index: i, count: n, center: center, radius: radius, ratio: 1)
            let dot = CAShapeLayer()
            dot.path = UIBezierPath(arcCenter: p, radius: dotRadius,
                                    startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true).cgPath
            dot.fillColor = (dim.labelDotColor ?? theme.labelDotColor).cgColor
            dot.strokeColor = UIColor.clear.cgColor
            labelDotsContainerLayer.addSublayer(dot)
        }
    }

    // MARK: - 装饰 ring（最外圈外，用 HYMRingRenderer 绘制）
    // 半径优先 = radius + labelOuterPadding（与标签圈一致，可与文字重叠）+ inset 微调；
    // 若超出 view 边界则裁剪到边界。
    private func rebuildDecorativeRing(_ model: RadarChartModel, center: CGPoint, radius: CGFloat, bounds: CGRect) {
        guard let theme = currentTheme else { return }
        let sides = (theme.decorativeRingSides == -1) ? model.dimensions.count : theme.decorativeRingSides
        let viewHalf = min(bounds.width, bounds.height) / 2
        let desired = radius + theme.labelOuterPadding + theme.decorativeRingInset
        let decorativeRadius = max(0, min(desired, viewHalf - 0.5))
        decorativeRingLayer.path = HYMRingRenderer.ringPath(
            center: center,
            radius: decorativeRadius,
            sides: sides,
            startAngle: -CGFloat.pi / 2)
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

            let dim = model.dimensions[i]
            let lbl = UILabel()
            lbl.text = dim.label
            lbl.textColor = dim.labelColor ?? theme.labelColor
            lbl.font = dim.labelFont ?? theme.labelFont
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
            scoreLabel.text = formatScore(value)
            scoreLabel.font = theme.scoreFont
            scoreLabel.textColor = theme.scoreColor
            scoreLabel.sizeToFit()
            scoreLabel.center = center   // 无副标题，分数居中
        } else {
            scoreLabel.isHidden = true
        }
    }

    private func formatScore(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10   // 保留 1 位小数
        return rounded.rounded() == rounded ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }
}
