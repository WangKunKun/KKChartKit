import UIKit

/// 等间隔采样时间。数组缺测位置应填 .nan，不能删除位置。
public struct CartesianTimeAxis {
    public var start: Date
    public var interval: TimeInterval
    public var timeZone: TimeZone
    public var labelFormatter: ((Date) -> String)?
    public init(start: Date, interval: TimeInterval, timeZone: TimeZone = .current,
                labelFormatter: ((Date) -> String)? = nil) {
        self.start = start
        self.interval = interval
        self.timeZone = timeZone
        self.labelFormatter = labelFormatter
    }
    func isValid(count: Int) -> Bool {
        interval.isFinite && interval > 0 && start.timeIntervalSinceReferenceDate.isFinite
            && (start.timeIntervalSinceReferenceDate + interval * Double(count)).isFinite
    }
    func date(at index: Int) -> Date { start.addingTimeInterval(Double(index) * interval) }
    func labels(count: Int) -> [String] {
        guard isValid(count: count) else { return [] }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = interval * Double(max(0, count - 1)) >= 86400 ? "MM-dd HH:mm" : "HH:mm"
        return (0..<count).map { labelFormatter?(date(at: $0)) ?? formatter.string(from: date(at: $0)) }
    }
}

public struct CartesianTimeSample {
    public let sourceIndex: Int
    public let date: Date
    public let value: Double
}

/// 明确由业务选择；未配置的可见系列会使整个图表回退原始展示，保持系列对齐。
public enum CartesianAggregation {
    case sum, average, min, max, last
    /// 仅接收有限值，按时间排序；全缺测不调用。闭包须无副作用，返回 nil 表示缺测。
    case custom(name: String, reduce: ([CartesianTimeSample]) -> Double?)

    public var name: String {
        switch self {
        case .sum: return "合计"
        case .average: return "平均"
        case .min: return "最小"
        case .max: return "最大"
        case .last: return "末值"
        case .custom(let name, _): return name
        }
    }
    func reduce(_ samples: [CartesianTimeSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let value: Double?
        switch self {
        case .sum: value = samples.reduce(0) { $0 + $1.value }
        case .average: value = samples.reduce(0) { $0 + $1.value / Double(samples.count) }
        case .min: value = samples.map(\.value).min()
        case .max: value = samples.map(\.value).max()
        case .last: value = samples.last?.value
        case .custom(_, let reduce): value = reduce(samples)
        }
        return value.flatMap { $0.isFinite ? $0 : nil }
    }
}

/// Column 的自动时间聚合；nil 配置保持原始行为。
public struct CartesianTimeGrouping {
    public var minimumColumnWidth: CGFloat = 4
    /// 在同一次数据/主题版本的手势重排中复用结果；每 renderer 最多保留三个粒度。
    /// configure/update、显隐变更及外部布局渲染会失效；false 便于对照调试。
    public var isCacheEnabled = true
    /// 放大到更细粒度前额外预留的宽度比例，抑制临界点反复切换。范围 0...0.5；0 关闭。
    /// 缩小时若柱宽不足仍立即合并，独立纯函数 group 不应用历史缓冲。
    public var granularityHysteresis: CGFloat = 0.15
    /// 首选区间秒数；向上取到完整采样数，区间锚定 timeAxis.start。
    public var preferredIntervals: [TimeInterval] = [60, 300, 900, 1800, 3600, 7200, 14400, 21600, 43200, 86400]
    public init(minimumColumnWidth: CGFloat = 4) { self.minimumColumnWidth = minimumColumnWidth }
}

/// 聚合项与原始数据之间的映射；区间为 [start, end)，末桶可能较短。
public struct CartesianTimeBucket {
    public let sourceRange: Range<Int>
    public let interval: DateInterval
    public let validSampleCount: Int
    public var expectedSampleCount: Int { sourceRange.count }
    public var coverage: Double { Double(validSampleCount) / Double(max(1, expectedSampleCount)) }
    public let value: Double?
    public let minimum: Double?
    public let maximum: Double?
    public let aggregationName: String
    public let unit: String?
    public let timeZone: TimeZone
    public var isAggregated: Bool { sourceRange.count > 1 }
    public var intervalLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MM-dd HH:mm"
        return "\(formatter.string(from: interval.start))–\(formatter.string(from: interval.end))"
    }
    var detailLabel: String { "\(aggregationName) · 有效 \(validSampleCount)/\(expectedSampleCount)" }
    func tooltipRow(name: String) -> String {
        "\(name) · \(detailLabel)：\(value.map { AxisRenderer.format($0) } ?? "无数据")\(unit.map { " " + $0 } ?? "")"
    }
}

public enum CartesianTimeGroupingStatus: Equatable {
    case disabled, invalidTimeAxis, missingAggregation, unsupportedStacking, noVisibleSeries
    case active(samplesPerBucket: Int)
}

/// 公开纯数据入口也便于业务验证 reducer；不修改输入模型。
public struct CartesianTimeGroupingResult {
    public let samplesPerBucket: Int
    public let status: CartesianTimeGroupingStatus
    /// [系列索引][桶序号]；保留隐藏系列的空数组，原始系列索引不压缩。
    public let buckets: [[CartesianTimeBucket]]
    let model: CartesianChartModel
}

public enum CartesianTimeGrouper {
    public static func group(model: CartesianChartModel, theme: CartesianChartTheme,
                             plotWidth: CGFloat, visibleRange: ClosedRange<Double>) -> CartesianTimeGroupingResult {
        group(model: model, plan: plan(model: model, theme: theme, plotWidth: plotWidth, visibleRange: visibleRange))
    }

