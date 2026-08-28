import UIKit

/// 网格线组件：按刻度生成横/竖网格 CAShapeLayer（由 CartesianRendererBase 编排挂载）。
enum GridRenderer {

    /// 竖线最小视觉间距（pt）：槽宽小于此值时按倍数抽稀（大数据量防叠成色带）。
    private static let minimumVerticalGridSpacing: CGFloat = 24

    /// 生成网格层。
    /// - 垂直图：横线 = 每个值刻度一条（Y 轴）；竖线 = 每个类目中心一条（X 轴）。
    /// - 水平图（条形图）：竖线 = 每个值刻度一条（X 轴）；横线 = 每个类目中心一条（Y 轴）。
    /// - Parameters:
    ///   - valueTicks: 值轴刻度值序列（垂直图沿 Y 映射；水平图沿 X 映射）
    ///   - categoryCount: 类目数（类目中心线位置 = 各类目中心值 0...n-1）
    ///   - isHorizontalValueAxis: 值轴是否水平（条形图为 true）
    static func makeGridLayer(valueTicks: [Double],
                              categoryCount: Int,
                              viewport: CartesianViewport,
                              plotFrame: CGRect,
                              theme: CartesianChartTheme,
                              isHorizontalValueAxis: Bool = false,
                              secondaryValueTicks: [Double] = [],
                              secondaryYDomain: ClosedRange<Double>? = nil) -> CAShapeLayer {
        if isHorizontalValueAxis {
            return makeHorizontalGridLayer(valueTicks: valueTicks, categoryCount: categoryCount,
                                           viewport: viewport, plotFrame: plotFrame, theme: theme)
        }
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        // 注意：不设置 layer.frame——path 使用 view 绝对坐标，layer 默认（frame=.zero、
        // 挂到 rootLayer 原点）时两者坐标系一致；若设 frame=plotFrame 会双重偏移。
        if theme.showsHorizontalGridlines {
            for tick in valueTicks {
                let y = CartesianGeometry.point(x: 0, y: tick,
                                                viewport: viewport, plotFrame: plotFrame).y
                path.move(to: CGPoint(x: plotFrame.minX, y: y))
                path.addLine(to: CGPoint(x: plotFrame.maxX, y: y))
            }
            // 次轴网格线（默认关；轴级 showsGridlines 开启时才传入 ticks）
            for tick in secondaryValueTicks {
                let y = CartesianGeometry.point(x: 0, y: tick, viewport: viewport,
                                                plotFrame: plotFrame,
                                                yDomain: secondaryYDomain).y
                path.move(to: CGPoint(x: plotFrame.minX, y: y))
                path.addLine(to: CGPoint(x: plotFrame.maxX, y: y))
            }
        }
        if theme.showsVerticalGridlines {
            // 视口驱动 + 密度抽稀：只为可见类目画竖线；槽宽小于最小视觉间距时
            // 隔 N 取 1（绝对索引取模，平移稳定），避免千条亚像素线叠成色带。
            let slotWidth = plotFrame.width / CGFloat(max(viewport.xSpan, 1e-9))
            let stride = max(1, Int(ceil(minimumVerticalGridSpacing / max(slotWidth, 1e-9))))
            for c in CartesianGeometry.visibleCategoryRange(viewport: viewport, count: categoryCount)
            where c % stride == 0 {
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

    /// 横线最小视觉间距（pt）：槽高小于此值时按倍数抽稀（水平图大数据量防叠成色带）。
    private static let minimumHorizontalGridSpacing: CGFloat = 24

    /// 水平图网格（条形图）：竖线 = 每个值刻度一条（X 轴，随 X 视口缩放平移）；
    /// 横线 = 每个类目中心一条（Y 轴不参与手势，恒全量；密度抽稀与垂直图竖线同策略）。
    private static func makeHorizontalGridLayer(valueTicks: [Double],
                                                categoryCount: Int,
                                                viewport: CartesianViewport,
                                                plotFrame: CGRect,
                                                theme: CartesianChartTheme) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        // 注意：不设置 layer.frame——path 使用 view 绝对坐标（与垂直分支同理）。
        if theme.showsVerticalGridlines {
            for tick in valueTicks {
                let x = CartesianGeometry.point(x: tick, y: 0,
                                                viewport: viewport, plotFrame: plotFrame).x
                path.move(to: CGPoint(x: x, y: plotFrame.minY))
                path.addLine(to: CGPoint(x: x, y: plotFrame.maxY))
            }
        }
        if theme.showsHorizontalGridlines {
            let slotHeight = plotFrame.height / CGFloat(max(viewport.ySpan, 1e-9))
            let stride = max(1, Int(ceil(minimumHorizontalGridSpacing / max(slotHeight, 1e-9))))
            for c in 0..<max(categoryCount, 0) where c % stride == 0 {
                // 类目 0 在顶部（与条形/左侧标签同一映射，见 horizontalCategoryY）
                let y = CartesianGeometry.horizontalCategoryY(category: Double(c),
                                                              viewport: viewport, plotFrame: plotFrame)
                path.move(to: CGPoint(x: plotFrame.minX, y: y))
                path.addLine(to: CGPoint(x: plotFrame.maxX, y: y))
            }
        }
        layer.path = path.cgPath
        layer.strokeColor = theme.gridColor.cgColor
        layer.fillColor = nil
        layer.lineWidth = theme.gridLineWidth
        return layer
    }
}
