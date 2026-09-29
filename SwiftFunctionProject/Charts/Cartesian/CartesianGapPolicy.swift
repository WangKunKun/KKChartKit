import Foundation

/// 折线/面积系列的缺测连接策略；仅影响路径，不补点、不改变数据、值域或命中。
/// NaN 和正负 Infinity 均为缺测。柱状/条形系列不使用此配置。
public enum CartesianGapPolicy: Equatable {
    /// 每段缺测都断开。
    case breakAll
    /// 连接全部有效点，忽略中间缺测。
    case connectAll
    /// 连续缺测数 <= 上限时连接；负上限按 0 处理。
    /// 例如上限 11：11 个空点连接，12/13 个空点断开。
    case autoGap(maximumMissingPoints: Int)
    /// 等间隔时间轴中，缺测数 × interval <= 上限秒数时连接（含等号）。
    /// 不包括两端有效点；无有效 timeAxis，或上限非有限/负值时，缺测处断开。
    case autoGapDuration(maximumMissingDuration: TimeInterval)

    func connects(missingCount: Int, sampleInterval: TimeInterval?) -> Bool {
        guard missingCount > 0 else { return true }
        switch self {
        case .breakAll: return false
        case .connectAll: return true
        case .autoGap(let maximum): return missingCount <= max(0, maximum)
        case .autoGapDuration(let maximum):
            guard maximum.isFinite, maximum >= 0,
                  let interval = sampleInterval, interval.isFinite, interval > 0 else { return false }
            let duration = Double(missingCount) * interval
            return duration.isFinite && duration <= maximum
        }
    }
}

/// 在原始索引上分段，必须先于降采样；前后缺测不产生空段或虚构端点。
enum CartesianGapSegmenter {
    static func segments(values: [Double], policy: CartesianGapPolicy,
                         sampleInterval: TimeInterval? = nil) -> [[Int]] {
        var result: [[Int]] = []
        var run: [Int] = []
        for index in values.indices where values[index].isFinite {
            if let previous = run.last,
               !policy.connects(missingCount: index - previous - 1, sampleInterval: sampleInterval) {
                result.append(run)
                run.removeAll(keepingCapacity: true)
            }
            run.append(index)
        }
        if !run.isEmpty { result.append(run) }
        return result
    }
}
