import UIKit

/// 原值合计与屏幕几何分离：小于一个像素的段也参与合计，正负链按轴独立。
struct CartesianStackTotalLabels {
    struct Key: Hashable {
        let axis: Int
        let stack: Int
        let category: Int
        let positive: Bool
    }

    struct Entry {
        var total: Double
        var endpoint: CGPoint
    }

    private(set) var entries: [Key: Entry] = [:]

    mutating func add(rawValue: Double, category: Int, axis: Int,
                      rect: CGRect, horizontal: Bool, stack: Int = 0) {
        guard rawValue.isFinite, rawValue != 0 else { return }
        let positive = rawValue > 0
        let key = Key(axis: axis, stack: stack, category: category, positive: positive)
        let endpoint = horizontal
            ? CGPoint(x: positive ? rect.maxX : rect.minX, y: rect.midY)
            : CGPoint(x: rect.midX, y: positive ? rect.minY : rect.maxY)
        // 渲染按系列顺序推进；同符号链最后一个非零段就是链端。
        let total = (entries[key]?.total ?? 0) + rawValue
        entries[key] = Entry(total: total, endpoint: endpoint)
    }

    func visibleEntries(in plot: CGRect) -> [(key: Key, value: Entry)] {
        entries.filter {
            let p = $0.value.endpoint
            // 包含恰好落在边缘的链端，但不把视口外的真实链端伪装成边缘标签。
            return $0.value.total.isFinite && p.x.isFinite && p.y.isFinite
                && p.x >= plot.minX - 1e-6 && p.x <= plot.maxX + 1e-6
                && p.y >= plot.minY - 1e-6 && p.y <= plot.maxY + 1e-6
        }.sorted {
            if $0.key.axis != $1.key.axis { return $0.key.axis < $1.key.axis }
            if $0.key.stack != $1.key.stack { return $0.key.stack < $1.key.stack }
            if $0.key.category != $1.key.category { return $0.key.category < $1.key.category }
            return $0.key.positive && !$1.key.positive
        }
    }
}

extension CartesianRendererBase {
    /// 标签收敛到 plot 内，避免覆盖标题和轴刻度；放不下的长文案跳过。
    func drawStackTotalLabels(_ totals: CartesianStackTotalLabels,
                             theme: CartesianChartTheme, into layer: CALayer) {
        let entries = totals.visibleEntries(in: currentPlotFrame)
        guard entries.count <= max(0, theme.dataLabelMaxMarkCount) else { return }
        let available = currentPlotFrame.insetBy(dx: 1, dy: 1)
        guard available.width > 0, available.height > 0 else { return }
        for (key, entry) in entries {
            let text = CartesianDataLabelGeometry.labelText(
                entry.total, formatter: theme.stackTotalLabelFormatter)
            let size = dataLabelTextSize(text, fontSize: theme.dataLabelFontSize)
            guard !text.isEmpty, size.width <= available.width,
                  size.height <= available.height else { continue }
            var center = entry.endpoint
            if isHorizontalValueAxis {
                center.x += (key.positive ? 1 : -1) * (size.width / 2 + 3)
            } else {
                center.y += (key.positive ? -1 : 1) * (size.height / 2 + 3)
            }
            center.x = min(max(center.x, available.minX + size.width / 2),
                           available.maxX - size.width / 2)
            center.y = min(max(center.y, available.minY + size.height / 2),
                           available.maxY - size.height / 2)
            layer.addSublayer(makeDataLabelLayer(
                text: text, fontSize: theme.dataLabelFontSize,
                color: dataLabelColor(theme: theme, inside: false), center: center, objects: seriesObjects))
        }
    }
}
