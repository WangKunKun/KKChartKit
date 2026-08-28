import Foundation

/// 值轴刻度生成器（纯函数，DEBUG 自检覆盖）。
///
/// 四档优先级：`tickPositions`（显式值）> `tickInterval`（须配显式 min/max）
/// > `tickCount`（nice scale 目标数量）> 自动（默认 6）。
/// 结果一律过滤到生效值域内（域外刻度不画线）。
enum ValueTickGenerator {

    /// - Parameters:
    ///   - axis: 值轴配置
    ///   - domain: 生效值域（过滤基准）
    ///   - dataBounds: 绑定系列的数据边界（自动档的生成来源；nil 走 0...1 兜底）
    ///   - generatesFromDomain: true 时自动档按 domain 本身生成
    ///     （水平图值轴在 X、随视口窗口变化，刻度跟随窗口）而非数据边界
    static func ticks(axis: CartesianAxisModel,
                      domain: ClosedRange<Double>,
                      dataBounds: (min: Double, max: Double)?,
                      generatesFromDomain: Bool) -> [Double] {
        let lo = domain.lowerBound, hi = domain.upperBound
        let inDomain: (Double) -> Bool = { $0 >= lo - 1e-9 && $0 <= hi + 1e-9 }

        if let positions = axis.tickPositions {
            return positions.filter(inDomain)
        }
        if let interval = axis.tickInterval,
           let minV = axis.min, let maxV = axis.max, interval > 0 {
            let count = Int(((maxV - minV) / interval).rounded())
            return (0...max(count, 0)).map { minV + Double($0) * interval }.filter(inDomain)
        }
        let scale: NiceScaleGenerator.Scale
        if generatesFromDomain {
            scale = NiceScaleGenerator.generate(dataMin: lo, dataMax: hi,
                                                maxTickCount: axis.tickCount ?? 6)
        } else {
            let b = dataBounds ?? (min: 0, max: 1)
            scale = NiceScaleGenerator.generate(dataMin: axis.min ?? b.min,
                                                dataMax: axis.max ?? b.max,
                                                maxTickCount: axis.tickCount ?? 6)
        }
        return scale.ticks.filter(inDomain)
    }
}
