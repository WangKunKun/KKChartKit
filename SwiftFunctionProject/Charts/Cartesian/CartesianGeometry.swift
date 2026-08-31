import CoreGraphics
import UIKit

/// 轴系图表几何纯函数（plot 布局、值↔屏幕映射；DEBUG 自检覆盖）。
public enum CartesianGeometry {

    /// 橡皮筋越界余量占全量跨度的比例（拖出边界的手感上限）。
    public static let rubberBandMarginRatio = 0.25

    /// 计算 plot 区（网格 + series 绘制区）frame。
    ///
    /// 布局模型：内容 inset → 顶部让出标题 → 左侧让出 y 刻度 label → 底部让出 x 刻度 label。
    /// `yAxisTickLabelWidth` / `xAxisTickLabelHeight` 由调用方按最宽/最高刻度文本量好传入。
    public static func layout(bounds: CGRect,
                              contentInset: UIEdgeInsets,
                              yAxisTickLabelWidth: CGFloat,
                              xAxisTickLabelHeight: CGFloat,
                              axisLabelGap: CGFloat,
                              titleHeight: CGFloat,
                              rightAxisLabelWidth: CGFloat = 0) -> CGRect {
        let x = bounds.minX + contentInset.left + yAxisTickLabelWidth + axisLabelGap
        let y = bounds.minY + contentInset.top + titleHeight + axisLabelGap
        let w = max(0, bounds.width - contentInset.left - contentInset.right
                        - yAxisTickLabelWidth - axisLabelGap
                        - rightAxisLabelWidth - (rightAxisLabelWidth > 0 ? axisLabelGap : 0))
        let h = max(0, bounds.height - contentInset.top - contentInset.bottom
                        - titleHeight - axisLabelGap - xAxisTickLabelHeight - axisLabelGap)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// 值 → 屏幕（view 坐标系）。x/y 均为线性映射；y 轴屏幕向下，故值越大 y 越小。
    /// 类目模式下数据点 x 取索引值（域 -0.5...n-0.5 时点落在 band 中心）。
    public static func point(x: Double, y: Double,
                             viewport: CartesianViewport,
                             plotFrame: CGRect,
                             yDomain: ClosedRange<Double>? = nil) -> CGPoint {
        let domain = yDomain ?? viewport.yDomain
        let tx = (x - viewport.xMin) / max(viewport.xSpan, 1e-9)
        let ty = (y - domain.lowerBound) / max(domain.upperBound - domain.lowerBound, 1e-9)
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
    /// 橡皮筋模式（`overshootMargin` > 0）：窗口贴着全量域边缘继续推时，
    /// 位移按 `rubberDamping` 阻尼衰减（越界部分走不动了），且允许越界至多
    /// `overshootMargin`（值域单位）——松手后由调用方回弹。
    /// - Parameters:
    ///   - range: 平移前的窗口
    ///   - screenDeltaX: 屏幕位移（px，右滑为正 → 内容右移 → 窗口左移看更早数据）
    ///   - plotWidth: plot 区宽度（像素↔值域换算基准）
    ///   - fullDomain: 全量域（窗口不得越出）
    ///   - overshootMargin: 橡皮筋越界余量（值域单位；0 = 硬 clamp，旧行为）
    ///   - rubberDamping: 越界方向的位移阻尼（0...1，默认 0.4）
    public static func pannedXRange(from range: ClosedRange<Double>,
                                    screenDeltaX: CGFloat,
                                    plotWidth: CGFloat,
                                    fullDomain: ClosedRange<Double>,
                                    overshootMargin: Double = 0,
                                    rubberDamping: Double = 0.4) -> ClosedRange<Double> {
        let span = range.upperBound - range.lowerBound
        guard span > 0, plotWidth > 0 else { return fullDomain }
        var offset = Double(screenDeltaX) / Double(plotWidth) * span

        // 贴边继续推：越界方向位移阻尼（视口已在边缘且仍往外推时）
        if overshootMargin > 0 {
            let atLowerEdge = range.lowerBound <= fullDomain.lowerBound + 1e-9 && offset > 0
            let atUpperEdge = range.upperBound >= fullDomain.upperBound - 1e-9 && offset < 0
            if atLowerEdge || atUpperEdge { offset *= min(max(rubberDamping, 0), 1) }
        }

        var lo = range.lowerBound - offset
        var hi = range.upperBound - offset
        // clamp：硬模式收紧在 fullDomain；橡皮筋模式放宽到 ±overshootMargin
        let lowerBound = fullDomain.lowerBound - overshootMargin
        let upperBound = fullDomain.upperBound + overshootMargin
        if lo < lowerBound {
            lo = lowerBound
            hi = lo + span
        }
        if hi > upperBound {
            hi = upperBound
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

    /// 把点序列以平滑曲线加入 path（`LineConnectionStyle.smooth` 用）。
    ///
    /// **Fritsch–Carlson 单调三次插值**（d3.curveMonotoneX 同款）：切线经限幅处理，
    /// 数学上保证每段曲线不超出两端点的值域——**视觉波峰/波谷必定落在数据点上**，
    /// 不会出现 Catmull-Rom 那种数据点旁边冲出虚假波峰的过冲。
    /// 调用方须已 `move(to: points[0])`；每段转三次贝塞尔；点数 ≤ 2 退化为直线。
    public static func appendSmoothCurve(to path: UIBezierPath, points: [CGPoint]) {
        guard points.count > 2 else {
            for p in points.dropFirst() { path.addLine(to: p) }
            return
        }
        let n = points.count

        // 1) 各段斜率
        var delta = [CGFloat](repeating: 0, count: n - 1)
        for i in 0..<n - 1 {
            let dx = points[i + 1].x - points[i].x
            delta[i] = dx != 0 ? (points[i + 1].y - points[i].y) / dx : 0
        }

        // 2) 各点切线（端点用相邻段斜率；内部点：相邻段斜率异号 → 0（局部极值，平台化），
        //    同号 → 平均）
        var m = [CGFloat](repeating: 0, count: n)
        m[0] = delta[0]
        m[n - 1] = delta[n - 2]
        for i in 1..<n - 1 {
            m[i] = delta[i - 1] * delta[i] <= 0 ? 0 : (delta[i - 1] + delta[i]) / 2
        }

        // 3) 限幅（防过冲核心）：段斜率为 0 → 两端切线归零；切线平方和超阈值（a²+b²>9）
        //    按比例收紧到边界——由此每段三次曲线被约束在端点值域内
        for i in 0..<n - 1 {
            if delta[i] == 0 {
                m[i] = 0
                m[i + 1] = 0
                continue
            }
            let a = m[i] / delta[i]
            let b = m[i + 1] / delta[i]
            let s = a * a + b * b
            if s > 9 {
                let t = 3 / sqrt(s)
                m[i] = t * a * delta[i]
                m[i + 1] = t * b * delta[i]
            }
        }

        // 4) Hermite → 三次贝塞尔（控制点在端点切线 1/3 处）
        for i in 0..<n - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]
            let dx = (p2.x - p1.x) / 3
            path.addCurve(to: p2,
                          controlPoint1: CGPoint(x: p1.x + dx, y: p1.y + m[i] * dx),
                          controlPoint2: CGPoint(x: p2.x - dx, y: p2.y - m[i + 1] * dx))
        }
    }

    /// 水平图类目 → 屏幕 Y（类目 0 在顶部，自上而下映射）。
    ///
    /// 与 `point` 的 Y 方向相反（`point` 的值域向上）：条形图的类目轴是离散
    /// 序列轴，阅读顺序自上而下（Highcharts 同款）。条形（`barRect`）、
    /// 左侧类目标签、横网格线与命中测试必须共用本映射，保证相互对齐。
    public static func horizontalCategoryY(category: Double,
                                           viewport: CartesianViewport,
                                           plotFrame: CGRect) -> CGFloat {
        let t = (category - viewport.yMin) / max(viewport.ySpan, 1e-9)
        return plotFrame.minY + CGFloat(t) * plotFrame.height
    }

    /// 水平图屏幕 Y → 类目（`horizontalCategoryY` 的逆映射）。
    public static func horizontalCategory(atY y: CGFloat,
                                          viewport: CartesianViewport,
                                          plotFrame: CGRect) -> Double {
        let t = Double((y - plotFrame.minY) / max(plotFrame.height, 1e-9))
        return viewport.yMin + t * viewport.ySpan
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
        isHorizontal: Bool = false,
        valueDomain: ClosedRange<Double>? = nil
    ) -> CGFloat {
        if isHorizontal {
            // 水平图（Bar）：返回 X 坐标（Bar 无次轴，不域参数化）
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
            // 垂直图（Column/Line）：返回 Y 坐标（valueDomain 供次轴系列使用）
            let d = valueDomain ?? viewport.yDomain
            if d.lowerBound >= 0 {
                // 全正值域，零轴在底部
                return plotArea.maxY
            } else if d.upperBound <= 0 {
                // 全负值域，零轴在顶部
                return plotArea.minY
            } else {
                // 混合值域，零轴在内部（插值计算）
                let ratio = -d.lowerBound / (d.upperBound - d.lowerBound)
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

    /// 按值轴分组的链式累计（双轴堆叠：跨轴不混叠）；返回与输入同序。
    /// **符号分组**（Highcharts 同款）：同轴内正值点只与正值累计、负值点只与负值累计，
    /// 正链从 0 向上、负链从 0 向下——形成上下镜像（收支对比/人口金字塔形态）。
    /// 系列 i 在点 j 的累计 = 同轴同符号链在 j 的前累计 + 自身值；
    /// 短系列补 0 对齐到最长长度。全主轴全非负时与 `stackedValues` 结果完全一致。
    public static func stackedValuesByAxis(series: [CartesianSeriesElement]) -> [[Double]] {
        guard !series.isEmpty else { return [] }
        let maxLength = series.map { $0.data.count }.max() ?? 0
        guard maxLength > 0 else { return [] }
        var runningPositive: [Int: [Double]] = [:]
        var runningNegative: [Int: [Double]] = [:]
        var out: [[Double]] = []
        for s in series {
            let axis = s.effectiveYAxisIndex
            let padded = s.data + [Double](repeating: 0, count: max(0, maxLength - s.data.count))
            let zeros = [Double](repeating: 0, count: maxLength)
            let pos = runningPositive[axis] ?? zeros
            let neg = runningNegative[axis] ?? zeros
            var cum = [Double](repeating: 0, count: maxLength)
            for j in 0..<maxLength {
                // 空值（NaN）：自身该点保持 NaN（断线），且不更新链——后续系列视其为缺位
                guard padded[j].isFinite else { cum[j] = .nan; continue }
                // 逐点按符号入链：v ≥ 0 归正链（0 视为正，与 Highcharts 一致）
                cum[j] = padded[j] >= 0 ? pos[j] + padded[j] : neg[j] + padded[j]
            }
            var newPos = pos
            var newNeg = neg
            for j in 0..<maxLength where padded[j].isFinite && padded[j] != 0 {
                if padded[j] > 0 { newPos[j] = cum[j] } else { newNeg[j] = cum[j] }
            }
            runningPositive[axis] = newPos
            runningNegative[axis] = newNeg
            out.append(cum)
        }
        return out
    }

    /// 百分比堆叠：归一化原值。
    /// - Parameters:
    ///   - fixedMax: 统一基准（nil = 每列按该列 |v| 总和归一，必满 100%）；
    ///     显式值时所有列按 v/fixedMax×100 归一，列合计可不满/超过 100%。
    /// 与输入同序；符号保留（正链向上、负链向下），短系列补 0 对齐；分母 ≤ 0 → 0。
    public static func percentNormalizedValues(series: [CartesianSeriesElement],
                                               fixedMax: Double? = nil) -> [[Double]] {
        guard !series.isEmpty else { return [] }
        let maxLength = series.map { $0.data.count }.max() ?? 0
        guard maxLength > 0 else { return [] }
        var totals: [Int: [Double]] = [:]   // axis -> 每列 |v| 总和（fixedMax 模式不用）
        if fixedMax == nil {
            for s in series {
                let axis = s.effectiveYAxisIndex
                var t = totals[axis] ?? [Double](repeating: 0, count: maxLength)
                for j in 0..<maxLength where j < s.data.count {
                    t[j] += abs(s.data[j])   // NaN 参与加法得 NaN，下方 isFinite 过滤按 0 计
                }
                totals[axis] = t.map { $0.isFinite ? $0 : 0 }
            }
        }
        return series.map { s in
            let axis = s.effectiveYAxisIndex
            let t = totals[axis] ?? [Double](repeating: 0, count: maxLength)
            return (0..<maxLength).map { j in
                let raw = j < s.data.count ? s.data[j] : 0
                guard raw.isFinite else { return .nan }   // 空值保持 NaN（断线）
                let denom = fixedMax ?? t[j]
                return denom > 1e-9 ? raw / denom * 100 : 0
            }
        }
    }

    /// 百分比堆叠累计：归一化原值按符号链累计（正链向上、负链向下）。
    public static func stackedPercentValues(series: [CartesianSeriesElement],
                                            fixedMax: Double? = nil) -> [[Double]] {
        let normalized = zip(series, percentNormalizedValues(series: series, fixedMax: fixedMax)).map {
            CartesianSeriesElement(name: $0.name, data: $1, color: $0.color,
                                   negativeColor: $0.negativeColor, yAxisIndex: $0.yAxisIndex)
        }
        return stackedValuesByAxis(series: normalized)
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
        valueDomain: ClosedRange<Double>? = nil,
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

        // 2. 组内间距：nil = 柱宽余量（1 - ratio，旧行为）；显式设置则独立可调
        //    （clamp 到组不超槽：n×柱宽 + (n-1)×间距 ≤ 槽宽）
        let innerGap: CGFloat
        if let ratio = theme.columnInnerSpacingRatio {
            let fit = seriesCount > 1
                ? (slotWidth - columnWidth * CGFloat(seriesCount)) / CGFloat(seriesCount - 1)
                : 0
            innerGap = min(ratio * subSlotWidth, max(0, fit))
        } else {
            innerGap = subSlotWidth - columnWidth
        }

        // 3. X 位置：类目中心经视口映射（缩放/平移自动跟随）；组区域两侧留组间距，
        //    组内柱按（柱宽 + 间距）排布后整体居中；组放不下时柱与间距等比收窄
        let groupRegion = slotWidth * (1 - theme.columnGroupSpacingRatio)
        var barWidth = columnWidth
        var gap = innerGap
        let count = CGFloat(max(seriesCount, 1))
        let desired = barWidth * count + gap * CGFloat(max(seriesCount - 1, 0))
        if desired > groupRegion, desired > 0 {
            let scale = groupRegion / desired
            barWidth *= scale
            gap *= scale
        }
        let groupWidth = barWidth * count + gap * CGFloat(max(seriesCount - 1, 0))
        let centerX = point(x: Double(categoryIndex), y: 0, viewport: viewport, plotFrame: plotArea).x
        let groupStart = centerX - groupRegion / 2 + (groupRegion - groupWidth) / 2
        let columnX = groupStart + CGFloat(seriesIndex) * (barWidth + gap)

        // 3. 计算数据点对应的 Y 坐标（使用现有的 point 函数）
        let valueY = point(x: Double(categoryIndex), y: dataPoint, viewport: viewport,
                           plotFrame: plotArea, yDomain: valueDomain).y

        // 4. 计算基准 Y 坐标（堆叠模式下使用）
        let startY: CGFloat
        if let baseline = baselineValue {
            startY = point(x: Double(categoryIndex), y: baseline, viewport: viewport,
                            plotFrame: plotArea, yDomain: valueDomain).y
        } else {
            startY = zeroY
        }

        // 5. 根据正负值确定矩形
        if dataPoint >= 0 {
            // 正值：从基准线向上到 valueY
            let height = startY - valueY
            return CGRect(x: columnX, y: valueY, width: barWidth, height: height)
        } else {
            // 负值：从 valueY 向下到基准线
            let height = valueY - startY
            return CGRect(x: columnX, y: startY, width: barWidth, height: height)
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
