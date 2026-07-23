import CoreGraphics

/// 热力图布局纯函数（便于 DEBUG 自检；仅依赖 CoreGraphics）。
public enum HeatmapGeometry {
    /// 布局结果。
    public struct Layout {
        public var cellSize: CGFloat          // 正方形边长
        public var gridOrigin: CGPoint        // 第一个格子（row=0,col=0）左上角（含对齐偏移）
        public var contentWidth: CGFloat      // 格子区域实际宽度
        public var contentHeight: CGFloat     // 格子区域实际高度
    }

    /// 根据可用区域、行列数、行/列间距、对齐，计算正方形格子尺寸与原点。
    ///
    /// 正方形约束：cellSize = min(可用宽/列数, 可用高/行数)，已扣除列间距/行间距。
    /// 纵向恒为顶部对齐（避免行标签错位）；横向按 `alignment`。
    ///
    /// - Parameters:
    ///   - bounds: 可用绘制区域
    ///   - rows: 行数
    ///   - columns: 最大列数
    ///   - rowSpacing: 行间距（垂直，格子之间）
    ///   - columnSpacing: 列间距（水平，格子之间）
    ///   - alignment: 水平对齐
    /// - Returns: 布局结果；rows/columns <= 0 时 cellSize=0
    public static func layout(
        bounds: CGRect, rows: Int, columns: Int,
        rowSpacing: CGFloat, columnSpacing: CGFloat,
        alignment: HeatmapHorizontalAlignment
    ) -> Layout {
        guard rows > 0, columns > 0 else {
            return Layout(cellSize: 0, gridOrigin: bounds.origin,
                          contentWidth: 0, contentHeight: 0)
        }
        let usableW = max(0, bounds.width - CGFloat(columns - 1) * columnSpacing)
        let usableH = max(0, bounds.height - CGFloat(rows - 1) * rowSpacing)
        let byW = usableW / CGFloat(columns)
        let byH = usableH / CGFloat(rows)
        let size = floor(max(0, min(byW, byH)))
        let contentW = CGFloat(columns) * size + CGFloat(columns - 1) * columnSpacing
        let contentH = CGFloat(rows) * size + CGFloat(rows - 1) * rowSpacing
        let xOffset: CGFloat
        switch alignment {
        case .leading:  xOffset = bounds.minX
        case .center:   xOffset = bounds.minX + (bounds.width - contentW) / 2
        case .trailing: xOffset = bounds.maxX - contentW
        }
        let yOffset = bounds.minY
        return Layout(cellSize: size,
                      gridOrigin: CGPoint(x: xOffset, y: yOffset),
                      contentWidth: contentW,
                      contentHeight: contentH)
    }

    /// 第 (row, col) 个格子的 frame（相对 gridOrigin 同坐标系）。
    public static func cellFrame(row: Int, col: Int, layout: Layout,
                                 rowSpacing: CGFloat, columnSpacing: CGFloat) -> CGRect {
        let x = layout.gridOrigin.x + CGFloat(col) * (layout.cellSize + columnSpacing)
        let y = layout.gridOrigin.y + CGFloat(row) * (layout.cellSize + rowSpacing)
        return CGRect(x: x, y: y, width: layout.cellSize, height: layout.cellSize)
    }
}
