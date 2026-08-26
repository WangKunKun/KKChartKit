import UIKit

/// 轴组件：轴线 + 刻度 label（由 CartesianRendererBase 编排挂载）。
enum AxisRenderer {

    /// 生成轴线层：plot 区左边线（y 轴）+ 底边线（x 轴）。
    static func makeAxisLinesLayer(plotFrame: CGRect,
                                   theme: CartesianChartTheme) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: plotFrame.minX, y: plotFrame.minY))
        path.addLine(to: CGPoint(x: plotFrame.minX, y: plotFrame.maxY))
        path.addLine(to: CGPoint(x: plotFrame.maxX, y: plotFrame.maxY))
        layer.path = path.cgPath
        layer.strokeColor = theme.axisLineColor.cgColor
        layer.fillColor = nil
        layer.lineWidth = theme.axisLineWidth
        return layer
    }

    /// 生成 y 轴刻度 labels（右侧对齐、贴 plot 左缘外侧）。
    /// 返回未加 superview 的 UILabel 数组，调用方负责挂载与清理。
    static func makeYTickLabels(ticks: [Double],
                                viewport: CartesianViewport,
                                plotFrame: CGRect,
                                theme: CartesianChartTheme) -> [UILabel] {
        ticks.map { tick in
            let lbl = UILabel()
            lbl.text = format(tick)
            lbl.textColor = theme.tickLabelColor
            lbl.font = theme.tickLabelFont
            lbl.sizeToFit()
            let y = CartesianGeometry.point(x: 0, y: tick,
                                            viewport: viewport, plotFrame: plotFrame).y
            lbl.center = CGPoint(x: plotFrame.minX - theme.axisLabelGap - lbl.bounds.width / 2,
                                 y: y)
            return lbl
        }
    }

    /// 生成 x 轴类目 labels（居中于类目中心、贴 plot 底缘外侧；超 10 个类目隔 N 显示）。
    static func makeCategoryLabels(labels: [String],
                                   viewport: CartesianViewport,
                                   plotFrame: CGRect,
                                   theme: CartesianChartTheme) -> [UILabel] {
        let stride = CartesianGeometry.categoryLabelStride(count: labels.count)
        var out: [UILabel] = []
        for (i, text) in labels.enumerated() where i % stride == 0 {
            let lbl = UILabel()
            lbl.text = text
            lbl.textColor = theme.tickLabelColor
            lbl.font = theme.tickLabelFont
            lbl.sizeToFit()
            let x = CartesianGeometry.point(x: Double(i), y: 0,
                                            viewport: viewport, plotFrame: plotFrame).x
            lbl.center = CGPoint(x: x,
                                 y: plotFrame.maxY + theme.axisLabelGap + lbl.bounds.height / 2)
            out.append(lbl)
        }
        return out
    }

    /// 刻度文本：去尾零（80.0 → "80"；0.2 → "0.2"；-0.0 → "0"）。
    /// ≥100 的非整数 %g 会产生科学计数法（123.456 → "1.2e+02"），退化为固定 1 位小数。
    static func format(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        let s = String(format: "%.2g", value)
        if s.contains("e") {
            return String(format: "%.1f", value)
        }
        return s
    }
}
