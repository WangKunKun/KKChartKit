import UIKit

/// 仅负责给既有完整路径上色。所有分区共享同一路径/渐变坐标，保留曲率、虚线相位、动画进度。
/// 裁剪容器与子层均由 renderer 的池管理；不参与数据、采样、值域或命中计算。
enum LineChartColorLayers {
    static func line(path: CGPath, color: UIColor, theme: CartesianChartTheme,
                     dash: LineDashStyle, clip: CGRect?, parent: CALayer,
                     pool: CartesianRenderObjectPool) -> CAShapeLayer {
        let line = pool.shape()
        line.path = path; line.strokeColor = color.cgColor; line.fillColor = nil
        line.lineWidth = theme.lineWidth; line.lineJoin = .round; line.lineCap = .round
        line.lineDashPattern = dash.dashPattern
        attach(line, clip: clip, parent: parent, pool: pool)
        return line
    }

    static func area(path: CGPath, color: UIColor, colors: [UIColor]?, opacity: CGFloat,
                     plot: CGRect, clip: CGRect?, parent: CALayer, pool: CartesianRenderObjectPool) {
        let gradient = pool.gradient()
        gradient.frame = plot; gradient.bounds.origin = plot.origin
        var colors = colors.flatMap { $0.isEmpty ? nil : $0 }
            ?? [color.withAlphaComponent(0.35), color.withAlphaComponent(0.04)]
        if colors.count == 1 { colors.append(colors[0]) }
        gradient.colors = colors.map { $0.withAlphaComponent($0.cgColor.alpha * opacity).cgColor }
        gradient.startPoint = CGPoint(x: 0.5, y: 0); gradient.endPoint = CGPoint(x: 0.5, y: 1)
        let mask = pool.shape()
        mask.path = path; mask.fillColor = UIColor.black.cgColor; mask.strokeColor = nil
        gradient.mask = mask
        attach(gradient, clip: clip, parent: parent, pool: pool)
    }

    private static func attach(_ layer: CALayer, clip: CGRect?, parent: CALayer,
                               pool: CartesianRenderObjectPool) {
        guard let clip else { parent.addSublayer(layer); return }
        let container = pool.layer()
        container.frame = clip; container.bounds.origin = clip.origin
        container.masksToBounds = true
        container.addSublayer(layer); parent.addSublayer(container)
    }
}
