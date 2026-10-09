import Foundation
import CoreGraphics

/// 折线 Min/Max 绘制降采样。设置到 `CartesianChartTheme.lineSampling`；nil 保持原始绘制。
/// 仅用于非堆叠直线（包括面积填充），不修改模型、值域和命中数据。bucketWidth 的单位为 UIKit point。
public struct LineChartSampling {
    /// 每条可见系列、当前视口的目标绘制点数（含边缘衔接邻点）；nil 使用原分组宽度模式。
    /// 非 nil 时优先于 bucketWidth / minimumVisiblePoints，最小按 2 处理；不足目标时不补点。
    /// 优先保留每个有效段的首、尾、最低、最高点；若保护点数超过目标，允许超额，避免断点/峰谷丢失。
    public var targetPointCount: Int? = nil
    /// 每个屏幕分组的目标宽度。每个连续有效段在组内保留首、尾、最小、最大值的原始索引。
    /// 数值越大，绘制点越少；无效值按 2 处理，最小为 1。
    public var bucketWidth: CGFloat = 2
    /// 分组宽度模式的启动门槛，并非保留点数（最小 2）；targetPointCount 非 nil 时忽略。
    public var minimumVisiblePoints: Int = 500
    /// 密集时隐藏 marker，缩放到稀疏视口自动恢复；不影响点击/吸附原始点。
    /// showsPoints 开启时仍保留孤立有效点的 marker，避免缺测分段只剩单点时不可见。
    public var hidesDenseMarkers = true
    /// 密集时隐藏数据标签，稀疏时继续遵守主题/系列开关和 dataLabelMaxMarkCount。
    public var hidesDenseDataLabels = true

    /// 创建默认配置。与其他图表主题一样，在主线程更新图表；配置本身为纯值类型。
    public init() {}
}

/// 只保存原始索引，绝不将省略点变为缺测或写回 series.data。
struct LineRenderSelection {
    let segments: [[Int]]
    let visiblePointCount: Int
    let isDense: Bool
    var sourcePointCount: Int = 0
    var minimumRequiredPointCount: Int = 0
    var renderedPointCount: Int { segments.reduce(0) { $0 + $1.count } }
}

/// 无 UIKit/图层依赖的纯算法。宽度模式锚定原始索引 0；目标模式按当前裁剪片段分配预算。
enum LineMinMaxSampler {
    static func segments(values: [Double], connectNulls: Bool,
                         gapPolicy: CartesianGapPolicy? = nil,
                         sampleInterval: TimeInterval? = nil) -> [[Int]] {
        CartesianGapSegmenter.segments(values: values,
            policy: gapPolicy ?? (connectNulls ? .connectAll : .breakAll), sampleInterval: sampleInterval)
    }

    static func select(values: [Double], connectNulls: Bool, visibleRange: ClosedRange<Double>,
                       plotWidth: CGFloat, configuration: LineChartSampling,
                       gapPolicy: CartesianGapPolicy? = nil,
                       sampleInterval: TimeInterval? = nil) -> LineRenderSelection {
        let original = segments(values: values, connectNulls: connectNulls,
                                gapPolicy: gapPolicy, sampleInterval: sampleInterval)
        let lo = visibleRange.lowerBound, hi = visibleRange.upperBound
        let span = hi - lo
        guard lo.isFinite, hi.isFinite, span.isFinite, span > 0,
              plotWidth.isFinite, plotWidth > 0, !values.isEmpty else {
            let count = original.reduce(0) { $0 + $1.count }
            return LineRenderSelection(segments: original, visiblePointCount: count, isDense: false, sourcePointCount: count)
        }
        var clipped: [[Int]] = []
        var visibleCount = 0
        for segment in original {
            guard let first = segment.first, let last = segment.last,
                  Double(last) >= lo, Double(first) <= hi else { continue }
            let start = lowerBound(segment, value: lo)
            let end = upperBound(segment, value: hi)
            visibleCount += max(0, end - start)
            // 边缘各保留一个真实邻点；跨视口的长线段也能完整衔接，不在边缘捏造采样值。
            clipped.append(Array(segment[max(0, start - 1)..<min(segment.count, end + 1)]))
        }
        let sourceCount = clipped.reduce(0) { $0 + $1.count }
        if let target = configuration.targetPointCount {
            let result = LineTargetPointSampler.select(segments: clipped, values: values, target: target)
            let retained = result.segments.reduce(0) { $0 + $1.count }
            return LineRenderSelection(segments: result.segments, visiblePointCount: visibleCount,
                isDense: retained < sourceCount, sourcePointCount: sourceCount,
                minimumRequiredPointCount: result.minimumRequiredPointCount)
        }
        let width = configuration.bucketWidth.isFinite ? max(1, configuration.bucketWidth) : 2
        let bucketCount = max(1, Double(plotWidth / width))
        let stride = max(1, Int(min(Double(values.count), ceil(span / bucketCount))))
        let dense = visibleCount >= max(2, configuration.minimumVisiblePoints) && stride > 1
        guard dense else { return LineRenderSelection(segments: clipped, visiblePointCount: visibleCount, isDense: false, sourcePointCount: sourceCount) }
        let reduced = clipped.map { segment -> [Int] in
            var kept: [Int] = []
            var bucket: [Int] = []
            func flush() {
                guard let first = bucket.first, let last = bucket.last else { return }
                var minimum = first, maximum = first
                for i in bucket {
                    if values[i] < values[minimum] { minimum = i }
                    if values[i] > values[maximum] { maximum = i }
                }
                kept.append(contentsOf: Set([first, minimum, maximum, last]).sorted())
            }
            for i in segment {
                if let first = bucket.first, first / stride != i / stride { flush(); bucket.removeAll(keepingCapacity: true) }
                bucket.append(i)
            }
            flush()
            return kept
        }
        return LineRenderSelection(segments: reduced, visiblePointCount: visibleCount, isDense: true, sourcePointCount: sourceCount)
    }

    private static func lowerBound(_ indices: [Int], value: Double) -> Int {
        var lo = 0, hi = indices.count
        while lo < hi { let mid = (lo + hi) / 2; if Double(indices[mid]) < value { lo = mid + 1 } else { hi = mid } }
        return lo
    }
    private static func upperBound(_ indices: [Int], value: Double) -> Int {
        var lo = 0, hi = indices.count
        while lo < hi { let mid = (lo + hi) / 2; if Double(indices[mid]) <= value { lo = mid + 1 } else { hi = mid } }
        return lo
    }
}

/// 内部诊断快照；统计实际选择的路径顶点，不是 marker 图层数，也不会修改原始数据。
struct LineSamplingStatistics: Equatable {
    let seriesName: String
    let visiblePointCount: Int
    let sourcePointCount: Int
    let renderedPointCount: Int
    let targetPointCount: Int?
    let minimumRequiredPointCount: Int
}
