import Foundation

/// 按点数预算的 Min/Max：先保护每段首尾与全段极值，再分配剩余预算。
/// 仅操作已裁剪、已按缺测规则分段的原始索引；不补点、不跨段连线。
enum LineTargetPointSampler {
    struct Result {
        let segments: [[Int]]
        let minimumRequiredPointCount: Int
    }

    static func select(segments: [[Int]], values: [Double], target: Int) -> Result {
        let protected = segments.map { anchors($0, values: values) }
        let minimum = protected.reduce(0) { $0 + $1.count }
        let originalCount = segments.reduce(0) { $0 + $1.count }
        let budget = min(originalCount, max(minimum, max(2, target)))
        guard budget < originalCount else {
            return Result(segments: segments, minimumRequiredPointCount: minimum)
        }
        var remainingBudget = budget - minimum
        var remainingCapacity = originalCount - minimum
        let sampled = segments.enumerated().map { index, segment -> [Int] in
            let required = protected[index]
            let capacity = segment.count - required.count
            // 按未保护点的数量比例分配，最后一段接收舍入余量；先钳制后转换，避免非法预算溢出。
            let share = remainingCapacity > 0
                ? Int(Double(remainingBudget) * (Double(capacity) / Double(remainingCapacity))) : 0
            let extra = max(remainingBudget - (remainingCapacity - capacity), min(capacity, share))
            remainingBudget -= extra
            remainingCapacity -= capacity
            guard extra > 0 else { return required.sorted() }
            guard extra < capacity else { return segment }
            let candidates = segment.filter { !required.contains($0) }
            var kept = required
            var start = 0
            var slots = extra
            while slots > 0 {
                let take = min(2, slots)
                // 双点组始终至少有两个候选点，奇数预算的最后一组只占一个名额。
                let count = max(take, Int(Double(candidates.count - start) * Double(take) / Double(slots)))
                let end = min(candidates.count, start + count)
                let bucket = candidates[start..<end]
                if take == 2 {
                    var low = bucket.first!, high = bucket.first!
                    for i in bucket {
                        if values[i] < values[low] { low = i }
                        if values[i] >= values[high] { high = i }
                    }
                    // 平台数据的首/尾不同，仍能准确消耗两个名额。
                    kept.insert(low); kept.insert(high)
                } else {
                    // 单点余量保留组内绝对幅值最大的原始点；平局取首个。
                    let peak = bucket.dropFirst().reduce(bucket.first!) {
                        abs(values[$1]) > abs(values[$0]) ? $1 : $0
                    }
                    kept.insert(peak)
                }
                start = end
                slots -= take
            }
            return kept.sorted()
        }
        return Result(segments: sampled, minimumRequiredPointCount: minimum)
    }

    private static func anchors(_ segment: [Int], values: [Double]) -> Set<Int> {
        guard let first = segment.first, let last = segment.last else { return [] }
        var low = first, high = first
        for i in segment {
            if values[i] < values[low] { low = i }
            if values[i] > values[high] { high = i }
        }
        return [first, last, low, high]
    }
}
