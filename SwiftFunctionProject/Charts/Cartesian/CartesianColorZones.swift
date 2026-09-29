import UIKit

/// 折线/面积的颜色分区轴。X 使用原始采样索引（可为小数），不是时间戳；
/// Y 使用系列所属值轴的绘制值（堆叠为累计值，百分比为百分比值）。
public enum CartesianZoneAxis { case x, y }

/// 一个半开颜色区间：[前一上限, upperBound)。首段从负无穷开始。
/// 仅影响折线/面积，不改变业务数据、值域、图例和命中；柱/条忽略此配置。
public struct CartesianColorZone {
    /// nil 表示正无穷，只能出现在末段。有限上限必须严格递增。
    public var upperBound: Double?
    /// nil 继承系列线色；标记跟随区间颜色，但显式 pointColor 优先。
    public var color: UIColor?
    /// nil 继承系列/主题渐变；空数组用本区间线色生成默认渐变；
    /// 一个颜色为纯色，多个颜色为沿整个绘图区的垂直渐变，不在分区边界重新开始。
    /// 所有颜色 alpha 仍乘系列 fillOpacity。
    public var areaGradientColors: [UIColor]?

    /// 创建分区；此值配置应用到图表时须在主线程，勿并发修改同一变量。
    public init(upperBound: Double? = nil, color: UIColor? = nil,
                areaGradientColors: [UIColor]? = nil) {
        self.upperBound = upperBound; self.color = color; self.areaGradientColors = areaGradientColors
    }
}

/// 逐系列连续线色/面积分区。有效配置优先于 negativeColor；nil 或无效配置回退旧行为。
/// 未给末段 nil 上限时，剩余区间自动继承系列线色/填充。阈值处属于后一段。
public struct CartesianColorZones {
    public var axis: CartesianZoneAxis
    public var zones: [CartesianColorZone]

    /// 创建配置；区间按上限严格递增，不自动排序或合并。
    public init(axis: CartesianZoneAxis = .y, zones: [CartesianColorZone]) {
        self.axis = axis; self.zones = zones
    }

    /// 空配置、非有限/重复/逆序上限、非末段无上限均无效；整份回退，避免部分误着色。
    public var isValid: Bool {
        guard !zones.isEmpty else { return false }
        var previous = -Double.infinity
        for (index, zone) in zones.enumerated() {
            guard let upper = zone.upperBound else { return index == zones.count - 1 }
            guard upper.isFinite, upper > previous else { return false }
            previous = upper
        }
        return true
    }
}

/// 渲染时一次解析；数据点查色和路径裁剪共享边界语义，不在每个标记处重复校验配置。
struct CartesianResolvedColorZones {
    let axis: CartesianZoneAxis
    let zones: [CartesianColorZone]
    let baseColor: UIColor
    var overridesArea: Bool { zones.contains { $0.areaGradientColors != nil } }

    init?(configuration: CartesianColorZones?, negativeColor: UIColor?, baseColor: UIColor) {
        if let configuration, configuration.isValid {
            axis = configuration.axis; zones = configuration.zones
        } else if let negativeColor, negativeColor != baseColor {
            axis = .y; zones = [.init(upperBound: 0, color: negativeColor)]
        } else { return nil }
        self.baseColor = baseColor
    }

    func color(x: Double, y: Double) -> UIColor {
        let value = axis == .x ? x : y
        return zones.first { $0.upperBound.map { value < $0 } ?? true }?.color ?? baseColor
    }

    struct Region {
        let clip: CGRect
        let zone: CartesianColorZone
    }

    /// 先与可见域求交再映射；阈值远在视口外时也不产生无限坐标/空图层。
    func regions(viewport: CartesianViewport, yDomain: ClosedRange<Double>?, plot: CGRect) -> [Region] {
        let domain = axis == .x ? viewport.xDomain : (yDomain ?? viewport.yDomain)
        let span = domain.upperBound - domain.lowerBound
        guard plot.width > 0, plot.height > 0, span.isFinite, span > 0,
              domain.lowerBound.isFinite, domain.upperBound.isFinite else { return [] }
        var result: [Region] = []
        var lower = -Double.infinity
        var complete = zones
        if zones.last?.upperBound != nil { complete.append(.init()) }
        for zone in complete {
            let upper = zone.upperBound ?? .infinity
            let lo = max(lower, domain.lowerBound), hi = min(upper, domain.upperBound)
            if hi > lo {
                let a = CGFloat((lo - domain.lowerBound) / span)
                let b = CGFloat((hi - domain.lowerBound) / span)
                let rect: CGRect
                if axis == .x {
                    rect = CGRect(x: plot.minX + a * plot.width, y: plot.minY,
                                  width: (b - a) * plot.width, height: plot.height)
                } else {
                    rect = CGRect(x: plot.minX, y: plot.maxY - b * plot.height,
                                  width: plot.width, height: (b - a) * plot.height)
                }
                result.append(Region(clip: rect, zone: zone))
            }
            lower = upper
        }
        return result
    }
}
