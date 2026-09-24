import UIKit

/// 热力图命中目标（点击格子时产生）。热力图不区分类别，kind 用协议默认 ""。
public struct HeatmapHitTarget: HYMChartHitTarget {
    public let identifier: String
    public let index: Int
    public let row: Int
    public let column: Int
    /// 该格子弹窗文本（自定义优先，否则 `format(value)`）。nil 表示无文本。
    public let tooltipText: String?
    public init(row: Int, column: Int, tooltipText: String? = nil) {
        self.row = row
        self.column = column
        self.identifier = "(\(row),\(column))"
        self.index = row * 1000 + column
        self.tooltipText = tooltipText
    }
}

/// 热力图渲染器：实现 HYMChartRenderer。绘制二维格子色块 + 可选行列标签 + 点击命中/选中边框。
///
/// 性能策略：每格一个 CALayer（圆角/边框/动画天然，与雷达图「每元素一 layer」风格一致）。
/// 格子均挂在 `cellsContainerLayer` 下，入场动画整体 opacity 淡入（由容器 DisplayLink 驱动）。
/// 若未来格子达数百级，可改为单 layer `draw(context:)` 批量绘制（Renderer 内部自由度，不影响协议）。
public final class HeatmapChartRenderer: HYMChartRenderer {
    public typealias Model = HeatmapChartModel
    public typealias Theme = HeatmapChartTheme

    public init() {}

    // MARK: - layer 子树
    private let backgroundLayer = CALayer()      // 背景色块（圆角，可选）
    private let cellsContainerLayer = CALayer()  // 所有格子容器（动画单元）
    private weak var hostView: UIView?
    private var rowLabels: [UILabel] = []
    private var columnLabels: [UILabel] = []

    // MARK: - 当前状态（render 时存，供动画/命中/选中读取）
    private var currentModel: HeatmapChartModel?
    private var currentTheme: HeatmapChartTheme?
    private var lastContext: HYMChartRenderContext?
    /// 命中检测缓存：渲染后的格子 frame（view 坐标系，因容器 frame=bounds）
    private var lastCellFrames: [(row: Int, col: Int, frame: CGRect)] = []
    /// 当前选中（单选互斥）
    private var currentSelection: (row: Int, column: Int)?

    // MARK: - mount / unmount
    public func mount(into view: UIView) {
        hostView = view
        view.layer.addSublayer(backgroundLayer)
        view.layer.addSublayer(cellsContainerLayer)
    }

    public func unmount(from view: UIView) {
        rowLabels.forEach { $0.removeFromSuperview() }
        columnLabels.forEach { $0.removeFromSuperview() }
        rowLabels.removeAll()
        columnLabels.removeAll()
        cellsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        [backgroundLayer, cellsContainerLayer].forEach { $0.removeFromSuperlayer() }
        hostView = nil
    }

    // MARK: - 动画契约
    public var animatableLayers: [CALayer] {
        guard currentTheme?.showsEntranceAnimation == true else { return [] }
        return [cellsContainerLayer]   // 容器对其 opacity 逐帧淡入（DisplayLink）
    }
    // updateEntranceAnimation 用协议默认空实现（热力图无逐帧子视图动画）

    // MARK: - render
    public func render(model: HeatmapChartModel, theme: HeatmapChartTheme, context: HYMChartRenderContext) {
        currentModel = model
        currentTheme = theme
        lastContext = context
        lastCellFrames.removeAll()
        cellsContainerLayer.frame = context.bounds

        // 背景
        if let bg = theme.backgroundColor {
            backgroundLayer.isHidden = false
            backgroundLayer.frame = context.bounds
            backgroundLayer.backgroundColor = bg.cgColor
            backgroundLayer.cornerRadius = theme.backgroundCornerRadius
        } else {
            backgroundLayer.isHidden = true
        }

        // 清空旧格子
        cellsContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        // 清空旧标签
        rowLabels.forEach { $0.removeFromSuperview() }; rowLabels.removeAll()
        columnLabels.forEach { $0.removeFromSuperview() }; columnLabels.removeAll()

        guard !model.rows.isEmpty, model.maxColumns > 0 else { return }

        // 1) 计算标签占位 → 格子可用区域（隐藏的标签不占空间）
        let cellBounds = resolveCellBounds(bounds: context.bounds, model: model, theme: theme)

        // 2) 布局（行/列间距分开）
        let layout = HeatmapGeometry.layout(
            bounds: cellBounds, rows: model.rows.count, columns: model.maxColumns,
            rowSpacing: theme.rowSpacing, columnSpacing: theme.columnSpacing,
            alignment: theme.horizontalAlignment)

        // 3) 色阶值域
        let range = model.resolvedValueRange
        let span = range.upperBound - range.lowerBound

        // 4) 绘制格子（选中格子加边框）
        for (r, row) in model.rows.enumerated() {
            for (c, cell) in row.enumerated() {
                guard cell.isValid else { continue }   // 无效格：占位不绘制、不进命中缓存
                let f = HeatmapGeometry.cellFrame(row: r, col: c, layout: layout,
                                                  rowSpacing: theme.rowSpacing, columnSpacing: theme.columnSpacing)
                lastCellFrames.append((r, c, f))
                let layer = CALayer()
                layer.frame = f
                layer.cornerRadius = theme.cellCornerRadius
                layer.backgroundColor = resolvedColor(for: cell, range: range, span: span, theme: theme).cgColor
                // 选中态边框（D5）
                if currentSelection?.row == r && currentSelection?.column == c {
                    layer.borderColor = (theme.selectionBorderColor ?? UIColor.clear).cgColor
                    layer.borderWidth = theme.selectionBorderWidth
                    layer.cornerRadius = theme.selectionBorderCornerRadius ?? theme.cellCornerRadius
                }
                cellsContainerLayer.addSublayer(layer)
            }
        }

        // 5) 标签（行/列分别按开关渲染）
        rebuildLabels(model: model, theme: theme, layout: layout)
    }

