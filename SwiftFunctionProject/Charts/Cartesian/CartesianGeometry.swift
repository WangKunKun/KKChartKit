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

    /// 类目 label 抽样步长：类目数超过 `maxLabels`（默认 10）时隔 N 取 1 显示。
    public static func categoryLabelStride(count: Int, maxLabels: Int = 10) -> Int {
        guard count > maxLabels, maxLabels > 0 else { return 1 }
        return Int(ceil(Double(count) / Double(maxLabels)))
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
}