    static func plan(model: CartesianChartModel, theme: CartesianChartTheme,
                     plotWidth: CGFloat, visibleRange: ClosedRange<Double>) -> CartesianTimeGroupingPlan {
        let count = model.maxPointCount
        func fallback(_ status: CartesianTimeGroupingStatus) -> CartesianTimeGroupingPlan {
            CartesianTimeGroupingPlan(samplesPerBucket: 1, status: status)
        }
        guard let configuration = model.timeGrouping else { return fallback(.disabled) }
        guard count > 0, let time = model.timeAxis, time.isValid(count: count) else { return fallback(.invalidTimeAxis) }
        let visible = model.series.filter(\.isVisible)
        guard !visible.isEmpty else { return fallback(.noVisibleSeries) }
        guard visible.allSatisfy({ $0.aggregation != nil }) else { return fallback(.missingAggregation) }
        if case .percentFixed = model.stacking { return fallback(.unsupportedStacking) }
        let seriesCount = model.columnSlotCount
        let minimumWidth = configuration.minimumColumnWidth.isFinite ? max(1, configuration.minimumColumnWidth) : 4
        let groupWidth: CGFloat
        if let spacing = theme.columnSpacing {
            // 固定 pt 间距不随槽宽缩放，必须直接计入完整组的宽度预算。
            groupWidth = spacing.requiredSlotWidth(seriesCount: seriesCount, minimumColumnWidth: minimumWidth)
        } else {
            let unitRect = CartesianGeometry.columnRect(dataPoint: 1, categoryIndex: 0,
                viewport: CartesianViewport(xMin: -0.5, xMax: 0.5, yMin: 0, yMax: 1),
                plotArea: CGRect(x: 0, y: 0, width: 1, height: 1), theme: theme, zeroY: 1,
                seriesCount: seriesCount)
            groupWidth = minimumWidth / max(unitRect.width, 0.001)
        }
        let width = plotWidth.isFinite ? max(1, plotWidth) : 1
        let capacity = max(1, min(count, Int(min(CGFloat(count), floor(width / groupWidth)))))
        let rawSpan = visibleRange.upperBound - visibleRange.lowerBound
        let span = rawSpan.isFinite ? min(Double(count), max(1, rawSpan)) : Double(count)
        let required = min(count, max(1, Int(ceil(span / Double(capacity)))))
        var stride = required
        if required > 1 {
            let candidates = configuration.preferredIntervals.filter { $0.isFinite && $0 > 0 }.map {
                min(count, max(1, Int(min(Double(count), ceil($0 / time.interval)))))
            }.sorted()
            stride = candidates.first(where: { $0 >= required }) ?? required
        }
        return CartesianTimeGroupingPlan(samplesPerBucket: stride, status: .active(samplesPerBucket: stride))
    }

    static func group(model: CartesianChartModel, plan: CartesianTimeGroupingPlan) -> CartesianTimeGroupingResult {
        guard case .active = plan.status, let time = model.timeAxis else {
            return CartesianTimeGroupingResult(samplesPerBucket: 1, status: plan.status, buckets: [], model: model)
        }
        let count = model.maxPointCount
        let stride = plan.samplesPerBucket
        var prepared = model
        prepared.timeBucketStride = stride
        prepared.timeBucketMetadata = Array(repeating: [:], count: model.series.count)
        var output: [[CartesianTimeBucket]] = Array(repeating: [], count: model.series.count)
        for (seriesIndex, series) in model.series.enumerated() {
            var values = Array(repeating: Double.nan, count: count)
            if series.isVisible, let reducer = series.aggregation {
                for lower in Swift.stride(from: 0, to: count, by: stride) {
                    let range = lower..<min(count, lower + stride)
                    let samples = range.compactMap { i -> CartesianTimeSample? in
                        guard i < series.data.count, series.data[i].isFinite else { return nil }
                        return CartesianTimeSample(sourceIndex: i, date: time.date(at: i), value: series.data[i])
                    }
                    // 恢复原始粒度时不调用 custom，不改变原值。
                    let value = stride == 1 ? samples.first?.value : reducer.reduce(samples)
                    let bucket = CartesianTimeBucket(sourceRange: range,
                        interval: DateInterval(start: time.date(at: range.lowerBound), end: time.date(at: range.upperBound)),
                        validSampleCount: samples.count, value: value,
                        minimum: samples.map(\.value).min(), maximum: samples.map(\.value).max(),
                        aggregationName: stride == 1 ? "原始值" : reducer.name, unit: series.unit, timeZone: time.timeZone)
                    values[lower] = value ?? .nan
                    prepared.timeBucketMetadata[seriesIndex][lower] = bucket
                    output[seriesIndex].append(bucket)
                }
            }
            prepared.series[seriesIndex].data = values
        }
        return CartesianTimeGroupingResult(samplesPerBucket: stride, status: .active(samplesPerBucket: stride),
                                           buckets: output, model: prepared)
    }
}

protocol HYMChartCategoryViewportControlling: AnyObject {
    func showCategoryRange(_ range: Range<Int>)
}


/// 只做宽度预算，不执行 reducer；供交互缓存按最终粒度查找。
struct CartesianTimeGroupingPlan {
    let samplesPerBucket: Int
    let status: CartesianTimeGroupingStatus
}
