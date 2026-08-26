import UIKit

/// 网格线组件：按刻度生成横/竖网格 CAShapeLayer（由 CartesianRendererBase 编排挂载）。
enum GridRenderer {

    /// 生成网格层。横线 = 每个 y 刻度一条；竖线 = 每个类目中心一条。
    /// - Parameters:
    ///   - yTicks: y 轴刻度值序列
    ///   - categoryCount: 类目数（竖线位置 = 各类目中心 x 值 0...n-1）
    static func makeGridLayer(yTicks: [Double],
                              categoryCount: Int,
                              viewport: CartesianViewport,
                              plotFrame: CGRect,
                              theme: CartesianChartTheme) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        // 注意：不设置 layer.frame——path 使用 view 绝对坐标，layer 默认（frame=.zero、
        // 挂到 rootLayer 原点）时两者坐标系一致；若设 frame=plotFrame 会双重偏移。
        if theme.showsHorizontalGridlines {
            for tick in yTicks {
                let y = CartesianGeometry.point(x: 0, y: tick,
                                                viewport: viewport, plotFrame: plotFrame).y
                path.move(to: CGPoint(x: plotFrame.minX, y: y))
                path.addLine(to: CGPoint(x: plotFrame.maxX, y: y))
            }
        }
        if theme.showsVerticalGridlines {
            for c in 0..<categoryCount {
                let x = CartesianGeometry.point(x: Double(c), y: 0,
                                                viewport: viewport, plotFrame: plotFrame).x
                path.move(to: CGPoint(x: x, y: plotFrame.minY))
                path.addLine(to: CGPoint(x: x, y: plotFrame.maxY))
            }
        }
        layer.path = path.cgPath
        layer.strokeColor = theme.gridColor.cgColor
        layer.fillColor = nil
        layer.lineWidth = theme.gridLineWidth
        return layer
    }
}