    // MARK: - 单格取色（per-cell 覆盖 > 色阶 > empty）
    private func resolvedColor(for cell: HeatmapCell,
                               range: ClosedRange<Double>, span: Double,
                               theme: HeatmapChartTheme) -> UIColor {
        if let override = cell.color { return override }
        if case .none = theme.colorScale { return theme.baseColor }
        let t = span > 0 ? (cell.value - range.lowerBound) / span : 1.0
        let c = theme.colorScale.color(at: CGFloat(t))
        return c == .clear ? theme.emptyColor : c
    }

    // MARK: - 格子可用区域（仅对「显示中」的标签预留空间）
    private func resolveCellBounds(bounds: CGRect, model: HeatmapChartModel, theme: HeatmapChartTheme) -> CGRect {
        var rowLabelW: CGFloat = 0
        var colLabelH: CGFloat = 0
        if theme.showsRowLabels, let labels = model.rowLabels, labels.count == model.rows.count {
            rowLabelW = (labels.map { textSize($0, font: theme.labelFont).width }.max() ?? 0) + theme.labelGap
        }
        if theme.showsColumnLabels, let labels = model.columnLabels, labels.count == model.maxColumns {
            colLabelH = textSize(labels.first ?? "", font: theme.labelFont).height + theme.labelGap
        }
        return bounds
            .insetBy(dx: theme.contentInset, dy: theme.contentInset)
            .insetBy(dx: rowLabelW, dy: 0)   // 左侧让出行标签（仅当显示）
            .insetBy(dx: 0, dy: colLabelH)   // 顶部让出列标签（仅当显示）
    }

    private func textSize(_ s: String, font: UIFont) -> CGSize {
        (s as NSString).size(withAttributes: [.font: font])
    }

    // MARK: - 标签（行/列分别渲染）
    private func rebuildLabels(model: HeatmapChartModel, theme: HeatmapChartTheme, layout: HeatmapGeometry.Layout) {
        guard let view = hostView else { return }
        let ox = layout.gridOrigin.x
        let oy = layout.gridOrigin.y
        let rowStep = layout.cellSize + theme.rowSpacing
        let colStep = layout.cellSize + theme.columnSpacing

        if theme.showsRowLabels, let labels = model.rowLabels, labels.count == model.rows.count {
            for r in 0..<model.rows.count {
                let lbl = UILabel()
                lbl.text = labels[r]
                lbl.textColor = theme.labelColor
                lbl.font = theme.labelFont
                lbl.sizeToFit()
                let cy = oy + CGFloat(r) * rowStep + layout.cellSize / 2
                lbl.center = CGPoint(x: ox - theme.labelGap - lbl.bounds.width / 2, y: cy)
                view.addSubview(lbl)
                rowLabels.append(lbl)
            }
        }
        if theme.showsColumnLabels, let labels = model.columnLabels, labels.count == model.maxColumns {
            for c in 0..<model.maxColumns {
                let lbl = UILabel()
                lbl.text = labels[c]
                lbl.textColor = theme.labelColor
                lbl.font = theme.labelFont
                lbl.sizeToFit()
                let cx = ox + CGFloat(c) * colStep + layout.cellSize / 2
                lbl.center = CGPoint(x: cx, y: oy - theme.labelGap - lbl.bounds.height / 2)
                view.addSubview(lbl)
                columnLabels.append(lbl)
            }
        }
    }

    // MARK: - 命中（覆盖协议默认 nil 实现）
    public func hitTest(_ point: CGPoint) -> HYMChartHitTarget? {
        guard let model = currentModel else { return nil }
        for hit in lastCellFrames where hit.frame.contains(point) {
            let cell = model.rows[hit.row][hit.col]
            let text = cell.tooltipText ?? Self.format(cell.value)
            return HeatmapHitTarget(row: hit.row, column: hit.col, tooltipText: text)
        }
        return nil
    }

    // MARK: - 选中（单选互斥；重绘格子应用边框）
    public func applySelection(_ target: HYMChartHitTarget?) {
        if let h = target as? HeatmapHitTarget {
            currentSelection = (h.row, h.column)
        } else {
            currentSelection = nil
        }
        guard let model = currentModel, let theme = currentTheme, let ctx = lastContext else { return }
        render(model: model, theme: theme, context: ctx)
    }

    // MARK: - Tooltip 锚点（覆盖协议默认 nil）
    public func tooltipAnchor(for target: HYMChartHitTarget) -> HYMChartTooltipAnchor? {
        guard let theme = currentTheme, theme.showsTooltipOnHit,
              let h = target as? HeatmapHitTarget,
              let hit = lastCellFrames.first(where: { $0.row == h.row && $0.col == h.column })
        else { return nil }
        return HYMChartTooltipAnchor(frame: hit.frame, preferredPlacements: [.top, .bottom])
    }

    // MARK: - 命中单元 frame（独立于 tooltip 开关，供外部自定义弹窗定位）
    public func hitFrame(for target: HYMChartHitTarget) -> CGRect? {
        guard let h = target as? HeatmapHitTarget,
              let hit = lastCellFrames.first(where: { $0.row == h.row && $0.col == h.column })
        else { return nil }
        return hit.frame
    }

    /// 默认 value 文本：去尾零（80.0 → "80"；80.5 → "80.5"）。
    static func format(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(value)
    }
}
