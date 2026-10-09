import UIKit

/// 图形主体的选中覆盖层；默认关闭，保持既有外观。与 tooltip / crosshair 开关独立。
/// 不修改系列 path、原配色、数据或命中范围；所有尺寸为屏幕 pt。
public struct CartesianSelectionStyle {
    public var isEnabled: Bool
    public var color: UIColor
    public var lineWidth: CGFloat
    public var fillOpacity: CGFloat
    /// 折线点环的最小半径（实际半径不小于当前系列 marker 半径）。
    public var pointRadius: CGFloat
    public init(isEnabled: Bool = false, color: UIColor = .systemYellow,
                lineWidth: CGFloat = 2, fillOpacity: CGFloat = 0.16, pointRadius: CGFloat = 7) {
        self.isEnabled = isEnabled; self.color = color; self.lineWidth = lineWidth
        self.fillOpacity = fillOpacity; self.pointRadius = pointRadius
    }
}

struct CartesianSelectionKey: Hashable {
    let seriesID: String
    let category: Int
    let kind: String
}

extension CartesianRendererBase {
    private func selectionFamily(_ target: HYMChartHitTarget) -> String {
        // LineHitTarget 的历史 kind 沿用协议空字符串，不能将其当作图形族标识。
        if target is LineHitTarget { return "line" }
        if target is ColumnHitTarget { return "column" }
        if target is BarHitTarget { return "bar" }
        return ""
    }

    func setBodySelection(_ target: HYMChartHitTarget?) {
        selectionKeys.removeAll(keepingCapacity: true)
        guard let model = currentModel, (currentTheme as? CartesianChartTheme)?.selection.isEnabled == true else {
            refreshBodySelection(); return
        }
        func append(series: Int, category: Int, id: String?, kind: String?) {
            guard model.series.indices.contains(series), model.series[series].isVisible,
                  id == nil || model.series[series].id == id,
                  currentDrawValues.indices.contains(series), currentDrawValues[series].indices.contains(category),
                  currentDrawValues[series][category].isFinite,
                  let current = makeHitTarget(seriesIndex: series, categoryIndex: category, value: currentDrawValues[series][category]),
                  kind == nil || kind == selectionFamily(current) else { return }
            let key = CartesianSelectionKey(seriesID: model.series[series].id, category: category, kind: selectionFamily(current))
            if !selectionKeys.contains(key) { selectionKeys.append(key) }
        }
        switch target {
        case let t as CartesianSharedHitTarget:
            for entry in t.entries { append(series: entry.seriesIndex, category: t.categoryIndex, id: entry.seriesID, kind: nil) }
        case let t as LineHitTarget: append(series: t.seriesIndex, category: t.index, id: t.seriesID, kind: selectionFamily(t))
        case let t as ColumnHitTarget: append(series: t.seriesIndex, category: t.categoryIndex, id: t.seriesID, kind: selectionFamily(t))
        case let t as BarHitTarget: append(series: t.seriesIndex, category: t.categoryIndex, id: t.seriesID, kind: selectionFamily(t))
        default: break
        }
        refreshBodySelection()
    }

    /// 重绘/旋转和入场动画后只重取当前几何，不沿用过期 frame。
    func refreshBodySelection() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        selectionLayer.removeFromSuperlayer()
        selectionLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let model = currentModel, let theme = currentTheme as? CartesianChartTheme,
              theme.selection.isEnabled, currentPlotFrame.width > 0, currentPlotFrame.height > 0 else {
            selectionKeys.removeAll(); selectionShapes.removeAll(); return
        }
        let style = theme.selection
        let width = style.lineWidth.isFinite ? min(max(style.lineWidth, 0), 20) : 2
        let opacity = style.fillOpacity.isFinite ? min(max(style.fillOpacity, 0), 1) : 0.16
        let radius = style.pointRadius.isFinite ? min(max(style.pointRadius, 1), 60) : 7
        selectionLayer.name = "chart.selection"
        selectionLayer.frame = currentPlotFrame; selectionLayer.bounds.origin = currentPlotFrame.origin
        selectionLayer.masksToBounds = true
        var valid: [CartesianSelectionKey] = []
        for key in selectionKeys {
            guard let series = model.series.firstIndex(where: { $0.id == key.seriesID && $0.isVisible }),
                  currentDrawValues.indices.contains(series), currentDrawValues[series].indices.contains(key.category),
                  currentDrawValues[series][key.category].isFinite,
                  let target = makeHitTarget(seriesIndex: series, categoryIndex: key.category, value: currentDrawValues[series][key.category]),
                  selectionFamily(target) == key.kind, let frame = hitFrame(for: target),
                  [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite),
                  frame.width > 0, frame.height > 0 else { continue }
            let path: UIBezierPath
            if target is LineHitTarget {
                let center = CGPoint(x: frame.midX, y: frame.midY)
                guard currentPlotFrame.insetBy(dx: -0.001, dy: -0.001).contains(center) else { continue }
                let markerRadius = model.series[series].lineTheme(theme).pointRadius
                let r = max(radius, markerRadius.isFinite ? min(max(markerRadius, 0), 60) : radius)
                path = UIBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            } else {
                let visible = frame.intersection(currentPlotFrame)
                guard !visible.isNull, visible.width > 0, visible.height > 0 else { continue }
                // 使用真实柱/条 rect，不把交互容差扩大成主体高亮。
                let inset = min(width / 2, min(visible.width, visible.height) / 2)
                path = UIBezierPath(rect: visible.insetBy(dx: inset, dy: inset))
            }
            if selectionShapes.count <= valid.count { selectionShapes.append(CAShapeLayer()) }
            let shape = selectionShapes[valid.count]
            shape.name = "chart.selection." + key.seriesID + ":" + String(key.category)
            shape.path = path.cgPath; shape.lineWidth = width
            shape.strokeColor = style.color.cgColor
            shape.fillColor = style.color.withAlphaComponent(style.color.cgColor.alpha * opacity).cgColor
            selectionLayer.addSublayer(shape); valid.append(key)
        }
        selectionKeys = valid
        // 拖动到更少系列的列时释放多余层；上限始终是当前实际选中系列数。
        if selectionShapes.count > valid.count { selectionShapes.removeLast(selectionShapes.count - valid.count) }
        if !valid.isEmpty { rootLayer.addSublayer(selectionLayer) }
    }
}
