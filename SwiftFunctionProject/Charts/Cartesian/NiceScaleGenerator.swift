import Foundation

/// nice numbers 刻度生成（Heckbert 算法）：从数据原始值域生成美化轴值域与刻度，
/// 避免轴上出现 3.7142 这类刻度。纯函数，DEBUG 自检覆盖。
public enum NiceScaleGenerator {

    /// 生成结果：美化后的值域 + 步长 + 刻度序列（min 起、max 止，含两端）。
    public struct Scale: Equatable {
        public var min: Double
        public var max: Double
        public var step: Double
        public var ticks: [Double]
    }

    /// 生成美化刻度。
    ///
    /// 规则：
    /// - 数据全非负（min ≥ 0）时下界从 0 起算（柱状图语义直觉）。
    /// - 平线（min == max）：值为 0 → 0...1；正值顶格（下界钳 0 后 range 正常）；
    ///   负值上浮 |lo|×10% 防零 range（如 -50...-50 → 上浮至 -45 后 nice 化为 -50...-45）。
    /// - NaN 输入 → 0...1 兜底。
    /// - maxTickCount 为目标刻度上限（近似，实际可能 ±2）。
    public static func generate(dataMin: Double, dataMax: Double,
                                maxTickCount: Int = 6) -> Scale {
        guard dataMin.isFinite, dataMax.isFinite else {
            return Scale(min: 0, max: 1, step: 1, ticks: [0, 1])
        }
        var lo = dataMin, hi = dataMax
        if lo > hi { swap(&lo, &hi) }
        if lo >= 0 { lo = 0 }                       // 全非负：含 0 下界
        if hi <= lo { hi = lo + (lo == 0 ? 1 : abs(lo) * 0.1) }  // 平线：0 → 0...1；负值上浮 10% 防零 range
        let range = niceNum(hi - lo)
        let step = niceNum(range / Double(max(maxTickCount, 2)))
        let niceMin = (lo / step).rounded(.down) * step
        let niceMax = (hi / step).rounded(.up) * step
        // 刻度：整数步进避免浮点累积误差
        let count = Int(((niceMax - niceMin) / step).rounded())
        let ticks = (0...max(count, 0)).map { niceMin + Double($0) * step }
        return Scale(min: niceMin, max: niceMax, step: step, ticks: ticks)
    }

    /// 把任意正数舍入到 1 / 2 / 5 × 10ⁿ 形态（Heckbert nice number）。
    static func niceNum(_ range: Double) -> Double {
        guard range.isFinite, range > 0 else { return 1 }
        let exponent = floor(log10(range))
        let fraction = range / pow(10, exponent)
        let niceFraction: Double
        switch fraction {
        case ..<1.5: niceFraction = 1
        case ..<3:   niceFraction = 2
        case ..<7:   niceFraction = 5
        default:     niceFraction = 10
        }
        return niceFraction * pow(10, exponent)
    }
}
