import Foundation

/// 单个 renderer 内的有界缓存。源模型/主题更新时整体失效，不尝试比较闭包身份。
/// 保存三个最近使用的粒度；外部持有的原始 model 永远不被覆盖。
final class CartesianRenderDataCache {
    struct Prepared {
        let model: CartesianChartModel
        let drawValues: [[Double]]
        let baseValues: [[Double]]
        let primaryBounds: (min: Double, max: Double)?
        let secondaryBounds: (min: Double, max: Double)?
        init(model source: CartesianChartModel) {
            var m = source
            m.series = source.renderingSeries
            model = m
            drawValues = m.stackedDrawValues
            baseValues = m.allBaseValues
            primaryBounds = m.dataBounds(yAxisIndex: 0)
            secondaryBounds = m.dataBounds(yAxisIndex: 1)
        }
    }
    private var entries: [(stride: Int, value: Prepared)] = []
    private var labels: [String]?
    private(set) var hits = 0
    private(set) var misses = 0
    var count: Int { entries.count }

    func invalidate() {
        entries.removeAll(); labels = nil
        hits = 0; misses = 0
    }
    func categoryLabels(model: CartesianChartModel, enabled: Bool) -> [String] {
        if enabled, let labels { return labels }
        let new = model.categoryLabels
        if enabled { labels = new }
        return new
    }
    func prepared(stride: Int, enabled: Bool, build: () -> CartesianChartModel) -> Prepared {
        if enabled, let index = entries.firstIndex(where: { $0.stride == stride }) {
            let entry = entries.remove(at: index)
            entries.append(entry); hits += 1
            return entry.value
        }
        misses += 1
        let value = Prepared(model: build())
        if enabled {
            entries.append((stride, value))
            if entries.count > 3 { entries.removeFirst() }
        }
        return value
    }
}
