import UIKit

/// 轴组件：轴线 + 刻度 label（由 CartesianRendererBase 编排挂载）。
enum AxisRenderer {

    /// 生成轴线层：plot 区左边线（y 轴）+ 底边线（x 轴）。
    static func makeAxisLinesLayer(plotFrame: CGRect,
                                   theme: CartesianChartTheme,
                                   showsRightAxis: Bool = false) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: plotFrame.minX, y: plotFrame.minY))
        path.addLine(to: CGPoint(x: plotFrame.minX, y: plotFrame.maxY))
        path.addLine(to: CGPoint(x: plotFrame.maxX, y: plotFrame.maxY))
        if showsRightAxis {
            // 双值轴：补画右缘竖线
            path.move(to: CGPoint(x: plotFrame.maxX, y: plotFrame.minY))
            path.addLine(to: CGPoint(x: plotFrame.maxX, y: plotFrame.maxY))
        }
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
                                theme: CartesianChartTheme,
                                formatter: ((Double) -> String)? = nil) -> [UILabel] {
        ticks.map { tick in
            let lbl = UILabel()
            lbl.text = tickText(tick, formatter: formatter)
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

    /// 生成 x 轴类目 labels（居中于类目中心、贴 plot 底缘外侧）。
    ///
    /// 视口驱动：只为**可见类目**生成标签；每个标签正对所属类目中心
    /// （即柱子组中心，缩放后跟随视口重排）；抽稀步长按**标签实测宽度**自适应
    /// （短标签全显示，放不下才隔 N 取 1，用绝对索引取模保证平移不闪跳）。
    /// 标签的 y 位置恒定（Y 轴不参与手势）。
    static func makeCategoryLabels(labels: [String],
                                   viewport: CartesianViewport,
                                   plotFrame: CGRect,
                                   theme: CartesianChartTheme) -> [UILabel] {
        let visible = CartesianGeometry.visibleCategoryRange(viewport: viewport, count: labels.count)
        guard !visible.isEmpty else { return [] }

        // 最宽标签 + 槽宽 → 自适应步长（12 个短数字标签可全显示）
        let fontAttrs: [NSAttributedString.Key: Any] = [.font: theme.tickLabelFont]
        let maxLabelWidth = visible.map { (labels[$0] as NSString).size(withAttributes: fontAttrs).width }.max() ?? 0
        let slotWidth = plotFrame.width / CGFloat(max(viewport.xSpan, 1e-9))
        let stride = CartesianGeometry.categoryLabelStride(labelWidth: maxLabelWidth,
                                                           slotWidth: slotWidth)

        var out: [UILabel] = []
        for i in visible where i % stride == 0 {
            let lbl = UILabel()
            lbl.text = labels[i]
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

    /// 生成右侧数值刻度 labels（双值轴的次轴）：左对齐贴 plot 右缘外侧。
    /// y 位置按次轴独立值域（`secondaryDomain`）映射。
    static func makeRightValueTickLabels(ticks: [Double],
                                         viewport: CartesianViewport,
                                         plotFrame: CGRect,
                                         theme: CartesianChartTheme,
                                         formatter: ((Double) -> String)? = nil,
                                         secondaryDomain: ClosedRange<Double>? = nil) -> [UILabel] {
        ticks.map { tick in
            let lbl = UILabel()
            lbl.text = tickText(tick, formatter: formatter)
            lbl.textColor = theme.tickLabelColor
            lbl.font = theme.tickLabelFont
            lbl.sizeToFit()
            let y = CartesianGeometry.point(x: 0, y: tick,
                                            viewport: viewport, plotFrame: plotFrame,
                                            yDomain: secondaryDomain).y
            lbl.center = CGPoint(x: plotFrame.maxX + theme.axisLabelGap + lbl.bounds.width / 2,
                                 y: y)
            return lbl
        }
    }

    /// 生成底部数值刻度 labels（水平图：值轴在 X）。
    ///
    /// 每个刻度水平居中于其值沿 X 轴的映射位置，贴 plot 底缘外侧；
    /// 值刻度数量由 nice scale 控制（约 ≤6 个），无需抽稀。
    /// 返回未加 superview 的 UILabel 数组，调用方负责挂载与清理。
    static func makeBottomValueTickLabels(ticks: [Double],
                                           viewport: CartesianViewport,
                                           plotFrame: CGRect,
                                           theme: CartesianChartTheme,
                                           formatter: ((Double) -> String)? = nil) -> [UILabel] {
        ticks.map { tick in
            let lbl = UILabel()
            lbl.text = tickText(tick, formatter: formatter)
            lbl.textColor = theme.tickLabelColor
            lbl.font = theme.tickLabelFont
            lbl.sizeToFit()
            let x = CartesianGeometry.point(x: tick, y: 0,
                                            viewport: viewport, plotFrame: plotFrame).x
            lbl.center = CGPoint(x: x,
                                 y: plotFrame.maxY + theme.axisLabelGap + lbl.bounds.height / 2)
            return lbl
        }
    }

    /// 生成左侧类目标签（水平图：类目轴在 Y）。
    ///
    /// 与底部类目标签同一策略：每个标签垂直居中于所属类目中心
    /// （类目 i 沿 Y 映射，类目 0 在顶部），右对齐贴 plot 左缘外侧；
    /// 槽高不足时按标签实测高度自适应抽稀（绝对索引取模保证稳定——
    /// 水平图 Y 轴不参与手势，抽稀只在类目极多时生效，如 1440 条）。
    /// 返回未加 superview 的 UILabel 数组，调用方负责挂载与清理。
    static func makeLeftCategoryLabels(labels: [String],
                                        viewport: CartesianViewport,
                                        plotFrame: CGRect,
                                        theme: CartesianChartTheme) -> [UILabel] {
        guard !labels.isEmpty else { return [] }
        let fontAttrs: [NSAttributedString.Key: Any] = [.font: theme.tickLabelFont]
        let maxLabelHeight = labels.map { ($0 as NSString).size(withAttributes: fontAttrs).height }.max() ?? 0
        // 槽高按类目轴跨度（Y）计算；categoryLabelStride 的数学对高度维度同样适用
        let slotHeight = plotFrame.height / CGFloat(max(viewport.ySpan, 1e-9))
        let stride = CartesianGeometry.categoryLabelStride(labelWidth: maxLabelHeight,
                                                           slotWidth: slotHeight)

        var out: [UILabel] = []
        for (i, text) in labels.enumerated() where i % stride == 0 {
            let lbl = UILabel()
            lbl.text = text
            lbl.textColor = theme.tickLabelColor
            lbl.font = theme.tickLabelFont
            lbl.sizeToFit()
            // 类目 0 在顶部（与 barRect 同一映射，见 horizontalCategoryY）
            let y = CartesianGeometry.horizontalCategoryY(category: Double(i),
                                                          viewport: viewport, plotFrame: plotFrame)
            lbl.center = CGPoint(x: plotFrame.minX - theme.axisLabelGap - lbl.bounds.width / 2,
                                 y: y)
            out.append(lbl)
        }
        return out
    }

    /// 刻度文本：formatter 优先，否则内置去尾零格式。
    static func tickText(_ tick: Double, formatter: ((Double) -> String)?) -> String {
        formatter?(tick) ?? format(tick)
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
