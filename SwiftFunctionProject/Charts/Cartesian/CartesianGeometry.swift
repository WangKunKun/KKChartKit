import CoreGraphics
import UIKit

/// 轴系图表几何纯函数（plot 布局、值↔屏幕映射；DEBUG 自检覆盖）。
public enum CartesianGeometry {

    /// 计算 plot 区（网格 + series 绘制区）frame。
    ///
    /// 布局模型：内容 inset → 顶部让出标题 → 左侧让出 y 刻度 label → 底部让出 x 刻度 label。
    /// `yAxisTickLabelWidth` / `xAxisTickLabelHeight` 由调用方按最宽/最高刻度文本量好传入。
    public static func layout(bounds: CGRect,
                              contentInset: UIEdgeInsets,
                              yAxisTickLabelWidth: CGFloat,
                              xAxisTickLabelHeight: CGFloat,
                              axisLabelGap: CGFloat,
                              titleHeight: CGFloat) -> CGRect {
        let x = bounds.minX + contentInset.left + yAxisTickLabelWidth + axisLabelGap
        let y = bounds.minY + contentInset.top + titleHeight + axisLabelGap
        let w = max(0, bounds.width - contentInset.left - contentInset.right
                        - yAxisTickLabelWidth - axisLabelGap)
        let h = max(0, bounds.height - contentInset.top - contentInset.bottom
                        - titleHeight - axisLabelGap - xAxisTickLabelHeight - axisLabelGap)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// 值 → 屏幕（view 坐标系）。x/y 均为线性映射；y 轴屏幕向下，故值越大 y 越小。
    /// 类目模式下数据点 x 取索引值（域 -0.5...n-0.5 时点落在 band 中心）。
    public static func point(x: Double, y: Double,
                             viewport: CartesianViewport,
                             plotFrame: CGRect) -> CGPoint {
        let tx = (x - viewport.xMin) / max(viewport.xSpan, 1e-9)
        let ty = (y - viewport.yMin) / max(viewport.ySpan, 1e-9)
        return CGPoint(x: plotFrame.minX + tx * plotFrame.width,
                       y: plotFrame.maxY - ty * plotFrame.height)
    }

    /// 屏幕 → 值（`point` 的逆映射）。
    public static func value(at point: CGPoint,
                             viewport: CartesianViewport,
                             plotFrame: CGRect) -> (x: Double, y: Double) {
        let tx = (point.x - plotFrame.minX) / max(plotFrame.width, 1e-9)
        let ty = (plotFrame.maxY - point.y) / max(plotFrame.height, 1e-9)
        return (viewport.xMin + tx * viewport.xSpan,
                viewport.yMin + ty * viewport.ySpan)
    }

    /// 类目 label 抽稀步长（按标签实测宽度自适应）。
    ///
    /// 语义：每个显示的标签须**正对所属类目中心**（与柱子组中心对齐），
    /// 因此相邻显示标签的间距 = stride × 槽宽，须容纳最宽标签 + 最小间隙。
    /// 短标签（如 "1"…"12"）即使类目很多也全显示；长标签（如 "12月"）才抽稀。
    /// - Parameters:
    ///   - labelWidth: 可见类目中最宽标签的实测宽度（pt）
    ///   - slotWidth: 单类目槽宽（plot 宽 / 可见类目数，pt）
    ///   - minGap: 相邻标签最小间隙（默认 4pt）
    public static func categoryLabelStride(labelWidth: CGFloat,
                                           slotWidth: CGFloat,
                                           minGap: CGFloat = 4) -> Int {
        guard slotWidth > 0, labelWidth + minGap > slotWidth else { return 1 }
        return Int(ceil((labelWidth + minGap) / slotWidth))
    }

    // MARK: - X 轴视口手势数学（纯函数，DEBUG 自检覆盖）

    /// 以锚点值为中心缩放 X 视口窗口（`factor` > 1 放大），并 clamp 到全量域。
    ///
    /// 锚点语义：`anchorValue` 处的内容在新旧窗口中的屏幕位置不变（捏合中心跟手）。
    /// - Parameters:
    ///   - range: 缩放前的窗口
    ///   - factor: 倍率（span / factor）
    ///   - anchorValue: 锚点值域值（建议 clamp 到窗口内，边界锚点退化为端点缩放）
    ///   - fullDomain: 全量域（窗口不得越出）
    ///   - minSpan: 最小可视跨度（放大下限，调用方按"最小可见类目数"与最大倍数折算）
    ///   - maxSpan: 最大可视跨度（缩小上限，通常 = 全量跨度）
    public static func zoomedXRange(from range: ClosedRange<Double>,
                                    factor: CGFloat,
                                    anchorValue: Double,
                                    fullDomain: ClosedRange<Double>,
                                    minSpan: Double,
                                    maxSpan: Double) -> ClosedRange<Double> {
        let fullSpan = fullDomain.upperBound - fullDomain.lowerBound
        guard fullSpan > 0, factor > 0 else { return fullDomain }

        var span = (range.upperBound - range.lowerBound) / Double(factor)
        span = min(max(span, minSpan), maxSpan)

        // 围绕锚点构建新窗口：锚点两侧的占比保持不变
        let anchor = min(max(anchorValue, range.lowerBound), range.upperBound)
        let leadingRatio = (anchor - range.lowerBound)
            / max(range.upperBound - range.lowerBound, 1e-9)
        var lo = anchor - leadingRatio * span
        var hi = lo + span

        // clamp 到全量域（先贴下界再贴上界，保持 span 不变）
        if lo < fullDomain.lowerBound {
            lo = fullDomain.lowerBound
            hi = lo + span
        }
        if hi > fullDomain.upperBound {
            hi = fullDomain.upperBound
            lo = hi - span
        }
        return lo...hi
    }

    /// 平移 X 视口窗口（屏幕像素 → 值域偏移），并 clamp 到全量域。
    ///
    /// - Parameters:
    ///   - range: 平移前的窗口
    ///   - screenDeltaX: 屏幕位移（px，右滑为正 → 内容右移 → 窗口左移看更早数据）
    ///   - plotWidth: plot 区宽度（像素↔值域换算基准）
    ///   - fullDomain: 全量域
    public static func pannedXRange(from range: ClosedRange<Double>,
                                    screenDeltaX: CGFloat,
                                    plotWidth: CGFloat,
                                    fullDomain: ClosedRange<Double>) -> ClosedRange<Double> {
        let span = range.upperBound - range.lowerBound
        guard span > 0, plotWidth > 0 else { return fullDomain }
        let offset = Double(screenDeltaX) / Double(plotWidth) * span
        var lo = range.lowerBound - offset
        var hi = range.upperBound - offset
        if lo < fullDomain.lowerBound {
            lo = fullDomain.lowerBound
            hi = lo + span
        }
        if hi > fullDomain.upperBound {
            hi = fullDomain.upperBound
            lo = hi - span
        }
        return lo...hi
    }

    /// 可见类目索引范围（部分可见即计入；类目 i 的 band 为 i-0.5 ... i+0.5）。
    ///
    /// 未缩放（视口 = 全量类目域）时返回 `0..<count`；
    /// 放大后返回与视口相交的类目区间，供渲染层跳过视口外柱体的 layer 创建。
    public static func visibleCategoryRange(viewport: CartesianViewport,
                                            count: Int) -> Range<Int> {
        guard count > 0 else { return 0..<0 }
        // 类目 i 的 band 为 [i-0.5, i+0.5)，与视口相交 ⇔ i > xMin-0.5 && i < xMax+0.5
        let lo = max(0, Int((viewport.xMin - 0.5).rounded(.up)))
        let hi = min(count - 1, Int((viewport.xMax + 0.5).rounded(.down)))
        guard lo <= hi else { return 0..<0 }
        return lo..<(hi + 1)
    }

    /// 折线连接点序列：数据点 → 绘制用路径点（straight/smooth 原样返回；
    /// 阶梯形态插入水平/垂直过渡点）。
    ///
    /// 纯屏幕坐标变换，与视口无关；命中测试仍按原始数据点（连接形态是绘制细节）。
    /// `.smooth` 的曲线由 `appendSmoothCurve(to:points:)` 在 path 层面处理。
    /// - Parameters:
    ///   - points: 数据点屏幕坐标（按 x 升序）
    ///   - style: 连接形态
    public static func steppedScreenPoints(_ points: [CGPoint],
                                           style: LineConnectionStyle) -> [CGPoint] {
        guard points.count > 1 else { return points }
        switch style {
        case .straight, .smooth:
            return points
        case .stepAfter:
            // 保持前值水平前进，到下一 x 再垂直跳变：(x[i-1],y[i-1]) → (x[i],y[i-1]) → (x[i],y[i])
            var out = [points[0]]
            for i in 1..<points.count {
                out.append(CGPoint(x: points[i].x, y: points[i - 1].y))
                out.append(points[i])
            }
            return out
        case .stepBefore:
            // 先垂直跳到新值，再水平前进：(x[i-1],y[i-1]) → (x[i-1],y[i]) → (x[i],y[i])
            var out = [points[0]]
            for i in 1..<points.count {
                out.append(CGPoint(x: points[i - 1].x, y: points[i].y))
                out.append(points[i])
            }
            return out
        case .stepCenter:
            // 垂直段在两点水平中点：(x[i-1],y[i-1]) → (mid,y[i-1]) → (mid,y[i]) → (x[i],y[i])
            var out = [points[0]]
            for i in 1..<points.count {
                let midX = (points[i - 1].x + points[i].x) / 2
                out.append(CGPoint(x: midX, y: points[i - 1].y))
                out.append(CGPoint(x: midX, y: points[i].y))
                out.append(points[i])
            }
            return out
        }
    }

    /// 把点序列以 Catmull-Rom 平滑曲线加入 path（`LineConnectionStyle.smooth` 用）。
    ///
    /// 调用方须已 `move(to: points[0])`；每段转三次贝塞尔，
    /// 控制点按标准 Catmull-Rom（张力因子 1/6）——过数据点、曲率连续、无过冲震荡。
    /// 点数 ≤ 2 时退化为直线。
    public static func appendSmoothCurve(to path: UIBezierPath, points: [CGPoint]) {
        guard points.count > 2 else {
            for p in points.dropFirst() { path.addLine(to: p) }
            return
        }
        for i in 0..<points.count - 1 {
            let p0 = i == 0 ? points[0] : points[i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, controlPoint1: cp1, controlPoint2: cp2)
        }
    }

    /// 零轴位置（坐标轴的 0 点在 plot 区域中的位置）
    /// - Parameters:
    ///   - viewport: 值域视口
    ///   - plotArea: plot 区域
    ///   - isHorizontal: 是否水平图表（Bar 图的 Y 轴对应数值轴）
    /// - Returns: 零轴在 plotArea 中的坐标（垂直图返回 Y，水平图返回 X）
    public static func zeroAxisPosition(
        viewport: CartesianViewport,
        plotArea: CGRect,
        isHorizontal: Bool = false
    ) -> CGFloat {
        if isHorizontal {
            // 水平图（Bar）：返回 X 坐标
            if viewport.xMin >= 0 {
                // 全正值域，零轴在左侧
                return plotArea.minX
            } else if viewport.xMax <= 0 {
                // 全负值域，零轴在右侧
                return plotArea.maxX
            } else {
                // 混合值域，零轴在内部（插值计算）
                let ratio = -viewport.xMin / (viewport.xMax - viewport.xMin)
                return plotArea.minX + plotArea.width * ratio
            }
        } else {
            // 垂直图（Column）：返回 Y 坐标
            if viewport.yMin >= 0 {
                // 全正值域，零轴在底部
                return plotArea.maxY
            } else if viewport.yMax <= 0 {
                // 全负值域，零轴在顶部
                return plotArea.minY
            } else {
                // 混合值域，零轴在内部（插值计算）
                let ratio = -viewport.yMin / (viewport.yMax - viewport.yMin)
                return plotArea.maxY - plotArea.height * ratio
            }
        }
    }

    /// 堆叠累计值（归一化为所有 series 同长度）
    /// - Parameter series: 原始 series 数组（可能长度不一）
    /// - Returns: 累计值数组，stack[i][j] = sum(series[0...i][j])
    /// - 锯齿 series：短 series 空位补 0，长度对齐到最长 series
    public static func stackedValues(series: [CartesianSeriesElement]) -> [[Double]] {
        guard !series.isEmpty else { return [] }

        // 1. 找到最长 series 的长度
        let maxLength = series.map { $0.data.count }.max() ?? 0
        guard maxLength > 0 else { return [] }

        // 2. 归一化所有 series 到相同长度（短 series 补 0）
        var normalizedData: [[Double]] = []
        for oneSeries in series {
            var padded = oneSeries.data
            while padded.count < maxLength {
                padded.append(0)
            }
            normalizedData.append(padded)
        }

        // 3. 计算累计值
        var stacked: [[Double]] = []
        for (index, data) in normalizedData.enumerated() {
            if index == 0 {
                stacked.append(data)  // 第一个系列保持原值
            } else {
                let previous = stacked[index - 1]
                let accumulated = zip(previous, data).map { $0 + $1 }
                stacked.append(accumulated)
            }
        }

        return stacked
    }

    /// 单个柱体位置（垂直图）。
    ///
    /// X 定位与槽宽均由 `viewport` 驱动：视口放大时柱体变宽并跟随视口
    /// （全量视口下与按类目总数计算的结果完全一致）。
    /// - Parameters:
    ///   - dataPoint: 数据点值
    ///   - categoryIndex: 类目索引（0-based）
    ///   - viewport: 值域视口（xSpan 即可见类目跨度，决定槽宽）
    ///   - plotArea: plot 区域
    ///   - theme: 主题配置（间距、圆角等）
    ///   - zeroY: 零轴 Y 坐标
    ///   - baselineValue: 基准值（堆叠模式下使用，nil 表示从零轴开始）
    ///   - seriesIndex: 系列索引（不堆叠模式下使用，0-based，默认 0）
    ///   - seriesCount: 系列总数（不堆叠模式下使用，默认 1）
    /// - Returns: 柱体的 CGRect（minY/maxY 根据 zeroY 自动确定方向）
    public static func columnRect(
        dataPoint: Double,
        categoryIndex: Int,
        viewport: CartesianViewport,
        plotArea: CGRect,
        theme: CartesianChartTheme,
        zeroY: CGFloat,
        baselineValue: Double? = nil,
        seriesIndex: Int = 0,
        seriesCount: Int = 1
    ) -> CGRect {
        // 1. 槽宽按视口跨度计算（可见类目平分 plot 宽；缩放时柱体随之变宽）
        let slotWidth = plotArea.width / CGFloat(max(viewport.xSpan, 1e-9))
        let subSlotWidth = slotWidth / CGFloat(seriesCount)  // 每个 series 的子槽宽度
        let columnWidth = subSlotWidth * theme.columnWidthRatio

        // 2. X 位置：类目中心经视口映射（缩放/平移自动跟随），再定位到系列子槽
        let seriesOffset = CGFloat(seriesIndex) * subSlotWidth  // 系列偏移
        let centerX = point(x: Double(categoryIndex), y: 0, viewport: viewport, plotFrame: plotArea).x
        let columnX = centerX - slotWidth / 2 + seriesOffset + (subSlotWidth - columnWidth) / 2

        // 3. 计算数据点对应的 Y 坐标（使用现有的 point 函数）
        let valueY = point(x: Double(categoryIndex), y: dataPoint, viewport: viewport, plotFrame: plotArea).y

        // 4. 计算基准 Y 坐标（堆叠模式下使用）
        let startY: CGFloat
        if let baseline = baselineValue {
            startY = point(x: Double(categoryIndex), y: baseline, viewport: viewport, plotFrame: plotArea).y
        } else {
            startY = zeroY
        }

        // 5. 根据正负值确定矩形
        if dataPoint >= 0 {
            // 正值：从基准线向上到 valueY
            let height = startY - valueY
            return CGRect(x: columnX, y: valueY, width: columnWidth, height: height)
        } else {
            // 负值：从 valueY 向下到基准线
            let height = valueY - startY
            return CGRect(x: columnX, y: startY, width: columnWidth, height: height)
        }
    }

    /// 单个条形位置（水平图）。
    ///
    /// 数值方向（X）由 `viewport` 驱动（本 SDK 的缩放/平移只作用于 X 轴，
    /// 对条形图即缩放数值轴、类目轴固定）；条形高度按类目轴跨度（`viewport.ySpan`）计算。
    /// - Parameters:
    ///   - dataPoint: 数据点值
    ///   - categoryIndex: 类目索引（0-based，类目 0 在顶部）
    ///   - viewport: 值域视口（ySpan 即类目跨度，决定槽高）
    ///   - plotArea: plot 区域
    ///   - theme: 主题配置（间距、圆角等）
    ///   - zeroX: 零轴 X 坐标
    ///   - baselineValue: 基准值（堆叠模式下使用，nil 表示从零轴开始）
    ///   - seriesIndex: 系列索引（不堆叠模式下使用，0-based，默认 0）
    ///   - seriesCount: 系列总数（不堆叠模式下使用，默认 1）
    /// - Returns: 条形的 CGRect（minX/maxX 根据 zeroX 自动确定方向）
    public static func barRect(
        dataPoint: Double,
        categoryIndex: Int,
        viewport: CartesianViewport,
        plotArea: CGRect,
        theme: CartesianChartTheme,
        zeroX: CGFloat,
        baselineValue: Double? = nil,
        seriesIndex: Int = 0,
        seriesCount: Int = 1
    ) -> CGRect {
        // 1. 槽高按类目轴跨度计算（Bar 的类目在 Y 轴；Y 不参与手势，恒为全量）
        let slotHeight = plotArea.height / CGFloat(max(viewport.ySpan, 1e-9))
        let subSlotHeight = slotHeight / CGFloat(seriesCount)  // 每个 series 的子槽高度
        let barHeight = subSlotHeight * theme.columnWidthRatio

        // 2. Y 位置（考虑系列偏移；类目 0 在顶部）
        let seriesOffset = CGFloat(seriesIndex) * subSlotHeight  // 系列偏移
        let barY = plotArea.minY + CGFloat(categoryIndex) * slotHeight + seriesOffset + (subSlotHeight - barHeight) / 2

        // 3. 计算数据点对应的 X 坐标（水平图的 X 轴对应数值，随 X 视口缩放）
        let valueX = point(x: dataPoint, y: Double(categoryIndex), viewport: viewport, plotFrame: plotArea).x

        // 4. 计算基准 X 坐标（堆叠模式下使用）
        let startX: CGFloat
        if let baseline = baselineValue {
            startX = point(x: baseline, y: Double(categoryIndex), viewport: viewport, plotFrame: plotArea).x
        } else {
            startX = zeroX
        }

        // 5. 根据正负值确定矩形
        if dataPoint >= 0 {
            // 正值：从基准线向右到 valueX
            let width = valueX - startX
            return CGRect(x: startX, y: barY, width: width, height: barHeight)
        } else {
            // 负值：从 valueX 向左到基准线
            let width = startX - valueX
            return CGRect(x: valueX, y: barY, width: width, height: barHeight)
        }
    }
}
