import UIKit

/// 闭包采用有名称的确定性预设，方便面板切换、复现和回归。
enum DemoTooltipRowRules {
    static let names = ["默认", "能源图标", "逐点名称", "隐藏偶数索引", "仅名称", "综合规则"]
    static func provider(_ name: String) -> ((CartesianDatum) -> CartesianTooltipRowStyle?)? {
        guard name != "默认" else { return nil }
        let images = ["sun.max.fill", "battery.100", "thermometer.medium", "bolt.fill"].map { UIImage(systemName: $0) }
        return { datum in
            let isPoint = datum.aggregatedValue == nil && datum.sourceRange.count == 1
            let composite = name == "综合规则"
            let image = name == "能源图标" || composite ? images[max(0, datum.seriesIndex) % images.count] : nil
            let title = isPoint && (name == "逐点名称" || composite)
                ? datum.name + "（采样\(datum.sourceRange.lowerBound + 1)）" : nil
            let hidesValue = name == "仅名称" || (composite && datum.seriesID == "series-3")
            let hidden = isPoint && ((name == "隐藏偶数索引" && datum.sourceRange.lowerBound % 2 == 0)
                || (composite && datum.seriesID == "series-2" && datum.sourceRange.lowerBound == 1))
            return .init(title: title, image: image, isHidden: hidden, hidesValue: hidesValue)
        }
    }
}
